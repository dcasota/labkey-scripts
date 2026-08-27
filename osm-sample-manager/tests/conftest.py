"""Shared fixtures.

The memory CLI is tested through ``subprocess`` rather than by importing it,
because its path resolution happens at import time from the environment. Driving
the real command line is also what a later session actually does, so these tests
exercise the supported surface rather than an internal one.
"""
from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
MEMORY_CLI = REPO / "tools" / "memory.py"
RENDER_CLI = REPO / "tools" / "render_backlog.py"


@dataclass
class Result:
    """The outcome of one CLI invocation."""

    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0

    @property
    def output(self) -> str:
        """Both streams, for assertions that do not care which one carried it."""
        return self.stdout + self.stderr

    def __repr__(self) -> str:  # pragma: no cover - only used in failure output
        return (f"Result(rc={self.returncode})\n"
                f"--- stdout ---\n{self.stdout}\n--- stderr ---\n{self.stderr}")


class MemoryHarness:
    """Drives ``tools/memory.py`` against a throwaway database."""

    def __init__(self, workdir: Path):
        self.workdir = workdir
        self.db = workdir / "memory.db"
        self.dump = workdir / "memory.sql"

    def env(self) -> dict[str, str]:
        env = dict(os.environ)
        env["OSM_MEMORY_DB"] = str(self.db)
        env["OSM_MEMORY_DUMP"] = str(self.dump)
        return env

    def run(self, *args: str, script: Path = MEMORY_CLI) -> Result:
        completed = subprocess.run(
            [sys.executable, str(script), *args],
            capture_output=True, text=True, env=self.env(), cwd=str(REPO),
        )
        return Result(completed.returncode, completed.stdout, completed.stderr)

    def render(self, *args: str) -> Result:
        return self.run(*args, script=RENDER_CLI)

    def init(self) -> Result:
        result = self.run("init")
        assert result.ok, result
        return result

    def must(self, *args: str) -> Result:
        """Run a command that is expected to succeed."""
        result = self.run(*args)
        assert result.ok, result
        return result

    def batch(self, lines: str) -> Result:
        path = self.workdir / "batch.txt"
        path.write_text(lines, encoding="utf-8")
        return self.run("batch", str(path))

    def read_dump(self) -> str:
        return self.dump.read_text(encoding="utf-8")


@pytest.fixture
def mem(tmp_path: Path) -> MemoryHarness:
    """An initialised, empty memory database in a temporary directory."""
    harness = MemoryHarness(tmp_path)
    harness.init()
    return harness


@pytest.fixture
def mem_uninitialised(tmp_path: Path) -> MemoryHarness:
    """A harness pointing at paths that do not exist yet."""
    return MemoryHarness(tmp_path)


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO


@pytest.fixture(scope="session")
def tracked_files(repo_root: Path) -> list[Path]:
    """Every file git tracks. The unit of analysis for the secret scan."""
    completed = subprocess.run(
        ["git", "ls-files", "-z"], capture_output=True, text=True, cwd=str(repo_root))
    assert completed.returncode == 0, completed.stderr
    return [repo_root / name for name in completed.stdout.split("\0") if name]
