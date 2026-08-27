"""Invariants of the committed knowledge base itself.

`tests/test_memory_cli.py` tests the tool; this file tests the *data* the tool
is holding. These assertions are the ones that would otherwise be claims in a
report nobody re-checks: that every requirement is traced, that the backlog is a
directed acyclic graph, that no cross-reference dangles.

The database is read from the committed dump, so these tests describe what is in
git rather than what happens to be in a local working file.
"""
from __future__ import annotations

import re
import sqlite3
from collections import defaultdict

import pytest

ITERATIONS = {"I0", "I1", "I2", "I3", "I4", "I5", "I6", "I7"}


@pytest.fixture(scope="module")
def db(repo_root, tmp_path_factory):
    """The committed dump, loaded into a throwaway in-memory database."""
    dump = repo_root / ".sdd" / "memory.sql"
    assert dump.exists(), "the tracked memory dump is missing"
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(dump.read_text(encoding="utf-8"))
    conn.execute("PRAGMA foreign_keys = ON")
    yield conn
    conn.close()


def rows(db, sql, *params):
    return db.execute(sql, params).fetchall()


def scalar(db, sql, *params):
    return db.execute(sql, params).fetchone()[0]


# --- the dump is loadable and populated --------------------------------------

def test_the_dump_loads_without_error(db):
    assert scalar(db, "SELECT COUNT(*) FROM meta") >= 1


@pytest.mark.parametrize(
    "table, minimum",
    [("requirements", 90), ("research", 10), ("decisions", 8),
     ("features", 30), ("backlog", 30), ("verifications", 15)],
)
def test_each_table_is_populated(db, table, minimum):
    assert scalar(db, f"SELECT COUNT(*) FROM {table}") >= minimum


def test_the_schema_version_is_recorded(db):
    assert scalar(db, "SELECT value FROM meta WHERE key='schema_version'")


# --- requirements ------------------------------------------------------------

def test_every_requirement_identifier_is_well_formed(db):
    bad = [r["id"] for r in rows(db, "SELECT id FROM requirements")
           if not re.fullmatch(r"(FR|NFR|CON|PRO)-\d{3}", r["id"])]
    assert not bad, f"malformed requirement ids: {bad}"


def test_every_requirement_cites_a_specification_source(db):
    bad = [r["id"] for r in rows(db, "SELECT id, source FROM requirements")
           if not r["source"].strip()]
    assert not bad, f"requirements with no source: {bad}"


# A requirement may come from the specification document, or it may be harvested
# from an external source LabKey publishes. Those are the only two origins. A
# source prefix outside this set means somebody invented scope.
REQUIREMENT_SOURCE_PREFIXES = ("spec:", "labkey:")


def test_every_requirement_source_names_a_recognised_origin(db):
    """A requirement that cannot be traced back to the .docx or to a named
    external source is invented scope."""
    bad = [(r["id"], r["source"]) for r in rows(db, "SELECT id, source FROM requirements")
           if not r["source"].startswith(REQUIREMENT_SOURCE_PREFIXES)]
    assert not bad, (
        f"requirements whose source names no recognised origin: {bad}; "
        f"expected one of {REQUIREMENT_SOURCE_PREFIXES}")


def test_the_specification_remains_the_primary_source(db):
    """The .docx is the contract (see the PRD, Assumptions). If externally
    harvested requirements ever outnumbered it, the project would have drifted
    from the thing it agreed to build."""
    total = scalar(db, "SELECT COUNT(*) FROM requirements")
    from_spec = scalar(db, "SELECT COUNT(*) FROM requirements WHERE source LIKE 'spec:%'")
    assert from_spec > total - from_spec, (
        f"only {from_spec} of {total} requirements come from the specification; "
        "external harvesting has overtaken the contract")


def test_externally_sourced_requirements_cite_a_resolvable_url(db):
    """A `spec:` requirement points at a section of a document held in the
    repository. An externally sourced one points at somebody else's website,
    which can change or vanish, so it must carry the exact URL it came from as a
    traceability edge -- not merely a page name in its `source` field."""
    external = [r["id"] for r in rows(
        db, "SELECT id FROM requirements WHERE source NOT LIKE 'spec:%' ORDER BY id")]
    missing = [rid for rid in external if not scalar(
        db,
        "SELECT COUNT(*) FROM traceability "
        "WHERE req_id=? AND artifact_kind='spec' AND artifact_ref LIKE 'https://%'",
        rid)]
    assert not missing, (
        f"externally sourced requirements with no source URL: {missing}; "
        "add one with: tools/memory.py link --req <id> --kind spec --to <url>")


def test_no_requirement_is_untraced(db):
    """The headline claim: every requirement maps to something that will build
    it. An orphan is a planning hole."""
    orphans = [r["id"] for r in rows(
        db, "SELECT id FROM requirements r WHERE NOT EXISTS "
            "(SELECT 1 FROM traceability t WHERE t.req_id = r.id) ORDER BY id")]
    assert not orphans, f"{len(orphans)} untraced requirements: {orphans}"


def test_prohibitions_are_present_and_traced(db):
    """The specification forbids specific things (§16.2, §18.2). Those are
    requirements too, and a plan that drops them is incomplete."""
    prohibitions = [r["id"] for r in rows(
        db, "SELECT id FROM requirements WHERE kind='prohibition'")]
    assert len(prohibitions) >= 8, f"expected the §18.2 prohibitions, found {prohibitions}"
    for pid in prohibitions:
        assert scalar(db, "SELECT COUNT(*) FROM traceability WHERE req_id=?", pid) >= 1, (
            f"prohibition {pid} is not traced to anything that enforces it")


def test_every_declared_iteration_is_in_range(db):
    bad = [(r["id"], r["iteration"]) for r in rows(
        db, "SELECT id, iteration FROM requirements WHERE iteration <> ''")
        if r["iteration"] not in ITERATIONS]
    assert not bad, f"requirements with an iteration outside I0-I7: {bad}"


# --- traceability ------------------------------------------------------------

def test_no_traceability_edge_references_a_missing_requirement(db):
    dangling = [r["req_id"] for r in rows(
        db, "SELECT DISTINCT req_id FROM traceability t WHERE NOT EXISTS "
            "(SELECT 1 FROM requirements r WHERE r.id = t.req_id)")]
    assert not dangling, f"traceability edges from unknown requirements: {dangling}"


@pytest.mark.parametrize(
    "kind, table",
    [("backlog", "backlog"), ("decision", "decisions"),
     ("feature", "features"), ("verification", "verifications")],
)
def test_no_traceability_edge_dangles(db, kind, table):
    dangling = [r["artifact_ref"] for r in rows(
        db, f"SELECT DISTINCT artifact_ref FROM traceability t WHERE t.artifact_kind=? "
            f"AND NOT EXISTS (SELECT 1 FROM {table} x WHERE x.id = t.artifact_ref)", kind)]
    assert not dangling, f"traceability points at unknown {kind}: {dangling}"


def test_every_traceability_kind_is_one_of_the_declared_kinds(db):
    allowed = {"feature", "backlog", "decision", "verification", "file", "spec"}
    found = {r["artifact_kind"] for r in rows(
        db, "SELECT DISTINCT artifact_kind FROM traceability")}
    assert found <= allowed, f"unexpected traceability kinds: {found - allowed}"


# --- backlog -----------------------------------------------------------------

def test_every_backlog_identifier_is_well_formed(db):
    bad = [r["id"] for r in rows(db, "SELECT id FROM backlog")
           if not re.fullmatch(r"PR-\d{3}", r["id"])]
    assert not bad, f"malformed backlog ids: {bad}"


def test_backlog_sequence_numbers_are_unique(db):
    seqs = [r["seq"] for r in rows(db, "SELECT seq FROM backlog")]
    duplicates = sorted({s for s in seqs if seqs.count(s) > 1})
    assert not duplicates, f"duplicate seq values: {duplicates}"


def test_backlog_sequence_numbers_are_contiguous_from_one(db):
    seqs = sorted(r["seq"] for r in rows(db, "SELECT seq FROM backlog"))
    assert seqs == list(range(1, len(seqs) + 1)), "the review order has gaps"


def test_every_backlog_item_belongs_to_an_iteration(db):
    bad = [(r["id"], r["iteration"]) for r in rows(
        db, "SELECT id, iteration FROM backlog")
        if r["iteration"] not in ITERATIONS]
    assert not bad, f"backlog items outside I0-I7: {bad}"


def test_every_backlog_item_has_acceptance_criteria(db):
    """An item without a way to tell it is finished cannot be reviewed."""
    bad = [r["id"] for r in rows(db, "SELECT id, acceptance FROM backlog")
           if not r["acceptance"].strip()]
    assert not bad, f"backlog items with no acceptance criteria: {bad}"


def test_acceptance_criteria_are_multiple_and_bounded(db):
    """Sized to be reviewable in one sitting: more than one criterion, but not
    so many that the item should have been split."""
    for r in rows(db, "SELECT id, acceptance FROM backlog"):
        count = len([c for c in r["acceptance"].split("|") if c.strip()])
        assert 2 <= count <= 12, f"{r['id']} has {count} acceptance criteria"


def test_every_backlog_item_names_a_branch(db):
    bad = [r["id"] for r in rows(db, "SELECT id, branch FROM backlog")
           if not r["branch"].strip()]
    assert not bad, f"backlog items with no branch name: {bad}"


def test_branch_names_are_unique_and_match_their_identifier(db):
    seen = {}
    for r in rows(db, "SELECT id, branch FROM backlog"):
        number = r["id"].split("-")[1].lstrip("0") or "0"
        assert r["branch"].startswith(f"pr-{int(number):03d}-"), (
            f"{r['id']} branch {r['branch']!r} does not match its id")
        assert r["branch"] not in seen, f"branch {r['branch']} reused by {seen.get(r['branch'])}"
        seen[r["branch"]] = r["id"]


def test_backlog_dependencies_all_exist(db):
    ids = {r["id"] for r in rows(db, "SELECT id FROM backlog")}
    dangling = []
    for r in rows(db, "SELECT id, depends_on FROM backlog WHERE depends_on <> ''"):
        for dep in (d.strip() for d in r["depends_on"].split(",")):
            if dep and dep not in ids:
                dangling.append((r["id"], dep))
    assert not dangling, f"dependencies on unknown items: {dangling}"


def test_no_backlog_item_depends_on_itself(db):
    bad = [r["id"] for r in rows(db, "SELECT id, depends_on FROM backlog")
           if r["id"] in [d.strip() for d in r["depends_on"].split(",")]]
    assert not bad, f"self-dependent items: {bad}"


def test_the_backlog_dependency_graph_is_acyclic(db):
    """A cycle would make the plan unexecutable, and it is not visible by eye
    once the graph is more than a handful of nodes."""
    graph = {}
    for r in rows(db, "SELECT id, depends_on FROM backlog"):
        graph[r["id"]] = [d.strip() for d in r["depends_on"].split(",") if d.strip()]

    WHITE, GREY, BLACK = 0, 1, 2
    colour = defaultdict(int)
    cycle: list[str] = []

    def visit(node: str, path: list[str]) -> bool:
        colour[node] = GREY
        for dep in graph.get(node, []):
            if colour[dep] == GREY:
                cycle.extend(path[path.index(dep):] + [dep] if dep in path else [node, dep])
                return True
            if colour[dep] == WHITE and visit(dep, path + [dep]):
                return True
        colour[node] = BLACK
        return False

    for node in graph:
        if colour[node] == WHITE and visit(node, [node]):
            pytest.fail(f"dependency cycle: {' -> '.join(cycle)}")


def test_every_dependency_is_scheduled_earlier(db):
    """A topological order the sequence numbers actually respect, so working
    down the list never blocks."""
    order = {r["id"]: r["seq"] for r in rows(db, "SELECT id, seq FROM backlog")}
    bad = []
    for r in rows(db, "SELECT id, seq, depends_on FROM backlog WHERE depends_on <> ''"):
        for dep in (d.strip() for d in r["depends_on"].split(",")):
            if dep and order.get(dep, -1) >= r["seq"]:
                bad.append((r["id"], r["seq"], dep, order.get(dep)))
    assert not bad, f"dependencies scheduled at or after their dependent: {bad}"


def test_the_first_item_has_no_dependencies(db):
    first = db.execute("SELECT id, depends_on FROM backlog ORDER BY seq LIMIT 1").fetchone()
    assert first["depends_on"] == "", f"{first['id']} is first but depends on {first['depends_on']}"


def test_every_iteration_is_represented_in_the_backlog(db):
    covered = {r["iteration"] for r in rows(db, "SELECT DISTINCT iteration FROM backlog")}
    assert covered == ITERATIONS, f"iterations with no backlog items: {ITERATIONS - covered}"


# --- decisions ---------------------------------------------------------------

def test_every_decision_identifier_is_well_formed(db):
    bad = [r["id"] for r in rows(db, "SELECT id FROM decisions")
           if not re.fullmatch(r"ADR-\d{4}", r["id"])]
    assert not bad, f"malformed ADR ids: {bad}"


def test_decision_identifiers_are_contiguous_from_one(db):
    numbers = sorted(int(r["id"].split("-")[1]) for r in rows(db, "SELECT id FROM decisions"))
    assert numbers == list(range(1, len(numbers) + 1)), f"ADR numbering has gaps: {numbers}"


def test_every_decision_records_its_alternatives(db):
    """A decision with one option was not a decision."""
    bad = [r["id"] for r in rows(db, "SELECT id, alternatives FROM decisions")
           if not r["alternatives"].strip()]
    assert not bad, f"decisions with no alternatives recorded: {bad}"


def test_every_decision_records_context_and_consequences(db):
    for r in rows(db, "SELECT id, context, decision, consequences FROM decisions"):
        for field in ("context", "decision", "consequences"):
            assert r[field].strip(), f"{r['id']} has an empty {field}"


def test_no_decision_supersedes_a_missing_decision(db):
    ids = {r["id"] for r in rows(db, "SELECT id FROM decisions")}
    bad = [(r["id"], r["supersedes"]) for r in rows(
        db, "SELECT id, supersedes FROM decisions WHERE supersedes <> ''")
        if r["supersedes"] not in ids]
    assert not bad, f"decisions superseding unknown ADRs: {bad}"


def test_every_decision_has_a_markdown_file(db, repo_root):
    """The database and `specs/adr/` must agree, or one of them is lying."""
    files = {p.name.split("-")[0]: p for p in (repo_root / "specs" / "adr").glob("*.md")}
    for r in rows(db, "SELECT id FROM decisions"):
        number = r["id"].split("-")[1]
        assert number in files, f"{r['id']} has no file in specs/adr/"


def test_every_adr_file_has_a_database_row(db, repo_root):
    ids = {r["id"] for r in rows(db, "SELECT id FROM decisions")}
    for path in (repo_root / "specs" / "adr").glob("*.md"):
        number = path.name.split("-")[0]
        assert f"ADR-{number}" in ids, f"{path.name} has no row in the memory database"


def test_adr_files_declare_a_matching_heading(repo_root):
    for path in sorted((repo_root / "specs" / "adr").glob("*.md")):
        first = path.read_text(encoding="utf-8").splitlines()[0]
        number = path.name.split("-")[0]
        assert first.startswith(f"# ADR-{number}:"), (
            f"{path.name} heading does not match its filename: {first!r}")


# --- features ----------------------------------------------------------------

def test_every_feature_records_its_evidence(db):
    """The gap analysis is only worth something if each row can be checked."""
    bad = [r["id"] for r in rows(db, "SELECT id, evidence FROM features")
           if not r["evidence"].strip()]
    assert not bad, f"features with no evidence: {bad}"


def test_no_feature_leaves_the_labkey_assessment_unknown(db):
    """`unknown` means the research was not finished."""
    bad = [r["id"] for r in rows(
        db, "SELECT id FROM features WHERE ce_support='unknown' OR gap='unknown'")]
    assert not bad, f"features with an unfinished assessment: {bad}"


def test_the_areas_used_are_from_a_known_set(db):
    allowed = {"registry", "storage", "workflow", "eln", "search", "audit",
               "api", "labkey", "llm", "ops", "ui", "security", "assay"}
    found = {r["area"] for r in rows(db, "SELECT DISTINCT area FROM features")}
    assert found <= allowed, f"unexpected feature areas: {found - allowed}"


# --- verifications and research ----------------------------------------------

def test_every_verification_names_how_it_was_checked(db):
    bad = [r["id"] for r in rows(db, "SELECT id, command FROM verifications")
           if not r["command"].strip()]
    assert not bad, f"verifications with no command recorded: {bad}"


def test_no_verification_claims_reasoning_as_evidence(db):
    """Reasoning is never acceptable evidence for a behavioural claim."""
    assert scalar(db, "SELECT COUNT(*) FROM verifications WHERE method NOT IN "
                      "('http','source','shell','doc')") == 0


def test_every_research_finding_cites_an_evidence_reference(db):
    bad = [r["id"] for r in rows(db, "SELECT id, evidence_ref FROM research")
           if not r["evidence_ref"].strip()]
    assert not bad, f"research findings with no evidence reference: {bad}"


def test_no_research_finding_rests_on_reasoning_alone(db):
    bad = [r["id"] for r in rows(
        db, "SELECT id FROM research WHERE evidence_kind='reasoning'")]
    assert not bad, f"research findings resting on reasoning: {bad}"


def test_tasks_belong_to_a_known_backlog_item(db):
    dangling = [r["id"] for r in rows(
        db, "SELECT id, pr_id FROM tasks t WHERE NOT EXISTS "
            "(SELECT 1 FROM backlog b WHERE b.id = t.pr_id)")]
    assert not dangling, f"tasks orphaned from their backlog item: {dangling}"
