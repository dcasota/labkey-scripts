# ADR-0008: Credentials Come Exclusively From The Environment

**Date**: 2026-08-26
**Status**: Accepted

## Context

The project must talk to a LabKey server, and will later talk to HuggingFace and
GitHub. The brief is absolute: no secrets in the repository, ever, and the
LabKey password in particular must not be committed.

The user's existing scripts already establish a convention worth preserving:
`LK_URL`, `LK_USER`, `LK_PASSWORD`, `LK_APIKEY`, `LK_CONTEXT`, `LK_INSECURE`,
each with a matching command-line flag, no prompting, and an explicit validation
gate before any authenticated work begins.

Those scripts also show the failure mode to avoid. `build-labkey-community.sh`
defaults `LK_PG_PASSWORD` to `sasa` and `LK_KEYSTORE_PASS` to `changeit`, and
writes them in plaintext into `server/configs/pg.properties`. A default that is
a real credential is worse than no default: it works, so nobody notices.

## Decision Drivers

- No credential may enter git history, where removal is expensive and
  incomplete.
- A missing credential must fail loudly, not fall back to a guess.
- The convention must match the user's existing scripts so one exported
  environment drives everything.
- HuggingFace and GitHub tokens are not yet available and must not be blocked
  on, nor faked with placeholders that look real.

## Considered Options

### Option 1: Configuration file, git-ignored

**Description**: A `config.local.yaml` holding credentials, listed in
`.gitignore`.

**Pros**:
- Convenient; set once, persists across shells.
- Structured, so complex configuration is expressible.

**Cons**:
- One `git add -f`, one `.gitignore` edit, or one `git add -A` from a different
  working directory and the secret is committed. The protection is a single
  line in a file anyone can change.
- A file on disk is readable by any process running as that user, and survives
  reboots.
- Diverges from the user's existing scripts.

### Option 2: Environment variables only

**Description**: Every credential is read from the environment. No defaults, no
files, no prompts. A missing required variable aborts with a message naming it.

**Pros**:
- Nothing to accidentally commit; there is no file.
- Matches the existing scripts exactly, so `LK_*` drives both.
- Composes with every secret manager, CI system and `direnv` setup.
- The failure mode is loud and immediate.

**Cons**:
- Values are visible in `/proc/<pid>/environ` to the same user, and command-line
  forms leak into the process table.
- Must be re-exported per shell.

### Option 3: A secret manager (Vault, `pass`, the OS keyring)

**Description**: Credentials are fetched at runtime from a dedicated store.

**Pros**:
- Strongest control: rotation, access audit, expiry.
- Nothing in the environment or on disk in plaintext.

**Cons**:
- Infrastructure this deployment does not have and one person would have to
  operate.
- Adds a hard dependency to every script, including ones that must run during
  bootstrap when the manager may not be reachable.
- Disproportionate to a single-server research deployment.

## Decision Outcome

**Chosen Option**: Option 2 — environment variables only, with no credential
defaults.

**Rationale**:

- It is the only option where committing a secret requires deliberately writing
  one into a file, rather than merely forgetting a `.gitignore` entry.
- It matches the conventions already proven in the user's scripts, so there is
  one mental model rather than two.
- Option 3 is the right answer for a production multi-user deployment and is not
  foreclosed: reading from the environment is exactly the interface a secret
  manager injects into.

The process-table objection is handled in implementation: credentials are passed
to subprocesses through the environment, never as command-line arguments.

## Consequences

### Positive

- The repository contains no credential and no plausible-looking placeholder.
  `memory.md` documents the variable *names* only.
- A missing credential produces a message naming the variable, not a
  confusing 401 later.
- CI and secret managers work without modification.

### Negative

- Contributors must export variables per shell. `.env.example` documents the
  names with empty values, and `.env` is git-ignored.
- Environment variables are visible to other processes of the same user. On a
  single-user research server this is accepted; it is recorded here so the
  acceptance is deliberate rather than accidental.

### Neutral

- `HUGGINGFACE_API_KEY`, `HUGGINGFACE_MODEL_ID` and `GITHUB_TOKEN` are reserved
  names, documented in `memory.md`, unset, and with no fallback value. Code
  paths that need them fail with a clear message until they are supplied.

## Implementation Notes

- `LK_APIKEY` takes precedence over `LK_USER`/`LK_PASSWORD`, matching the
  existing scripts. An API key is preferred because it can be role-restricted
  and revoked independently.
- The LabKey client applies the existing scripts' TLS rule: verification is
  skipped for loopback HTTPS because the deployment uses a self-signed
  certificate, and only for loopback. A non-loopback host requires either a
  valid certificate or an explicit `LK_INSECURE=1`.
- No credential is ever logged, including at debug level. Log lines carry the
  URL and the status code, never the `Authorization` header.
- The repository is deliberately created with **no git remote**. One is added
  when `GITHUB_TOKEN` is supplied, so an accidental push cannot happen first.

## References

- `/root/build-labkey-community.sh`, `/root/install-labkey-uci-datasets.sh`
- `memory.md` (environment variable table)
- Memory: `FR-013`
