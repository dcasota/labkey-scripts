"""The memory CLI: round trips, determinism, and the failures it must catch.

`tools/memory.py` is load-bearing for the whole project — it is how every later
session reads what is already known. These tests assert the **denials** as much
as the happy paths: a knowledge base that silently accepts a dangling reference
or a stale dump is worse than none, because it looks authoritative.
"""
from __future__ import annotations

import sqlite3

import pytest

# A representative row of each kind, used across several tests.
REQ = ("add", "req", "--id", "FR-001", "--title", "Chain of custody",
       "--source", "spec:§1", "--kind", "functional", "--iteration", "I0")
PR = ("add", "backlog", "--id", "PR-001", "--seq", "1", "--title", "Scaffolding")


# --- initialisation ----------------------------------------------------------

def test_init_creates_both_the_database_and_the_dump(mem_uninitialised):
    mem = mem_uninitialised
    assert not mem.db.exists() and not mem.dump.exists()
    result = mem.run("init")
    assert result.ok, result
    assert mem.db.exists(), "the binary database was not created"
    assert mem.dump.exists(), "the tracked dump was not created"
    assert "schema_version" in mem.read_dump()


def test_a_command_on_a_missing_database_with_no_dump_fails_clearly(mem_uninitialised):
    result = mem_uninitialised.run("stats")
    assert not result.ok
    assert "memory.py init" in result.output


def test_a_missing_binary_database_is_rebuilt_from_the_dump(mem):
    """A fresh clone has the dump and no database. It must self-heal rather than
    demanding a ceremony."""
    mem.must(*REQ)
    mem.db.unlink()
    result = mem.run("list", "requirements", "--brief")
    assert result.ok, result
    assert "FR-001" in result.stdout


# --- add / show / list round trip --------------------------------------------

def test_add_then_show_round_trips_every_field(mem):
    mem.must("add", "req", "--id", "FR-042", "--title", "A title",
             "--body", "A body", "--source", "spec:§5", "--kind", "constraint",
             "--priority", "should", "--iteration", "I2", "--status", "planned")
    shown = mem.must("show", "FR-042").stdout
    for fragment in ("FR-042", "A title", "A body", "spec:§5", "constraint",
                     "should", "I2", "planned"):
        assert fragment in shown, f"{fragment!r} did not survive the round trip"


@pytest.mark.parametrize(
    "args",
    [
        ("add", "research", "--id", "RF-001", "--topic", "T", "--finding", "F"),
        ("add", "decision", "--id", "ADR-0001", "--title", "D"),
        ("add", "feature", "--id", "FEAT-001", "--area", "registry", "--name", "N"),
        ("add", "verification", "--id", "V-001", "--claim", "C"),
        PR,
        REQ,
    ],
)
def test_every_entity_kind_can_be_added(mem, args):
    assert mem.run(*args).ok


def test_a_task_can_be_attached_to_a_backlog_item(mem):
    mem.must(*PR)
    mem.must("add", "task", "--id", "T-001", "--pr", "PR-001", "--title", "Do the thing")
    assert "T-001" in mem.must("list", "tasks", "--brief").stdout


def test_list_brief_shows_id_title_and_status(mem):
    mem.must(*REQ)
    line = mem.must("list", "requirements", "--brief").stdout
    assert "FR-001" in line and "Chain of custody" in line and "[open]" in line


def test_list_accepts_a_where_clause(mem):
    mem.must(*REQ)
    mem.must("add", "req", "--id", "FR-002", "--title", "Other",
             "--source", "spec:§2", "--iteration", "I3")
    filtered = mem.must("list", "requirements", "--where", "iteration='I3'", "--brief").stdout
    assert "FR-002" in filtered and "FR-001" not in filtered


def test_show_on_an_unknown_id_fails(mem):
    result = mem.run("show", "FR-999")
    assert not result.ok
    assert "nothing found" in result.output.lower()


def test_stats_reports_row_counts(mem):
    mem.must(*REQ)
    out = mem.must("stats").stdout
    assert "requirements" in out and "1" in out


# --- identifier discipline ---------------------------------------------------

@pytest.mark.parametrize(
    "entity, bad_id",
    [
        ("req", "FR-1"),          # not zero-padded
        ("req", "XX-001"),        # wrong prefix
        ("req", "fr-001"),        # wrong case
        ("research", "RF-1"),
        ("decision", "ADR-001"),  # ADRs are four digits
        ("feature", "FEATURE-001"),
        ("backlog", "PR-1"),
        ("verification", "VER-001"),
    ],
)
def test_a_malformed_identifier_is_refused(mem, entity, bad_id):
    """Identifier discipline is what makes cross-references reliable. A typo
    must fail at write time, not surface later as a dangling link."""
    args = {
        "req": ("add", "req", "--id", bad_id, "--title", "t", "--source", "s"),
        "research": ("add", "research", "--id", bad_id, "--topic", "t", "--finding", "f"),
        "decision": ("add", "decision", "--id", bad_id, "--title", "t"),
        "feature": ("add", "feature", "--id", bad_id, "--area", "a", "--name", "n"),
        "backlog": ("add", "backlog", "--id", bad_id, "--seq", "1", "--title", "t"),
        "verification": ("add", "verification", "--id", bad_id, "--claim", "c"),
    }[entity]
    result = mem.run(*args)
    assert not result.ok, f"{bad_id!r} was accepted for {entity}"
    assert "invalid id" in result.output


@pytest.mark.parametrize("good_id", ["FR-001", "NFR-999", "CON-012", "PRO-005"])
def test_every_requirement_prefix_is_accepted(mem, good_id):
    assert mem.run("add", "req", "--id", good_id, "--title", "t", "--source", "s").ok


# --- duplicate and constraint handling ---------------------------------------

def test_adding_the_same_identifier_twice_is_refused(mem):
    mem.must(*REQ)
    result = mem.run(*REQ)
    assert not result.ok
    assert "--replace" in result.output, "the error should say how to overwrite deliberately"


def test_replace_overwrites_deliberately(mem):
    mem.must(*REQ)
    mem.must("add", "req", "--id", "FR-001", "--title", "Revised title",
             "--source", "spec:§1", "--replace")
    assert "Revised title" in mem.must("show", "FR-001").stdout


@pytest.mark.parametrize(
    "args, bad_value",
    [
        (("add", "req", "--id", "FR-001", "--title", "t", "--source", "s",
          "--kind", "invented"), "invented"),
        (("add", "backlog", "--id", "PR-001", "--seq", "1", "--title", "t",
          "--size", "XXL"), "XXL"),
        (("add", "verification", "--id", "V-001", "--claim", "c",
          "--result", "maybe"), "maybe"),
    ],
)
def test_an_invalid_enumerated_value_is_refused(mem, args, bad_value):
    result = mem.run(*args)
    assert not result.ok
    assert bad_value in result.output or "choose from" in result.output


def test_a_task_referencing_an_unknown_backlog_item_is_refused(mem):
    """Enforced by a foreign key, so it cannot be bypassed."""
    result = mem.run("add", "task", "--id", "T-001", "--pr", "PR-404", "--title", "t")
    assert not result.ok
    assert "T-001" not in mem.must("list", "tasks").stdout


def test_linking_an_unknown_requirement_is_refused(mem):
    mem.must(*PR)
    result = mem.run("link", "--req", "FR-404", "--kind", "backlog", "--to", "PR-001")
    assert not result.ok, "a dangling traceability edge was accepted"
    assert "FR-404" in result.output or "foreign key" in result.output.lower()


def test_linking_a_known_requirement_succeeds_and_shows_up(mem):
    mem.must(*REQ)
    mem.must(*PR)
    mem.must("link", "--req", "FR-001", "--kind", "backlog", "--to", "PR-001")
    assert "PR-001" in mem.must("show", "FR-001").stdout


# --- set ---------------------------------------------------------------------

def test_set_updates_one_column(mem):
    mem.must(*PR)
    mem.must("set", "backlog", "PR-001", "status", "done")
    assert "done" in mem.must("show", "PR-001").stdout


@pytest.mark.parametrize(
    "args, expected",
    [
        (("set", "nosuchtable", "PR-001", "status", "done"), "unknown table"),
        (("set", "backlog", "PR-001", "nosuchcolumn", "x"), "no column"),
        (("set", "backlog", "PR-404", "status", "done"), "no row"),
        (("set", "backlog", "PR-001", "status", "invented"), "constraint"),
    ],
)
def test_set_refuses_bad_arguments(mem, args, expected):
    mem.must(*PR)
    result = mem.run(*args)
    assert not result.ok, f"{args} should have failed"
    assert expected in result.output.lower()


# --- query is read-only ------------------------------------------------------

def test_query_returns_rows(mem):
    mem.must(*REQ)
    out = mem.must("query", "SELECT id, title FROM requirements").stdout
    assert "FR-001" in out and "Chain of custody" in out


def test_query_supports_a_common_table_expression(mem):
    mem.must(*REQ)
    assert mem.run("query", "WITH x AS (SELECT 1 AS n) SELECT n FROM x").ok


@pytest.mark.parametrize(
    "statement",
    [
        "DELETE FROM requirements",
        "DROP TABLE requirements",
        "UPDATE requirements SET title='x'",
        "INSERT INTO requirements(id) VALUES('FR-002')",
        "  delete from requirements  ",
        "PRAGMA writable_schema=1",
    ],
)
def test_query_refuses_to_mutate(mem, statement):
    """The read-only guarantee is what lets any session run `query` freely."""
    mem.must(*REQ)
    result = mem.run("query", statement)
    assert not result.ok, f"{statement!r} was allowed through the read-only path"
    assert "read-only" in result.output
    assert mem.run("query", "SELECT COUNT(*) AS n FROM requirements").stdout.strip().endswith("1")


def test_a_malformed_query_reports_the_sql_error(mem):
    result = mem.run("query", "SELECT nosuchcolumn FROM requirements")
    assert not result.ok
    assert "sql error" in result.output.lower()


# --- determinism -------------------------------------------------------------

def test_dump_is_byte_identical_across_a_rebuild_cycle(mem):
    """The property that makes the dump reviewable: identical content must
    always produce identical text, or every commit churns."""
    mem.batch(
        "add req --id FR-001 --title 'One' --source 'spec:§1'\n"
        "add req --id FR-002 --title 'Two' --source 'spec:§2'\n"
        "add backlog --id PR-001 --seq 1 --title 'Scaffold'\n"
        "add backlog --id PR-002 --seq 2 --title 'Next' --depends PR-001\n"
        "add decision --id ADR-0001 --title 'A decision'\n"
        "link --req FR-001 --kind backlog --to PR-001\n"
        "link --req FR-002 --kind backlog --to PR-002\n"
    )
    first = mem.read_dump()
    mem.must("rebuild")
    mem.must("dump")
    assert mem.read_dump() == first, "dump -> db -> dump was not byte-identical"


def test_insertion_order_does_not_affect_the_dump(mem, tmp_path):
    """Row order in the dump is explicit, so two sessions adding the same
    knowledge in different orders produce the same text and do not conflict."""
    mem.batch("add req --id FR-002 --title 'Two' --source 's2'\n"
              "add req --id FR-001 --title 'One' --source 's1'\n")
    reversed_dump = mem.read_dump()

    other = type(mem)(tmp_path / "other")
    other.workdir.mkdir()
    other.init()
    other.batch("add req --id FR-001 --title 'One' --source 's1'\n"
                "add req --id FR-002 --title 'Two' --source 's2'\n")
    # created_at differs by design; compare the rest.
    def strip_timestamps(text: str) -> list[str]:
        import re
        return [re.sub(r"'\d{4}-\d{2}-\d{2}T[\d:]+Z'", "'TS'", line)
                for line in text.splitlines() if line.startswith("INSERT INTO requirements")]

    assert strip_timestamps(reversed_dump) == strip_timestamps(other.read_dump())


def test_rebuild_reconstructs_the_database_exactly(mem):
    mem.batch("add req --id FR-001 --title 'One' --source 's'\n"
              "add backlog --id PR-001 --seq 1 --title 'S'\n"
              "link --req FR-001 --kind backlog --to PR-001\n")
    before = mem.must("stats").stdout
    mem.db.unlink()
    mem.must("rebuild")
    assert mem.must("stats").stdout == before


def test_rebuild_without_a_dump_fails(mem):
    mem.dump.unlink()
    result = mem.run("rebuild")
    assert not result.ok
    assert "does not exist" in result.output


# --- the integrity gate ------------------------------------------------------

def test_check_passes_on_a_consistent_database(mem):
    mem.batch("add req --id FR-001 --title 'One' --source 's'\n"
              "add backlog --id PR-001 --seq 1 --title 'S'\n"
              "link --req FR-001 --kind backlog --to PR-001\n")
    result = mem.run("check")
    assert result.ok, result
    assert "OK" in result.stdout


def test_check_fails_on_a_dangling_backlog_dependency(mem):
    mem.must("add", "backlog", "--id", "PR-002", "--seq", "2", "--title", "t",
             "--depends", "PR-404")
    result = mem.run("check")
    assert result.returncode == 2, result
    assert "PR-404" in result.output


def test_check_fails_on_a_duplicate_sequence_number(mem):
    mem.must("add", "backlog", "--id", "PR-001", "--seq", "7", "--title", "a")
    mem.must("add", "backlog", "--id", "PR-002", "--seq", "7", "--title", "b")
    result = mem.run("check")
    assert result.returncode == 2, result
    assert "seq" in result.output


def test_check_fails_on_an_untraced_requirement(mem):
    """A requirement nobody plans to build is a planning hole, and the gate must
    say so rather than leaving it to be noticed by eye."""
    mem.must(*REQ)
    result = mem.run("check")
    assert result.returncode == 2, result
    assert "FR-001" in result.output


def test_check_fails_on_a_traceability_edge_to_an_unknown_backlog_item(mem):
    """Written directly to the database, bypassing the CLI, to prove the gate
    catches damage the CLI would have refused."""
    mem.must(*REQ)
    mem.must(*PR)
    mem.must("link", "--req", "FR-001", "--kind", "backlog", "--to", "PR-001")
    with sqlite3.connect(mem.db) as conn:
        conn.execute("UPDATE traceability SET artifact_ref='PR-404'")
    result = mem.run("check")
    assert result.returncode == 2, result
    assert "PR-404" in result.output


def test_check_fails_on_a_traceability_edge_to_an_unknown_decision(mem):
    mem.must(*REQ)
    mem.must("add", "decision", "--id", "ADR-0001", "--title", "D")
    mem.must("link", "--req", "FR-001", "--kind", "decision", "--to", "ADR-0001")
    with sqlite3.connect(mem.db) as conn:
        conn.execute("UPDATE traceability SET artifact_ref='ADR-0404'")
    result = mem.run("check")
    assert result.returncode == 2, result
    assert "ADR-0404" in result.output


def test_check_fails_when_an_adr_supersedes_an_unknown_adr(mem):
    mem.must("add", "decision", "--id", "ADR-0002", "--title", "D",
             "--supersedes", "ADR-0404")
    result = mem.run("check")
    assert result.returncode == 2, result
    assert "ADR-0404" in result.output


def test_check_detects_and_repairs_a_stale_dump(mem):
    """The dump is what git tracks. If it drifts from the database, the commit
    would record knowledge that is not there."""
    mem.batch("add req --id FR-001 --title 'One' --source 's'\n"
              "add backlog --id PR-001 --seq 1 --title 'S'\n"
              "link --req FR-001 --kind backlog --to PR-001\n")
    assert mem.run("check").ok
    mem.dump.write_text("-- tampered\n", encoding="utf-8")
    result = mem.run("check")
    assert result.returncode == 2, result
    assert "stale" in result.output.lower()
    # It regenerates rather than only complaining, so the fix is one commit away.
    assert "FR-001" in mem.read_dump()
    assert mem.run("check").ok, "a second run should pass once the dump is rewritten"


# --- batch -------------------------------------------------------------------

def test_batch_applies_many_statements(mem):
    result = mem.batch(
        "# a comment\n"
        "\n"
        "add req --id FR-001 --title 'One' --source 's'\n"
        "add req --id FR-002 --title 'Two' --source 's'\n"
    )
    assert result.ok, result
    assert "applied 2 statements" in result.stdout


def test_batch_ignores_comments_and_blank_lines(mem):
    result = mem.batch("\n\n# nothing here\n   \n# nor here\n")
    assert result.ok
    assert "applied 0 statements" in result.stdout


def test_batch_refuses_a_read_command(mem):
    """A batch file is a write transcript. Allowing reads would make its effect
    depend on output nobody captures."""
    result = mem.batch("list requirements\n")
    assert not result.ok
    assert "only add/link/set" in result.output


def test_batch_reports_the_line_number_and_how_far_it_got(mem):
    result = mem.batch(
        "add req --id FR-001 --title 'One' --source 's'\n"
        "add req --id BROKEN --title 'Two' --source 's'\n"
        "add req --id FR-003 --title 'Three' --source 's'\n"
    )
    assert not result.ok
    assert ":2:" in result.output, "the failing line number should be named"
    assert "1 rows applied" in result.output, "partial application must be explicit"


def test_batch_leaves_the_dump_consistent_after_a_partial_failure(mem):
    """Nothing may fail silently: rows that were applied must be in the dump."""
    mem.batch("add req --id FR-001 --title 'One' --source 's'\n"
              "add req --id NOPE --title 'Two' --source 's'\n")
    assert "FR-001" in mem.read_dump()


def test_batch_on_a_missing_file_fails(mem):
    result = mem.run("batch", str(mem.workdir / "nope.txt"))
    assert not result.ok
    assert "not found" in result.output


def test_batch_writes_the_dump_once_and_the_result_matches_a_manual_dump(mem):
    mem.batch("add req --id FR-001 --title 'One' --source 's'\n"
              "add req --id FR-002 --title 'Two' --source 's'\n")
    after_batch = mem.read_dump()
    mem.must("dump")
    assert mem.read_dump() == after_batch
