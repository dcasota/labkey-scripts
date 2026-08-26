#!/usr/bin/env python3
"""
OSM project memory database CLI.

The memory database is the durable, machine-queryable knowledge base for the
Open Sample Manager (OSM) project. Every later session reads from it instead of
re-deriving knowledge from scratch.

Source of truth in git is the deterministic SQL dump ``.sdd/memory.sql``.
The binary ``.sdd/memory.db`` is a *build artifact* and is git-ignored.

    tools/memory.py rebuild      # .sdd/memory.sql -> .sdd/memory.db
    tools/memory.py dump         # .sdd/memory.db  -> .sdd/memory.sql

Every mutating command writes the dump automatically, so a commit always
contains a reviewable text diff of what changed.

Usage examples
--------------
    tools/memory.py init
    tools/memory.py add req --id FR-001 --title "..." --kind functional \\
        --source "spec:§4" --priority must --iteration I1 --body "..."
    tools/memory.py add research --id RF-001 --topic "..." --finding "..." \\
        --evidence-kind source --evidence-ref /root/scicore/...
    tools/memory.py add decision --id ADR-001 --title "..." --status accepted \\
        --context "..." --decision "..." --consequences "..."
    tools/memory.py add feature --id FEAT-001 --area storage --name "..." \\
        --commercial yes --ce-support absent --gap high
    tools/memory.py add backlog --id PR-001 --title "..." --summary "..." \\
        --acceptance "..." --depends PR-000 --iteration I0 --size S
    tools/memory.py add task --id T-001 --pr PR-001 --title "..."
    tools/memory.py add verification --id V-001 --claim "..." --method http \\
        --command "..." --result pass --detail "..."
    tools/memory.py link --req FR-001 --to PR-001 --kind backlog
    tools/memory.py list backlog
    tools/memory.py show PR-001
    tools/memory.py query "SELECT id,title FROM backlog WHERE status='todo'"
    tools/memory.py stats

Exit codes: 0 ok, 1 usage/validation error, 2 integrity error.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import os
import re
import sqlite3
import sys
import textwrap
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SDD_DIR = REPO_ROOT / ".sdd"
DB_PATH = Path(os.environ.get("OSM_MEMORY_DB", SDD_DIR / "memory.db"))
DUMP_PATH = Path(os.environ.get("OSM_MEMORY_DUMP", SDD_DIR / "memory.sql"))

SCHEMA_VERSION = "1"

SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Requirements extracted from the specification document.
CREATE TABLE IF NOT EXISTS requirements (
    id          TEXT PRIMARY KEY,            -- FR-001 / NFR-001 / CON-001
    kind        TEXT NOT NULL,               -- functional|nonfunctional|constraint|prohibition
    title       TEXT NOT NULL,
    body        TEXT NOT NULL DEFAULT '',
    source      TEXT NOT NULL,               -- e.g. "spec:§5" (traceability to the .docx)
    priority    TEXT NOT NULL DEFAULT 'must',-- must|should|could|wont
    iteration   TEXT NOT NULL DEFAULT '',    -- I0..I7 per spec §13
    status      TEXT NOT NULL DEFAULT 'open',-- open|planned|in-progress|done|deferred
    created_at  TEXT NOT NULL,
    CHECK (kind IN ('functional','nonfunctional','constraint','prohibition')),
    CHECK (priority IN ('must','should','could','wont')),
    CHECK (status IN ('open','planned','in-progress','done','deferred'))
);

-- Research findings, each pinned to verifiable evidence.
CREATE TABLE IF NOT EXISTS research (
    id            TEXT PRIMARY KEY,          -- RF-001
    topic         TEXT NOT NULL,
    finding       TEXT NOT NULL,
    evidence_kind TEXT NOT NULL,             -- source|http|doc|web|reasoning
    evidence_ref  TEXT NOT NULL DEFAULT '',  -- absolute file path, URL, or API action
    confidence    TEXT NOT NULL DEFAULT 'high', -- high|medium|low
    created_at    TEXT NOT NULL,
    CHECK (evidence_kind IN ('source','http','doc','web','reasoning')),
    CHECK (confidence IN ('high','medium','low'))
);

-- Architecture Decision Records (mirrored to specs/adr/ as markdown).
CREATE TABLE IF NOT EXISTS decisions (
    id           TEXT PRIMARY KEY,           -- ADR-001
    title        TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'proposed', -- proposed|accepted|superseded|rejected
    context      TEXT NOT NULL DEFAULT '',
    decision     TEXT NOT NULL DEFAULT '',
    consequences TEXT NOT NULL DEFAULT '',
    alternatives TEXT NOT NULL DEFAULT '',
    supersedes   TEXT NOT NULL DEFAULT '',
    created_at   TEXT NOT NULL,
    CHECK (status IN ('proposed','accepted','superseded','rejected'))
);

-- Feature / gap inventory: commercial LabKey Sample Manager vs LabKey CE vs OSM.
CREATE TABLE IF NOT EXISTS features (
    id         TEXT PRIMARY KEY,             -- FEAT-001
    area       TEXT NOT NULL,                -- registry|storage|workflow|eln|search|audit|api|labkey|llm|ops|ui|security
    name       TEXT NOT NULL,
    detail     TEXT NOT NULL DEFAULT '',
    commercial TEXT NOT NULL DEFAULT 'unknown', -- yes|no|partial|unknown  (does LabKey Sample Manager have it)
    ce_support TEXT NOT NULL DEFAULT 'unknown', -- native|partial|custom|absent|unknown (LabKey CE)
    gap        TEXT NOT NULL DEFAULT 'unknown', -- none|low|medium|high  (effort for OSM)
    evidence   TEXT NOT NULL DEFAULT '',
    notes      TEXT NOT NULL DEFAULT '',
    CHECK (commercial IN ('yes','no','partial','unknown')),
    CHECK (ce_support IN ('native','partial','custom','absent','unknown')),
    CHECK (gap IN ('none','low','medium','high','unknown'))
);

-- Ordered, reviewable PR backlog.
CREATE TABLE IF NOT EXISTS backlog (
    id         TEXT PRIMARY KEY,             -- PR-001
    seq        INTEGER NOT NULL,             -- review/merge order
    title      TEXT NOT NULL,
    summary    TEXT NOT NULL DEFAULT '',
    acceptance TEXT NOT NULL DEFAULT '',     -- newline-separated acceptance criteria
    depends_on TEXT NOT NULL DEFAULT '',     -- comma-separated PR ids
    iteration  TEXT NOT NULL DEFAULT '',     -- I0..I7
    size       TEXT NOT NULL DEFAULT 'M',    -- XS|S|M|L
    branch     TEXT NOT NULL DEFAULT '',
    status     TEXT NOT NULL DEFAULT 'todo', -- todo|in-progress|review|done|blocked
    created_at TEXT NOT NULL,
    CHECK (size IN ('XS','S','M','L')),
    CHECK (status IN ('todo','in-progress','review','done','blocked'))
);

CREATE TABLE IF NOT EXISTS tasks (
    id         TEXT PRIMARY KEY,             -- T-001
    pr_id      TEXT NOT NULL REFERENCES backlog(id) ON DELETE CASCADE,
    seq        INTEGER NOT NULL DEFAULT 0,
    title      TEXT NOT NULL,
    detail     TEXT NOT NULL DEFAULT '',
    status     TEXT NOT NULL DEFAULT 'todo',
    created_at TEXT NOT NULL,
    CHECK (status IN ('todo','in-progress','done','blocked'))
);

-- How a claim about the environment was actually verified (never assume).
CREATE TABLE IF NOT EXISTS verifications (
    id          TEXT PRIMARY KEY,            -- V-001
    claim       TEXT NOT NULL,
    method      TEXT NOT NULL,               -- http|source|shell|doc
    command     TEXT NOT NULL DEFAULT '',
    result      TEXT NOT NULL,               -- pass|fail|partial
    detail      TEXT NOT NULL DEFAULT '',
    verified_at TEXT NOT NULL,
    CHECK (method IN ('http','source','shell','doc')),
    CHECK (result IN ('pass','fail','partial'))
);

-- Traceability graph: requirement -> artifact (feature, backlog item, adr, file...).
CREATE TABLE IF NOT EXISTS traceability (
    req_id        TEXT NOT NULL REFERENCES requirements(id) ON DELETE CASCADE,
    artifact_kind TEXT NOT NULL,             -- feature|backlog|decision|verification|file|spec
    artifact_ref  TEXT NOT NULL,
    PRIMARY KEY (req_id, artifact_kind, artifact_ref)
);

CREATE INDEX IF NOT EXISTS idx_backlog_seq      ON backlog(seq);
CREATE INDEX IF NOT EXISTS idx_tasks_pr         ON tasks(pr_id, seq);
CREATE INDEX IF NOT EXISTS idx_features_area    ON features(area);
CREATE INDEX IF NOT EXISTS idx_req_iteration    ON requirements(iteration);
CREATE INDEX IF NOT EXISTS idx_trace_artifact   ON traceability(artifact_kind, artifact_ref);
"""

# Tables in a stable order so the dump is byte-deterministic.
TABLES = [
    "meta", "requirements", "research", "decisions", "features",
    "backlog", "tasks", "verifications", "traceability",
]
# Deterministic ordering key per table (must be a unique ordering).
ORDER_BY = {
    "meta": "key",
    "requirements": "id",
    "research": "id",
    "decisions": "id",
    "features": "id",
    "backlog": "id",
    "tasks": "id",
    "verifications": "id",
    "traceability": "req_id, artifact_kind, artifact_ref",
}

ID_PATTERNS = {
    "requirements": re.compile(r"^(FR|NFR|CON|PRO)-\d{3}$"),
    "research": re.compile(r"^RF-\d{3}$"),
    # 4-digit ADR numbering per the reference SDD methodology (specs/adr/NNNN-*.md).
    "decisions": re.compile(r"^ADR-\d{4}$"),
    "features": re.compile(r"^FEAT-\d{3}$"),
    "backlog": re.compile(r"^PR-\d{3}$"),
    "tasks": re.compile(r"^T-\d{3}$"),
    "verifications": re.compile(r"^V-\d{3}$"),
}


class MemoryError_(Exception):
    """Fatal, user-facing error. Never swallowed silently."""


def now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def connect(create: bool = False) -> sqlite3.Connection:
    SDD_DIR.mkdir(parents=True, exist_ok=True)
    if not DB_PATH.exists() and not create:
        if DUMP_PATH.exists():
            # Auto-heal: the dump is the source of truth, the db is derived.
            rebuild(quiet=True)
        else:
            raise MemoryError_(
                f"no memory database at {DB_PATH} and no dump at {DUMP_PATH}; run: tools/memory.py init")
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA)
    conn.execute("INSERT OR REPLACE INTO meta(key,value) VALUES('schema_version',?)", (SCHEMA_VERSION,))
    conn.commit()


def validate_id(table: str, value: str) -> str:
    pat = ID_PATTERNS.get(table)
    if pat and not pat.match(value):
        raise MemoryError_(f"invalid id {value!r} for {table}; expected pattern {pat.pattern}")
    return value


def sql_literal(v) -> str:
    if v is None:
        return "NULL"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def dump(quiet: bool = False) -> None:
    """Write a deterministic SQL dump. This file is what git tracks."""
    if not DB_PATH.exists():
        raise MemoryError_(f"cannot dump: {DB_PATH} does not exist")
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    lines = [
        "-- OSM project memory database - deterministic dump.",
        "-- Source of truth in git. Regenerate the binary db with: tools/memory.py rebuild",
        "-- Do not hand-edit; use tools/memory.py.",
        "BEGIN TRANSACTION;",
    ]
    lines.append(SCHEMA.strip())
    for table in TABLES:
        cur = conn.execute(f"SELECT * FROM {table} ORDER BY {ORDER_BY[table]}")
        rows = cur.fetchall()
        if not rows:
            continue
        cols = [d[0] for d in cur.description]
        lines.append(f"-- {table}: {len(rows)} rows")
        collist = ",".join(cols)
        for r in rows:
            vals = ",".join(sql_literal(r[c]) for c in cols)
            lines.append(f"INSERT INTO {table}({collist}) VALUES({vals});")
    lines.append("COMMIT;")
    DUMP_PATH.parent.mkdir(parents=True, exist_ok=True)
    DUMP_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    conn.close()
    if not quiet:
        print(f"wrote {DUMP_PATH}")


def rebuild(quiet: bool = False) -> None:
    """Recreate the binary db from the committed dump. Deterministic."""
    if not DUMP_PATH.exists():
        raise MemoryError_(f"cannot rebuild: {DUMP_PATH} does not exist")
    if DB_PATH.exists():
        DB_PATH.unlink()
    SDD_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(DUMP_PATH.read_text(encoding="utf-8"))
    conn.commit()
    conn.close()
    if not quiet:
        print(f"rebuilt {DB_PATH} from {DUMP_PATH}")


def _insert(table: str, data: dict, replace: bool = False) -> None:
    if "id" in data:
        validate_id(table, data["id"])
    conn = connect()
    ensure_schema(conn)
    cols = ",".join(data)
    ph = ",".join("?" for _ in data)
    verb = "INSERT OR REPLACE" if replace else "INSERT"
    try:
        conn.execute(f"{verb} INTO {table}({cols}) VALUES({ph})", tuple(data.values()))
    except sqlite3.IntegrityError as e:
        raise MemoryError_(f"{table}: {e} (use --replace to overwrite)") from e
    conn.commit()
    conn.close()
    dump(quiet=True)
    print(f"{table}: {'updated' if replace else 'added'} {data.get('id', '')}".strip())


# --------------------------------------------------------------------------- CLI

def cmd_init(a):
    SDD_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    ensure_schema(conn)
    conn.execute("INSERT OR REPLACE INTO meta(key,value) VALUES('created_at',?)", (now(),))
    conn.execute("INSERT OR REPLACE INTO meta(key,value) VALUES('project',?)", ("open-sample-manager",))
    conn.commit()
    conn.close()
    dump(quiet=True)
    print(f"initialised {DB_PATH} (schema v{SCHEMA_VERSION}) and {DUMP_PATH}")


def cmd_add(a):
    ts = now()
    if a.what == "req":
        _insert("requirements", dict(id=a.id, kind=a.kind, title=a.title, body=a.body,
                                     source=a.source, priority=a.priority, iteration=a.iteration,
                                     status=a.status, created_at=ts), a.replace)
    elif a.what == "research":
        _insert("research", dict(id=a.id, topic=a.topic, finding=a.finding,
                                 evidence_kind=a.evidence_kind, evidence_ref=a.evidence_ref,
                                 confidence=a.confidence, created_at=ts), a.replace)
    elif a.what == "decision":
        _insert("decisions", dict(id=a.id, title=a.title, status=a.status, context=a.context,
                                  decision=a.decision, consequences=a.consequences,
                                  alternatives=a.alternatives, supersedes=a.supersedes,
                                  created_at=ts), a.replace)
    elif a.what == "feature":
        _insert("features", dict(id=a.id, area=a.area, name=a.name, detail=a.detail,
                                 commercial=a.commercial, ce_support=a.ce_support, gap=a.gap,
                                 evidence=a.evidence, notes=a.notes), a.replace)
    elif a.what == "backlog":
        _insert("backlog", dict(id=a.id, seq=a.seq, title=a.title, summary=a.summary,
                                acceptance=a.acceptance, depends_on=a.depends, iteration=a.iteration,
                                size=a.size, branch=a.branch, status=a.status, created_at=ts), a.replace)
    elif a.what == "task":
        _insert("tasks", dict(id=a.id, pr_id=a.pr, seq=a.seq, title=a.title, detail=a.detail,
                              status=a.status, created_at=ts), a.replace)
    elif a.what == "verification":
        _insert("verifications", dict(id=a.id, claim=a.claim, method=a.method, command=a.command,
                                      result=a.result, detail=a.detail, verified_at=ts), a.replace)
    else:  # pragma: no cover - argparse restricts choices
        raise MemoryError_(f"unknown entity {a.what}")


def cmd_link(a):
    conn = connect(); ensure_schema(conn)
    conn.execute("INSERT OR IGNORE INTO traceability(req_id,artifact_kind,artifact_ref) VALUES(?,?,?)",
                 (a.req, a.kind, a.to))
    conn.commit(); conn.close(); dump(quiet=True)
    print(f"linked {a.req} -> {a.kind}:{a.to}")


def cmd_set(a):
    """Update a single column of a single row, e.g. mark a PR done."""
    table = a.table
    if table not in TABLES:
        raise MemoryError_(f"unknown table {table}; one of {', '.join(TABLES)}")
    conn = connect()
    cols = {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}
    if a.column not in cols:
        raise MemoryError_(f"{table} has no column {a.column}; columns: {', '.join(sorted(cols))}")
    cur = conn.execute(f"UPDATE {table} SET {a.column}=? WHERE id=?", (a.value, a.id))
    if cur.rowcount == 0:
        raise MemoryError_(f"no row {a.id!r} in {table}")
    conn.commit(); conn.close(); dump(quiet=True)
    print(f"{table}.{a.id}.{a.column} = {a.value}")


def _print_rows(rows, cols=None, width=110):
    if not rows:
        print("(no rows)"); return
    cols = cols or list(rows[0].keys())
    for r in rows:
        head = " | ".join(str(r[c]) for c in cols[:3] if c in r.keys())
        print(f"- {head}")
        for c in cols[3:]:
            if c not in r.keys():
                continue
            v = r[c]
            if v in (None, ""):
                continue
            txt = str(v).replace("\n", "\n      ")
            print(textwrap.fill(f"    {c}: {txt}", width=width,
                                subsequent_indent="      ", replace_whitespace=False))


def cmd_list(a):
    conn = connect()
    table = a.table
    if table not in TABLES:
        raise MemoryError_(f"unknown table {table}; one of {', '.join(TABLES)}")
    order = "seq, id" if table in ("backlog", "tasks") else ORDER_BY[table]
    sql = f"SELECT * FROM {table}"
    params = []
    if a.where:
        sql += f" WHERE {a.where}"
    sql += f" ORDER BY {order}"
    rows = conn.execute(sql, params).fetchall()
    if a.brief:
        for r in rows:
            k = r["id"] if "id" in r.keys() else r[0]
            t = r["title"] if "title" in r.keys() else (r["name"] if "name" in r.keys() else "")
            extra = f"  [{r['status']}]" if "status" in r.keys() else ""
            print(f"{k}  {t}{extra}")
    else:
        _print_rows(rows)
    conn.close()


def cmd_show(a):
    conn = connect()
    found = False
    for table in TABLES:
        cols = {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}
        if "id" not in cols:
            continue
        rows = conn.execute(f"SELECT * FROM {table} WHERE id=?", (a.id,)).fetchall()
        if rows:
            found = True
            print(f"== {table} ==")
            for r in rows:
                for k in r.keys():
                    if r[k] not in (None, ""):
                        print(f"  {k}: {r[k]}")
    tr = conn.execute("SELECT * FROM traceability WHERE req_id=? OR artifact_ref=?",
                      (a.id, a.id)).fetchall()
    if tr:
        found = True
        print("== traceability ==")
        for r in tr:
            print(f"  {r['req_id']} -> {r['artifact_kind']}:{r['artifact_ref']}")
    conn.close()
    if not found:
        raise MemoryError_(f"nothing found for id {a.id!r}")


def cmd_query(a):
    stripped = a.sql.strip().lower()
    if not (stripped.startswith("select") or stripped.startswith("with")):
        raise MemoryError_("query accepts read-only SELECT/WITH statements only; use 'add'/'set' to mutate")
    conn = connect()
    try:
        rows = conn.execute(a.sql).fetchall()
    except sqlite3.Error as e:
        raise MemoryError_(f"sql error: {e}") from e
    if not rows:
        print("(no rows)")
    else:
        hdr = list(rows[0].keys())
        print(" | ".join(hdr))
        print("-+-".join("-" * len(h) for h in hdr))
        for r in rows:
            print(" | ".join("" if r[h] is None else str(r[h]) for h in hdr))
    conn.close()


def cmd_stats(a):
    conn = connect()
    print(f"db:   {DB_PATH}")
    print(f"dump: {DUMP_PATH}")
    for t in TABLES:
        n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"  {t:<14} {n:>5}")
    print("\nbacklog by status:")
    for r in conn.execute("SELECT status, COUNT(*) n FROM backlog GROUP BY status ORDER BY status"):
        print(f"  {r['status']:<12} {r['n']}")
    print("\nrequirements by iteration:")
    for r in conn.execute("SELECT iteration, COUNT(*) n FROM requirements GROUP BY iteration ORDER BY iteration"):
        print(f"  {r['iteration'] or '(none)':<12} {r['n']}")
    orphan = conn.execute(
        "SELECT COUNT(*) FROM requirements r WHERE NOT EXISTS "
        "(SELECT 1 FROM traceability t WHERE t.req_id = r.id)").fetchone()[0]
    print(f"\nrequirements with no traceability link: {orphan}")
    conn.close()


def cmd_check(a):
    """Integrity gate: run in CI / before commit. Non-zero exit on problems."""
    conn = connect()
    problems = []
    for r in conn.execute("SELECT id, depends_on FROM backlog WHERE depends_on <> ''"):
        for dep in [x.strip() for x in r["depends_on"].split(",") if x.strip()]:
            hit = conn.execute("SELECT 1 FROM backlog WHERE id=?", (dep,)).fetchone()
            if not hit:
                problems.append(f"{r['id']}: depends_on unknown PR {dep}")
    for r in conn.execute("SELECT id, supersedes FROM decisions WHERE supersedes <> ''"):
        if not conn.execute("SELECT 1 FROM decisions WHERE id=?", (r["supersedes"],)).fetchone():
            problems.append(f"{r['id']}: supersedes unknown ADR {r['supersedes']}")
    for r in conn.execute("SELECT DISTINCT artifact_ref FROM traceability WHERE artifact_kind='backlog'"):
        if not conn.execute("SELECT 1 FROM backlog WHERE id=?", (r["artifact_ref"],)).fetchone():
            problems.append(f"traceability points at unknown backlog item {r['artifact_ref']}")
    seqs = [r["seq"] for r in conn.execute("SELECT seq FROM backlog")]
    if len(seqs) != len(set(seqs)):
        problems.append("backlog seq values are not unique")
    conn.close()
    # The dump must match the db, otherwise the committed text is stale.
    if DUMP_PATH.exists():
        before = DUMP_PATH.read_text(encoding="utf-8")
        dump(quiet=True)
        if DUMP_PATH.read_text(encoding="utf-8") != before:
            problems.append(f"{DUMP_PATH} was stale and has been regenerated; commit it")
    if problems:
        print("INTEGRITY PROBLEMS:")
        for p in problems:
            print(f"  - {p}")
        sys.exit(2)
    print("memory integrity OK")


def cmd_batch(a):
    """Apply many subcommands from a file in one pass (one dump at the end).

    Each non-empty, non-``#`` line is a shell-quoted argv for a mutating
    subcommand, e.g.::

        add req --id FR-001 --title "Chain of custody" --source "spec:§1"
        link --req FR-001 --kind backlog --to PR-003

    The whole batch is applied or the first failure aborts with a non-zero exit;
    partial application is reported explicitly so nothing fails silently.
    """
    import shlex
    path = Path(a.file)
    if not path.exists():
        raise MemoryError_(f"batch file not found: {path}")
    parser = build_parser()
    global dump
    real_dump = dump
    applied = 0
    try:
        dump = lambda quiet=False: None  # noqa: E731 - suppress per-row dumps
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            argv = shlex.split(line)
            if argv[0] not in ("add", "link", "set"):
                raise MemoryError_(f"{path}:{lineno}: only add/link/set allowed in a batch, got {argv[0]!r}")
            try:
                ns = parser.parse_args(argv)
            except SystemExit as e:
                raise MemoryError_(f"{path}:{lineno}: bad arguments: {line}") from e
            try:
                ns.fn(ns)
            except MemoryError_ as e:
                raise MemoryError_(f"{path}:{lineno}: {e} (after {applied} rows applied)") from e
            applied += 1
    finally:
        dump = real_dump
        if applied:
            dump(quiet=True)
    print(f"batch: applied {applied} statements from {path}")


def cmd_dump(a):
    dump()


def cmd_rebuild(a):
    rebuild()


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="memory.py", description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("init", help="create an empty memory database").set_defaults(fn=cmd_init)
    sub.add_parser("dump", help="write .sdd/memory.sql from the db").set_defaults(fn=cmd_dump)
    sub.add_parser("rebuild", help="rebuild the db from .sdd/memory.sql").set_defaults(fn=cmd_rebuild)
    sub.add_parser("stats", help="row counts and rollups").set_defaults(fn=cmd_stats)
    sub.add_parser("check", help="integrity gate (exit 2 on problems)").set_defaults(fn=cmd_check)

    a = sub.add_parser("add", help="add an entry")
    a.set_defaults(fn=cmd_add)
    asub = a.add_subparsers(dest="what", required=True)

    def common(sp):
        sp.add_argument("--id", required=True)
        sp.add_argument("--replace", action="store_true", help="overwrite an existing row")

    sp = asub.add_parser("req"); common(sp)
    sp.add_argument("--kind", default="functional",
                    choices=["functional", "nonfunctional", "constraint", "prohibition"])
    sp.add_argument("--title", required=True)
    sp.add_argument("--body", default="")
    sp.add_argument("--source", required=True, help='traceability, e.g. "spec:§5"')
    sp.add_argument("--priority", default="must", choices=["must", "should", "could", "wont"])
    sp.add_argument("--iteration", default="")
    sp.add_argument("--status", default="open",
                    choices=["open", "planned", "in-progress", "done", "deferred"])

    sp = asub.add_parser("research"); common(sp)
    sp.add_argument("--topic", required=True)
    sp.add_argument("--finding", required=True)
    sp.add_argument("--evidence-kind", default="source",
                    choices=["source", "http", "doc", "web", "reasoning"])
    sp.add_argument("--evidence-ref", default="")
    sp.add_argument("--confidence", default="high", choices=["high", "medium", "low"])

    sp = asub.add_parser("decision"); common(sp)
    sp.add_argument("--title", required=True)
    sp.add_argument("--status", default="accepted",
                    choices=["proposed", "accepted", "superseded", "rejected"])
    sp.add_argument("--context", default="")
    sp.add_argument("--decision", default="")
    sp.add_argument("--consequences", default="")
    sp.add_argument("--alternatives", default="")
    sp.add_argument("--supersedes", default="")

    sp = asub.add_parser("feature"); common(sp)
    sp.add_argument("--area", required=True)
    sp.add_argument("--name", required=True)
    sp.add_argument("--detail", default="")
    sp.add_argument("--commercial", default="unknown", choices=["yes", "no", "partial", "unknown"])
    sp.add_argument("--ce-support", default="unknown",
                    choices=["native", "partial", "custom", "absent", "unknown"])
    sp.add_argument("--gap", default="unknown", choices=["none", "low", "medium", "high", "unknown"])
    sp.add_argument("--evidence", default="")
    sp.add_argument("--notes", default="")

    sp = asub.add_parser("backlog"); common(sp)
    sp.add_argument("--seq", type=int, required=True)
    sp.add_argument("--title", required=True)
    sp.add_argument("--summary", default="")
    sp.add_argument("--acceptance", default="")
    sp.add_argument("--depends", default="")
    sp.add_argument("--iteration", default="")
    sp.add_argument("--size", default="M", choices=["XS", "S", "M", "L"])
    sp.add_argument("--branch", default="")
    sp.add_argument("--status", default="todo",
                    choices=["todo", "in-progress", "review", "done", "blocked"])

    sp = asub.add_parser("task"); common(sp)
    sp.add_argument("--pr", required=True)
    sp.add_argument("--seq", type=int, default=0)
    sp.add_argument("--title", required=True)
    sp.add_argument("--detail", default="")
    sp.add_argument("--status", default="todo", choices=["todo", "in-progress", "done", "blocked"])

    sp = asub.add_parser("verification"); common(sp)
    sp.add_argument("--claim", required=True)
    sp.add_argument("--method", default="http", choices=["http", "source", "shell", "doc"])
    sp.add_argument("--command", default="")
    sp.add_argument("--result", default="pass", choices=["pass", "fail", "partial"])
    sp.add_argument("--detail", default="")

    sp = sub.add_parser("link", help="link a requirement to an artifact")
    sp.set_defaults(fn=cmd_link)
    sp.add_argument("--req", required=True)
    sp.add_argument("--kind", required=True,
                    choices=["feature", "backlog", "decision", "verification", "file", "spec"])
    sp.add_argument("--to", required=True)

    sp = sub.add_parser("set", help="update one column of one row")
    sp.set_defaults(fn=cmd_set)
    sp.add_argument("table"); sp.add_argument("id")
    sp.add_argument("column"); sp.add_argument("value")

    sp = sub.add_parser("list", help="list a table")
    sp.set_defaults(fn=cmd_list)
    sp.add_argument("table")
    sp.add_argument("--where", default="")
    sp.add_argument("--brief", action="store_true")

    sp = sub.add_parser("show", help="show everything about an id")
    sp.set_defaults(fn=cmd_show)
    sp.add_argument("id")

    sp = sub.add_parser("batch", help="apply add/link/set lines from a file in one pass")
    sp.set_defaults(fn=cmd_batch)
    sp.add_argument("file")

    sp = sub.add_parser("query", help="read-only SQL")
    sp.set_defaults(fn=cmd_query)
    sp.add_argument("sql")

    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        args.fn(args)
    except MemoryError_ as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
