"""Secret-scanning regression test.

The project promises that no credential ever enters the repository. That promise
was checked by hand once during the bootstrap; this file turns it into a gate
that runs on every change.

The design that makes this work is the **allowlist of exact literals**. Anything
credential-shaped that is not on the list fails the test, so introducing a new
one is a deliberate act visible in the diff — which is the review gate we want.
Broadening a regex to make a failure go away is the wrong fix; adding a clearly
fake value to `ALLOWED_LITERALS`, or removing the secret, is the right one.

This file necessarily contains strings that *look* like credentials. None is
real, and none is a value that authenticates against anything.
"""
from __future__ import annotations

import re

import pytest

# --- files that are not source ------------------------------------------------

BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".zip",
                   ".gz", ".db", ".woff", ".woff2", ".ttf"}

#: This file is the scanner. It quotes the patterns it hunts for, so scanning it
#: would report itself.
SELF = "tests/test_no_secrets.py"


# --- high-signal patterns: always a finding, no allowlist -------------------

HIGH_SIGNAL = [
    (re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----"),
     "a private key block"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}"), "a GitHub token"),
    (re.compile(r"\bhf_[A-Za-z0-9]{34,}"), "a HuggingFace token"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "an AWS access key id"),
    (re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}"), "a Slack token"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
     "a JSON web token"),
    (re.compile(r"://[^/\s:@]+:[^/\s:@]{4,}@"), "a credential embedded in a URL"),
]


# --- credential-shaped assignments -------------------------------------------

#: `name = "value"`, `name: "value"`, `NAME=value` — the shapes a secret takes
#: when someone pastes one into source.
ASSIGNMENT = re.compile(
    r"""(?ix)
    \b(pass|passwd|password|pwd|secret|token|apikey|api_key|
       auth|credential|passphrase|private_key|access_key)
    [a-z0-9_]*
    \s*[:=]\s*
    (?P<quote>["'])(?P<value>[^"'\n]{6,})(?P=quote)
    """
)

#: Bare shell-style assignment, e.g. in a `.env` or a script.
BARE_ASSIGNMENT = re.compile(
    r"""(?ix)
    ^\s*(?:export\s+)?
    ([A-Z][A-Z0-9_]*(?:PASSWORD|PASSWD|SECRET|TOKEN|APIKEY|API_KEY|CREDENTIAL))
    =(?P<value>\S{6,})\s*$
    """,
    re.MULTILINE,
)

#: Exact literal values that are known-fake and deliberately present.
#: Adding to this list is a review decision. Keep each entry justified.
ALLOWED_LITERALS = {
    # Placeholders in prose, templates and documentation.
    "<from env>", "<user>", "...", "…", "value", "changeit",
    "your-token-here", "REPLACE_ME", "xxxxx",
    # Obviously-fake values used by the LabKey client tests.
    "unused-in-test",
    "hunter2-should-not-appear",
    "super-secret-value",
    "s3cret-password",
    "s3cret-key-value",
    "must-not-appear",
    "MUST-NOT-APPEAR-4f2a",
    "csrf-token-value",
    "wrong password",
    "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
    # Documentation of the *shape* of a LabKey credential, not a credential.
    "<hex>",
    # Names of environment variables, quoted in prose.
    "LK_PASSWORD", "LK_APIKEY", "HUGGINGFACE_API_KEY", "GITHUB_TOKEN",
}

#: Values shorter than this are not worth flagging: `"x"`, `"pw"`, `"k"` cannot
#: authenticate against anything and appear constantly in test fixtures.
MIN_INTERESTING = 6


def _iter_text_files(tracked_files, repo_root):
    for path in tracked_files:
        rel = str(path.relative_to(repo_root))
        if rel == SELF or path.suffix.lower() in BINARY_SUFFIXES:
            continue
        try:
            yield rel, path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, FileNotFoundError):
            continue


def _findings(tracked_files, repo_root):
    findings: list[str] = []
    for rel, text in _iter_text_files(tracked_files, repo_root):
        for lineno, line in enumerate(text.splitlines(), 1):
            for pattern, what in HIGH_SIGNAL:
                if pattern.search(line):
                    findings.append(f"{rel}:{lineno}: {what}")
        for match in ASSIGNMENT.finditer(text):
            value = match.group("value")
            if len(value) < MIN_INTERESTING or value in ALLOWED_LITERALS:
                continue
            if value.startswith("$") or value.startswith("{"):
                continue  # a variable reference, not a literal
            lineno = text[: match.start()].count("\n") + 1
            findings.append(f"{rel}:{lineno}: credential-shaped literal {value!r}")
        for match in BARE_ASSIGNMENT.finditer(text):
            # Strip surrounding quotes before judging: `NAME="$VAR"` is a
            # variable reference, not a literal, and so is `NAME='$VAR'`.
            value = match.group("value").strip("\"'")
            if not value or value in ALLOWED_LITERALS or value.startswith("$"):
                continue
            lineno = text[: match.start()].count("\n") + 1
            findings.append(f"{rel}:{lineno}: assigned credential {value!r}")
    return findings


# --- the gate ----------------------------------------------------------------

def test_no_credential_shaped_literal_is_tracked(tracked_files, repo_root):
    findings = _findings(tracked_files, repo_root)
    assert not findings, (
        "possible secrets in tracked files:\n  " + "\n  ".join(findings)
        + "\n\nIf a finding is a deliberate placeholder, add its exact value to "
          "ALLOWED_LITERALS in tests/test_no_secrets.py with a justification. "
          "Do not broaden the patterns."
    )


def test_the_env_template_declares_names_without_values(tracked_files, repo_root):
    """`.env.example` documents which variables exist. Every one must be empty
    or an obviously non-secret default."""
    template = repo_root / ".env.example"
    assert template.exists(), ".env.example is missing; contributors need the variable names"
    offenders = []
    for lineno, line in enumerate(template.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, _, value = line.partition("=")
        if any(word in name.upper() for word in ("PASSWORD", "APIKEY", "API_KEY",
                                                 "TOKEN", "SECRET")) and value.strip():
            offenders.append(f"{lineno}: {name}={value}")
    assert not offenders, f".env.example carries values for credentials: {offenders}"


def test_the_real_env_file_is_not_tracked(tracked_files, repo_root):
    tracked = {str(p.relative_to(repo_root)) for p in tracked_files}
    assert ".env" not in tracked, ".env must never be committed"


def test_gitignore_refuses_the_obvious_secret_shapes(repo_root):
    ignored = (repo_root / ".gitignore").read_text(encoding="utf-8")
    for pattern in (".env", "*.pem", "*.key", "secrets/"):
        assert pattern in ignored, f".gitignore should refuse {pattern}"


def test_the_binary_memory_database_is_not_tracked(tracked_files, repo_root):
    """It is derived, and a binary in git has no reviewable diff (ADR-0007)."""
    tracked = {str(p.relative_to(repo_root)) for p in tracked_files}
    assert ".sdd/memory.db" not in tracked
    assert ".sdd/memory.sql" in tracked, "the dump is the source of truth and must be tracked"


def test_the_repository_has_no_remote(repo_root):
    """Deliberate until GITHUB_TOKEN is supplied, so an accidental push of an
    early mistake cannot happen first (ADR-0008)."""
    import subprocess
    completed = subprocess.run(["git", "remote"], capture_output=True, text=True,
                               cwd=str(repo_root))
    assert completed.stdout.strip() == "", (
        f"unexpected git remote configured: {completed.stdout.strip()}")


# --- the scanner itself must work --------------------------------------------

@pytest.mark.parametrize(
    "content, why",
    [
        ('password = "correct-horse-battery"', "a quoted password literal"),
        ("LK_PASSWORD=Sup3rSecretValue", "a bare environment assignment"),
        ('api_key: "abcdef0123456789abcdef"', "a quoted api key"),
        ("-----BEGIN RSA PRIVATE KEY-----", "a private key header"),
        ("token = 'ghp_" + "A" * 36 + "'", "a GitHub token"),
        ("HUGGINGFACE_API_KEY=hf_" + "B" * 34, "a HuggingFace token"),
        ("url = 'https://user:hunter2pass@host/'", "a credential in a URL"),
        ("AWS = 'AKIA" + "A" * 16 + "'", "an AWS key id"),
    ],
)
def test_the_scanner_detects_a_planted_secret(tmp_path, repo_root, content, why):
    """A scanner that cannot fail is not a gate. Plant one and prove it fires."""
    planted = tmp_path / "planted.py"
    planted.write_text(content + "\n", encoding="utf-8")
    findings = _findings([planted], tmp_path)
    assert findings, f"the scanner missed {why}: {content!r}"


@pytest.mark.parametrize(
    "content",
    [
        'password = ""',
        'password = "x"',
        "LK_PASSWORD=",
        'LK_PASSWORD="$SOME_VAR"',
        'password = "unused-in-test"',
        "schema_name = 'exp'",
        "# Set LK_PASSWORD in your environment",
        'headers = {"apikey": self.api_key}',
    ],
)
def test_the_scanner_does_not_fire_on_safe_content(tmp_path, content):
    """A gate that cries wolf gets disabled, so the false-positive behaviour
    matters as much as the detection."""
    planted = tmp_path / "safe.py"
    planted.write_text(content + "\n", encoding="utf-8")
    assert not _findings([planted], tmp_path), f"false positive on {content!r}"


def test_the_allowlist_is_documented_and_small(tracked_files, repo_root):
    """The allowlist is the escape hatch. If it grows large it stops being a
    review gate and becomes a rubber stamp."""
    assert len(ALLOWED_LITERALS) < 40, (
        "the secret-scanner allowlist has grown large enough to hide a real "
        "secret; review its entries")
