# LabKey build and installer scripts

Seven Bash scripts that build [LabKey Server Community
Edition](https://www.labkey.org/) from source on a single host and populate it
with study content, plus the Snyk scanner used to sweep the group's GitHub and
GitLab repositories.

They are written for Photon OS but work on any Linux with `bash`, `curl`,
`git`, `unzip` and a JDK. Each one is **idempotent**: re-running it is safe, and
creating something that already exists counts as success rather than an error.

---

## The scripts

| Script | What it does |
| --- | --- |
| [`build-labkey-community.sh`](build-labkey-community.sh) | Builds LabKey CE from the source enlistment: fetches the branch, sets up PostgreSQL, generates a TLS keystore, configures the site and starts the server. |
| [`install-labkey-recommended-modules.sh`](install-labkey-recommended-modules.sh) | Adds the recommended optional modules to an existing enlistment so the next build includes them. |
| [`install-labkey-sample-data.sh`](install-labkey-sample-data.sh) | Downloads LabKey's official demo archives and imports the HIV observational demo study into `Tutorials / HIV Study`. |
| [`install-labkey-uci-datasets.sh`](install-labkey-uci-datasets.sh) | Downloads UCI Machine Learning Repository datasets, converts them to CSV with generated schemas, and imports each as a LabKey list. |
| [`install-labkey-v940-evidence.sh`](install-labkey-v940-evidence.sh) | Builds an evidence shelf for the V940 study: source tables as lists, with the supporting documents in the file repository. |
| [`install-labkey-sleepdrive-lab.sh`](install-labkey-sleepdrive-lab.sh) | Builds a student lab from the sleep-drive *Nature* paper — Fig. 1–5 source data as lists, step-by-step wiki pages, and a 30-question quiz drawn from a pool of 100. |
| [`snyk_scan_github_repos.sh`](snyk_scan_github_repos.sh) | Discovers UniBasel core-facility repositories on GitHub and GitLab, clones them and runs `snyk code test` over each. |

---

## Recipe: a full installation from scratch

Run from your home directory. Set the three values first — the scripts read
credentials from the command line or the environment, never from a file in this
repository.

```bash
cd "$HOME"

username="admin@example.org"
password="…"
url="https://127.0.0.1:8443"

chmod a+x ./*.sh
mkdir -p ./scicore/githubrepositories

# 1. Optional: security sweep of the group's repositories (needs SNYK_TOKEN)
./snyk_scan_github_repos.sh ./unibas_scicore_github_repos.csv ./scicore/githubrepositories/

# 2. Build LabKey CE from source and start it
./build-labkey-community.sh --branch release26.7 --dir "$HOME/scicore"

# 3. Add the recommended modules (rebuild afterwards to pick them up)
./install-labkey-recommended-modules.sh --dir "$HOME/scicore" --branch release26.7

# 4. Official demo study
./install-labkey-sample-data.sh --dir "$HOME/scicore/sample-data" \
    --import --force --url "$url" --project Tutorials \
    --user "$username" --password "$password" --insecure

# 5. Datasets and study content
./install-labkey-uci-datasets.sh   --import --force --url "$url" \
    --user "$username" --password "$password" --insecure

./install-labkey-v940-evidence.sh  --import --force --url "$url" \
    --user "$username" --password "$password" --insecure

./install-labkey-sleepdrive-lab.sh --import --force --url "$url" \
    --user "$username" --password "$password" --insecure
```

### Three things to check before you paste that

- **Use the HTTPS port.** `build-labkey-community.sh` serves HTTPS on **8443**
  and plain HTTP on 8080. `https://127.0.0.1:8080` will not connect — pick
  `https://127.0.0.1:8443` (as above) or `http://127.0.0.1:8080`.
- **Variables are shell variables**, so `username=…` with no `$` on assignment
  and `"$username"` when used. A leading `$` on the left-hand side is
  PowerShell, not Bash.
- **The seed CSV is not in this repository.** Step 1 names
  `unibas_scicore_github_repos.csv`; supply your own, or drop the argument and
  let the script discover repositories from the GitHub and GitLab APIs.

---

## The six common flags

`install-labkey-sample-data.sh`, `install-labkey-uci-datasets.sh`,
`install-labkey-v940-evidence.sh` and `install-labkey-sleepdrive-lab.sh` all
accept the same six options, so the four steps above are interchangeable in
shape:

| Flag | Meaning |
| --- | --- |
| `--import` | Push the prepared content into a running server. Without it the script only downloads and prepares files locally. |
| `--force` | Rebuild rather than reuse: re-download archives, re-extract, and rebuild lists instead of skipping ones that already exist. |
| `--url URL` | Server base URL. Default `https://127.0.0.1:8443`. |
| `--user NAME` | Site-admin user, or `$LK_USER`. |
| `--password PW` | Password, or `$LK_PASSWORD`. Several scripts also take `--apikey`. |
| `--insecure` | Skip TLS verification. Implied for loopback HTTPS, because the build generates a self-signed certificate. |

**`--force` matters more than it looks.** Without it these scripts skip work
that is already done, which is what you want on a re-run. With it they *rebuild*
— and rebuilding is what keeps a list at its true row count. An importer that
appends instead of replacing turns a 7-row table into 91 rows after thirteen
runs, and that has happened here.

Every script also has `--help`.

---

## Per-script detail

### `build-labkey-community.sh`

Builds and runs the server. Key options: `--dir DIR` (enlistment, default
`$HOME/src/labkeyEnlistment`), `--branch NAME` (e.g. `release26.7`),
`--pg-user` / `--pg-password`, `--https-port` (8443), `--http-port` (8080).

Everything else is an environment variable with a default: `LK_PG_DATABASE`,
`LK_PGDATA`, `LK_SITE_SHORT_NAME`, `LK_SITE_ORG`, `LK_SITE_EMAIL`,
`LK_SITE_THEME` and more — see the header of the script.

> **Change the database password before this repository is shared.**
> `LK_PG_PASSWORD` falls back to a hard-coded default when the variable is
> unset, so the value is visible in the file. Set `LK_PG_PASSWORD` in the
> environment, or pass `--pg-password`, and change the role's password on any
> host that was built with the default.

### `install-labkey-recommended-modules.sh`

Adds optional modules to the enlistment at `--dir` on `--branch`. It changes
the source tree only; run `build-labkey-community.sh` again for the modules to
appear in a running server.

### `install-labkey-sample-data.sh`

Fetches LabKey's official demo archives into `--dir` and, with `--import`,
imports `ImportableDemoStudy.folder.zip` into `--project` / `--folder`
(defaults `Tutorials` / `HIV Study`).

Extra options: `--with-proteomics` (adds a ~67 MiB MS2 archive),
`--no-examples` (skip the `LabKey/examples` clone), `--no-extract` (keep the
zips packed), `--apikey`, `--context`.

The data is fictional. Do not treat it as PHI.

### `install-labkey-uci-datasets.sh`

Downloads UCI datasets, converts each to CSV with an inferred schema, and
imports them as lists under `UCI-Labs / UCI Datasets`. Bounded by
`--limit N`, `LK_MAX_BYTES` (50 MiB per download) and `LK_MAX_ROWS` (50,000).

### `install-labkey-v940-evidence.sh`

Builds the `V940-Evidence / Evidence Shelf` folder: source tables as lists plus
the supporting documents in the file repository, with the same size and row
caps.

### `install-labkey-sleepdrive-lab.sh`

Builds `SleepDrive-Lab / Source Data Lab` from the *Nature* sleep-drive paper:

- Fig. 1–5 Source Data converted to ~80 lists, one per sheet or block, in
  per-figure subfolders and mirrored on the landing folder.
- Figure images in the file repository, embedded in step-by-step wiki pages.
- A **quiz**: 8 papers of 30 questions drawn from a pool of 100, built as
  LabKey Survey designs — one question per card, real radio buttons for
  single-answer questions and tick boxes where several parts form the answer,
  with a *Cancel the Quiz* button on every card. Which paper a student gets
  rotates with the number of attempts they have already made, so a repeat is a
  different paper with the answers in a different order. Scoring, attempt
  history and a per-question review are LabKey SQL queries; no JavaScript is
  written by the script.

Tunable with `LK_QUIZ_PAPERS` (8) and `LK_QUIZ_QUESTIONS` (30). An instructor
can replace the question pool by putting a `quiz_bank.json` next to the script.

It also installs a small block of CSS into the project's custom stylesheet, to
hide the survey wizard's step list — LabKey offers no setting for that.

### `snyk_scan_github_repos.sh`

Discovers repositories across ten GitHub organisations and a GitLab group,
clones them into the work directory and runs `snyk code test` over each.

```bash
./snyk_scan_github_repos.sh [csv_path] [work_dir]
./snyk_scan_github_repos.sh --discover-only [csv_path]    # write the CSV, no clone or scan
```

Defaults: `./unibas_core_facility_repos.csv` and `./cloned_repos`. Needs
`SNYK_TOKEN`; `GITHUB_TOKEN` and `GITLAB_TOKEN` are optional and raise the API
rate limit. All three are read from the environment.

---

## Requirements

- `bash`, `curl`, `git`, `unzip`, `python3`, `sha256sum`
- A JDK and PostgreSQL for `build-labkey-community.sh` (it can install and
  initialise PostgreSQL itself)
- `snyk` on `PATH` for the scanner

## Conventions

- Credentials come from the command line or the environment. **No token, key or
  password belongs in this repository.**
- Progress goes to stderr; several helpers return an HTTP status code on stdout,
  so mixing the two would corrupt the parsing.
- `--insecure` is implied for loopback HTTPS, because the build generates a
  self-signed certificate. Do not use it against a remote host.
