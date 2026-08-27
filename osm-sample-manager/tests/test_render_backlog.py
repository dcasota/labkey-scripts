"""The backlog renderer, including drift detection.

`docs/backlog.md` and `specs/tasks/README.md` are generated. If they can drift
from the memory database without anyone noticing, the readable artefacts stop
describing the actual plan — so `--check` failing on drift is the property that
matters most here.
"""
from __future__ import annotations

import shutil

import pytest

SEED = (
    "add req --id FR-001 --title 'Chain of custody' --source 'spec:§1' --iteration I0\n"
    "add req --id NFR-001 --title 'Latency' --source 'spec:§14' --kind nonfunctional "
    "--iteration I0\n"
    "add backlog --id PR-001 --seq 1 --iteration I0 --size S --title 'Scaffolding' "
    "--summary 'Set things up' --acceptance 'First thing | Second thing'\n"
    "add backlog --id PR-002 --seq 2 --iteration I1 --size M --title 'Registry' "
    "--depends PR-001 --acceptance 'Registers a sample'\n"
    "link --req FR-001 --kind backlog --to PR-001\n"
    "link --req NFR-001 --kind backlog --to PR-002\n"
)


@pytest.fixture
def rendered(mem, tmp_path):
    """A seeded database rendered into an isolated output directory."""
    assert mem.batch(SEED).ok
    out = tmp_path / "out"
    result = mem.render("--out-dir", str(out))
    assert result.ok, result
    return out


def backlog_md(out):
    return (out / "docs" / "backlog.md").read_text(encoding="utf-8")


def tasks_md(out):
    return (out / "specs" / "tasks" / "README.md").read_text(encoding="utf-8")


# --- rendering ---------------------------------------------------------------

def test_both_artefacts_are_written(rendered):
    assert (rendered / "docs" / "backlog.md").exists()
    assert (rendered / "specs" / "tasks" / "README.md").exists()


def test_the_backlog_lists_every_item_in_sequence_order(rendered):
    text = backlog_md(rendered)
    assert text.index("PR-001") < text.index("PR-002")


def test_acceptance_criteria_are_rendered_as_separate_checkboxes(rendered):
    text = backlog_md(rendered)
    assert "- [ ] First thing" in text
    assert "- [ ] Second thing" in text


def test_dependencies_are_shown(rendered):
    assert "PR-001" in backlog_md(rendered).split("### PR-002")[1]


def test_requirements_are_shown_against_their_item(rendered):
    section = backlog_md(rendered).split("### PR-001")[1].split("### ")[0]
    assert "FR-001" in section


def test_the_task_index_carries_the_traceability_matrix(rendered):
    text = tasks_md(rendered)
    assert "Requirement to Task Mapping" in text
    assert "FR-001" in text and "PR-001" in text
    assert "spec:§1" in text, "the spec section should reach the task index"


def test_an_iteration_gate_is_described(rendered):
    assert "Acceptance gate" in tasks_md(rendered)


def test_rendering_is_deterministic(mem, tmp_path):
    mem.batch(SEED)
    first, second = tmp_path / "a", tmp_path / "b"
    mem.render("--out-dir", str(first))
    mem.render("--out-dir", str(second))
    assert backlog_md(first) == backlog_md(second)
    assert tasks_md(first) == tasks_md(second)


# --- drift detection ---------------------------------------------------------

def test_check_passes_when_the_output_is_current(mem, rendered):
    result = mem.render("--check", "--out-dir", str(rendered))
    assert result.ok, result
    assert "current" in result.stdout


def test_check_detects_drift_after_the_database_changes(mem, rendered):
    """The case that matters: someone edits the backlog and forgets to render."""
    assert mem.run("set", "backlog", "PR-001", "status", "done").ok
    result = mem.render("--check", "--out-dir", str(rendered))
    assert result.returncode == 2, result
    assert "STALE" in result.stdout
    assert "docs/backlog.md" in result.stdout


def test_check_detects_drift_when_a_new_item_is_added(mem, rendered):
    assert mem.run("add", "backlog", "--id", "PR-003", "--seq", "3", "--title", "New").ok
    assert mem.render("--check", "--out-dir", str(rendered)).returncode == 2


def test_check_detects_a_hand_edited_file(mem, rendered):
    """Hand-editing a generated file must be caught, not silently overwritten
    at some later unrelated moment."""
    target = rendered / "docs" / "backlog.md"
    target.write_text(target.read_text() + "\nhand edited\n", encoding="utf-8")
    assert mem.render("--check", "--out-dir", str(rendered)).returncode == 2


def test_check_detects_a_missing_file(mem, rendered):
    (rendered / "docs" / "backlog.md").unlink()
    assert mem.render("--check", "--out-dir", str(rendered)).returncode == 2


def test_check_does_not_write_anything(mem, rendered):
    before = backlog_md(rendered)
    mem.run("set", "backlog", "PR-001", "status", "done")
    mem.render("--check", "--out-dir", str(rendered))
    assert backlog_md(rendered) == before, "--check must not modify the tree"


def test_rendering_again_resolves_the_drift(mem, rendered):
    mem.run("set", "backlog", "PR-001", "status", "done")
    assert mem.render("--check", "--out-dir", str(rendered)).returncode == 2
    assert mem.render("--out-dir", str(rendered)).ok
    assert mem.render("--check", "--out-dir", str(rendered)).ok


# --- edge cases --------------------------------------------------------------

def test_an_empty_backlog_is_refused_rather_than_producing_empty_files(mem, tmp_path):
    """Rendering an empty backlog would silently blank two tracked files."""
    result = mem.render("--out-dir", str(tmp_path / "out"))
    assert not result.ok
    assert "empty" in result.output


def test_an_unknown_iteration_does_not_crash_the_renderer(mem, tmp_path):
    mem.batch("add req --id FR-001 --title 't' --source 's'\n"
              "add backlog --id PR-001 --seq 1 --iteration I9 --title 'Future'\n"
              "link --req FR-001 --kind backlog --to PR-001\n")
    out = tmp_path / "out"
    assert mem.render("--out-dir", str(out)).ok
    assert "I9" in backlog_md(out)


def test_an_item_with_no_acceptance_criteria_renders(mem, tmp_path):
    mem.batch("add req --id FR-001 --title 't' --source 's'\n"
              "add backlog --id PR-001 --seq 1 --iteration I0 --title 'Bare'\n"
              "link --req FR-001 --kind backlog --to PR-001\n")
    out = tmp_path / "out"
    assert mem.render("--out-dir", str(out)).ok
    assert "PR-001" in backlog_md(out)


def test_the_committed_artefacts_match_the_committed_database(repo_root):
    """The real repository, not a fixture: what is committed must be current."""
    import subprocess
    import sys

    completed = subprocess.run(
        [sys.executable, str(repo_root / "tools" / "render_backlog.py"), "--check"],
        capture_output=True, text=True, cwd=str(repo_root),
        env={k: v for k, v in __import__("os").environ.items()
             if k not in ("OSM_MEMORY_DB", "OSM_MEMORY_DUMP")},
    )
    assert completed.returncode == 0, (
        "docs/backlog.md or specs/tasks/README.md is stale; "
        f"run tools/render_backlog.py\n{completed.stdout}{completed.stderr}")


def test_out_dir_is_created_when_absent(mem, tmp_path):
    mem.batch(SEED)
    out = tmp_path / "deep" / "nested" / "out"
    assert mem.render("--out-dir", str(out)).ok
    assert (out / "docs" / "backlog.md").exists()
    shutil.rmtree(out)
