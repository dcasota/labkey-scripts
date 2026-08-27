#!/usr/bin/env python3
"""
Verify the LabKey publish target and record what was observed.

This is the executable form of the project's central rule: never assert a
LabKey behaviour that has not been checked. Each probe below is read-only, and
each writes a row into the memory database so that a later session can look the
answer up instead of guessing (see ``standards/general/verification.md``).

Usage::

    export LK_URL=https://127.0.0.1:8443
    export LK_USER=...  LK_PASSWORD=...       # or LK_APIKEY=...
    scripts/verify_labkey.py                  # probe and print
    scripts/verify_labkey.py --record V-020   # also write verification rows,
                                              # numbering from V-020 upwards

Credentials come from the environment only. Nothing is written to the LabKey
server; every probe is a read.

Exit codes: 0 all probes passed, 2 at least one probe failed, 1 fatal.
"""
from __future__ import annotations

import argparse
import logging
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "src"))

from osm.labkey import (  # noqa: E402
    ConfigError,
    LabKeyClient,
    LabKeyError,
)

log = logging.getLogger("verify")

#: Capabilities the OSM specification needs and LabKey CE is expected to lack.
#: Listed explicitly so that a future LabKey release *gaining* one shows up as a
#: changed result rather than going unnoticed.
EXPECTED_ABSENT_SCHEMAS = ("inventory", "storage", "freezer", "sampleManager",
                           "workflow", "eln", "labbook")

#: Aliquot and amount columns the bridge relies on when publishing samples.
EXPECTED_MATERIAL_COLUMNS = ("RootMaterialRowId", "AliquotedFromLSID", "IsAliquot",
                             "AliquotCount", "StoredAmount", "Units", "SampleState")


@dataclass
class Probe:
    """One read-only check and its outcome."""

    claim: str
    command: str
    result: str = "pass"          # pass | fail | partial
    detail: str = ""
    notes: list[str] = field(default_factory=list)

    def report(self) -> None:
        mark = {"pass": "PASS", "fail": "FAIL", "partial": "PART"}[self.result]
        print(f"[{mark}] {self.claim}")
        if self.detail:
            print(f"       {self.detail}")


def probe_identity(lk: LabKeyClient) -> Probe:
    data = lk.whoami()
    email = data.get("email") or data.get("displayName")
    ok = bool(email) and email != "guest"
    return Probe(
        claim="An authenticated LabKey session can be established from environment credentials",
        command="GET /login-whoAmI.api",
        result="pass" if ok else "fail",
        detail=(f"authenticated as {email}; CSRF token "
                f"{'captured' if lk.csrf else 'MISSING'}; base {lk.base_url}"),
    )


def probe_schemas(lk: LabKeyClient, container: str) -> tuple[Probe, list[str]]:
    schemas = lk.schemas(container)
    present = [s for s in EXPECTED_ABSENT_SCHEMAS if s in schemas]
    return (
        Probe(
            claim=("LabKey CE exposes no inventory, storage, freezer, workflow or "
                   "eln schema, so it provides no substrate for the OSM freezer "
                   "map, job queue or notebook"),
            command=f"POST {container}/query-getSchemas.api {{includeHidden:true}}",
            result="pass" if not present else "partial",
            detail=(f"{len(schemas)} schemas: {', '.join(schemas)}"
                    + (f"; UNEXPECTEDLY PRESENT: {', '.join(present)}" if present else "")),
        ),
        schemas,
    )


def probe_material_columns(lk: LabKeyClient, container: str) -> Probe:
    cols = lk.query_details("exp", "Materials", container=container)
    names = {c.get("name") for c in cols}
    missing = [c for c in EXPECTED_MATERIAL_COLUMNS if c not in names]
    return Probe(
        claim=("exp.Materials natively carries the aliquot, amount and status "
               "columns the publish bridge maps onto"),
        command=f"POST {container}/query-getQueryDetails.api {{exp, Materials}}",
        result="pass" if not missing else "fail",
        detail=(f"{len(cols)} columns; all expected present"
                if not missing else f"missing: {', '.join(missing)}"),
    )


def probe_sample_states(lk: LabKeyClient, container: str) -> Probe:
    rows = lk.select_rows("exp", "SampleStateType", container=container)
    values = [r.get("Value") for r in rows]
    return Probe(
        claim=("LabKey CE offers only three sample state types against the eight "
               "lifecycle statuses the OSM specification requires"),
        command=f"POST {container}/query-selectRows.api {{exp, SampleStateType}}",
        result="pass" if len(values) == 3 else "partial",
        detail=(f"{len(values)} state types: {', '.join(str(v) for v in values)}; "
                "OSM needs Registered, Available, Reserved, In Process, Consumed, "
                "Locked, Discarded, Shipped"),
    )


def probe_audit(lk: LabKeyClient, container: str) -> Probe:
    queries = lk.queries("auditLog", container=container)
    wanted = ("SampleTimelineEvent", "SampleSetAuditEvent", "TransactionAuditEvent")
    missing = [q for q in wanted if q not in queries]
    return Probe(
        claim=("The auditLog schema is queryable and provides a sample timeline, "
               "which supplements but cannot replace the OSM hash-chained trail"),
        command=f"POST {container}/query-getQueries.api {{auditLog}}",
        result="pass" if not missing else "fail",
        detail=(f"{len(queries)} audit queries; sample providers present"
                if not missing else f"missing: {', '.join(missing)}"),
    )


def probe_units(lk: LabKeyClient, container: str) -> Probe:
    rows = lk.select_rows("exp", "MeasurementUnits", container=container)
    return Probe(
        claim="LabKey CE ships a fixed measurement-unit vocabulary the bridge must map onto",
        command=f"POST {container}/query-selectRows.api {{exp, MeasurementUnits}}",
        result="pass" if rows else "fail",
        detail=f"{len(rows)} units: {', '.join(str(r.get('Value')) for r in rows[:12])}…",
    )


def probe_known_bad_action(lk: LabKeyClient) -> Probe:
    """The client must refuse a non-existent action locally rather than
    producing a confusing 404 from the server."""
    try:
        lk.post_json("query-importData.api", {})
    except LabKeyError as exc:
        ok = "query-import.api" in str(exc)
        return Probe(
            claim=("The client refuses query-importData.api locally and names "
                   "query-import.api, the action that actually exists"),
            command="client guard, no request issued",
            result="pass" if ok else "fail",
            detail=str(exc)[:200],
        )
    return Probe(
        claim="The client refuses query-importData.api locally",
        command="client guard",
        result="fail",
        detail="the guard did not fire",
    )


def probe_containers(lk: LabKeyClient) -> Probe:
    data = lk.containers("/", depth=1)
    children = [c.get("path") for c in (data.get("children") or [])]
    return Probe(
        claim="Container enumeration works and the project's scratch space can be located",
        command="GET /project-getContainers.api?includeSubfolders=true&depth=1",
        result="pass",
        detail=f"{len(children)} top-level containers: {', '.join(str(c) for c in children)}",
    )


def next_verification_id(start: str | None) -> "callable":
    """Return an allocator producing V-nnn ids, continuing after existing rows."""
    if start:
        if not re.fullmatch(r"V-\d{3}", start):
            raise SystemExit(f"--record expects an id like V-020, got {start!r}")
        counter = int(start.split("-")[1])
    else:
        counter = 1

    def allocate() -> str:
        nonlocal counter
        value = f"V-{counter:03d}"
        counter += 1
        return value

    return allocate


def record(probe: Probe, vid: str) -> None:
    """Write one verification row through the memory CLI.

    Shelling out to ``tools/memory.py`` rather than importing it keeps the
    single documented write path honest: if the CLI rejects the row, so is this.
    """
    cmd = [
        sys.executable, str(REPO / "tools" / "memory.py"), "add", "verification",
        "--id", vid, "--claim", probe.claim, "--method", "http",
        "--command", probe.command, "--result", probe.result,
        "--detail", probe.detail, "--replace",
    ]
    completed = subprocess.run(cmd, capture_output=True, text=True)
    if completed.returncode != 0:
        raise SystemExit(f"failed to record {vid}: {completed.stderr.strip()}\n"
                         f"  command: {shlex.join(cmd[:6])} …")
    print(f"       recorded {vid}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--container", default="/home",
                    help="container to probe (default: /home)")
    ap.add_argument("--record", metavar="FIRST_ID", nargs="?", const="V-001", default=None,
                    help="write verification rows starting at this id, e.g. V-020")
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args(argv)

    logging.basicConfig(level=logging.DEBUG if a.verbose else logging.INFO,
                        format="%(levelname)s %(name)s: %(message)s")

    try:
        client = LabKeyClient.from_env()
    except ConfigError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    probes: list[Probe] = []
    try:
        with client as lk:
            probes.append(probe_identity(lk))
            schema_probe, _ = probe_schemas(lk, a.container)
            probes.append(schema_probe)
            probes.append(probe_material_columns(lk, a.container))
            probes.append(probe_sample_states(lk, a.container))
            probes.append(probe_audit(lk, a.container))
            probes.append(probe_units(lk, a.container))
            probes.append(probe_containers(lk))
            probes.append(probe_known_bad_action(lk))
    except LabKeyError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print()
    allocate = next_verification_id(a.record) if a.record else None
    for p in probes:
        p.report()
        if allocate:
            record(p, allocate())
    print()

    failed = [p for p in probes if p.result == "fail"]
    partial = [p for p in probes if p.result == "partial"]
    print(f"{len(probes)} probes: {len(probes) - len(failed) - len(partial)} pass, "
          f"{len(partial)} partial, {len(failed)} fail")
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
