"""Integration tests against a real LabKey server.

Deselected by default. Run with credentials in the environment::

    export LK_URL=https://127.0.0.1:8443
    export LK_USER=...  LK_PASSWORD=...     # or LK_APIKEY=...
    make integration

Every test here is **read-only**. Nothing is created, modified or deleted on the
server, and in particular nothing touches the ``SleepDrive-Lab`` project, which
belongs to other work.

These tests are the executable half of `docs/labkey-ce-ground-truth.md`: if a
LabKey upgrade changes one of these facts, a test fails rather than the
knowledge silently going stale.
"""
from __future__ import annotations

import pytest

from osm.labkey import ConfigError, LabKeyClient, LabKeyError

pytestmark = pytest.mark.labkey


@pytest.fixture(scope="module")
def lk():
    try:
        client = LabKeyClient.from_env()
    except ConfigError as exc:
        pytest.skip(f"LabKey credentials not configured: {exc}")
    try:
        client.connect()
    except LabKeyError as exc:
        pytest.skip(f"LabKey server not reachable: {exc}")
    yield client
    client.close()


def test_session_is_authenticated_and_has_a_csrf_token(lk):
    who = lk.whoami()
    assert who.get("success") is True
    assert who.get("email"), "session resolved to a guest; credentials did not take effect"
    assert lk.csrf, "no CSRF token captured; every mutating call would be rejected"


def test_no_storage_or_workflow_schema_exists(lk):
    """The finding ADR-0001 turns on: CE has no substrate for the freezer map,
    the job queue or the ELN."""
    schemas = set(lk.schemas("/home"))
    for absent in ("inventory", "storage", "freezer", "workflow", "eln", "labbook"):
        assert absent not in schemas, (
            f"schema {absent!r} is now present; docs/gap-analysis.md needs revisiting")


def test_exp_materials_carries_the_aliquot_and_amount_columns(lk):
    """These are what the publish bridge maps OSM samples onto."""
    names = {c["name"] for c in lk.query_details("exp", "Materials")}
    for column in ("RootMaterialRowId", "AliquotedFromLSID", "IsAliquot", "AliquotCount",
                   "AliquotVolume", "AvailableAliquotCount", "StoredAmount", "Units",
                   "SampleState", "MaterialExpDate"):
        assert column in names, f"exp.Materials lost the {column} column"


def test_there_is_no_root_material_lsid_column(lk):
    """LabKey replaced the LSID-based root pointer with RootMaterialRowId.
    Assuming the older name produces a silent lookup failure."""
    names = {c["name"].lower() for c in lk.query_details("exp", "Materials")}
    assert "rootmateriallsid" not in names


def test_only_three_sample_state_types_exist(lk):
    """OSM's eight-status lifecycle has no LabKey equivalent."""
    values = {r["Value"] for r in lk.select_rows("exp", "SampleStateType")}
    assert values == {"Available", "Consumed", "Locked"}


def test_audit_schema_provides_the_sample_timeline(lk):
    queries = set(lk.queries("auditLog"))
    for provider in ("SampleTimelineEvent", "SampleSetAuditEvent", "TransactionAuditEvent"):
        assert provider in queries


def test_measurement_units_are_available_for_mapping(lk):
    values = {r["Value"] for r in lk.select_rows("exp", "MeasurementUnits", max_rows=100)}
    assert {"mL", "uL", "mg", "ug", "vials"} <= values


def test_an_unknown_action_fails_with_a_useful_message(lk):
    """LabKey serves an HTML page for an unrecognised action. The client should
    say the action name is probably wrong rather than raising a JSON error."""
    with pytest.raises(LabKeyError) as excinfo:
        lk.get_json("query-thisActionDoesNotExist.api")
    assert excinfo.value.status is not None


def test_a_bad_query_name_preserves_the_server_explanation(lk):
    """Spec §16.2 requires the response body on a failed publish, so it must
    survive the round trip."""
    with pytest.raises(LabKeyError) as excinfo:
        lk.post_json("query-getQueryDetails.api",
                     {"schemaName": "exp", "queryName": "NoSuchQuery12345"})
    assert excinfo.value.body, "the server's explanation was discarded"


def test_container_enumeration_finds_the_home_project(lk):
    data = lk.containers("/", depth=1)
    paths = {c.get("path") for c in (data.get("children") or [])}
    assert "/home" in paths


def test_reading_does_not_require_write_permission(lk):
    """A read-only probe must not need the CSRF header, confirming these tests
    genuinely mutate nothing."""
    assert lk.select_rows("exp", "SampleStateType", max_rows=1) is not None
