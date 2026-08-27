#!/usr/bin/env bash
# install-labkey-uci-datasets.sh
#
# Walk every dataset published at https://archive.ics.uci.edu/datasets,
# download the tabular file when UCI exposes one, extract archives, clean
# the columns, decide List vs Study, and optionally import into LabKey
# Community Edition as Lists (the recommended target for UCI tables).
#
# There is no official UCI→LabKey connector. This script is that loop:
#   catalog  →  download  →  extract  →  prepare CSV  →  analyse  →  import
#
# Catalog source:  https://archive.ics.uci.edu/api/datasets/list   (~689 rows)
# Per-dataset:     https://archive.ics.uci.edu/api/dataset?id=N
# File payload:    data_url, usually https://archive.ics.uci.edu/static/public/{id}/data.csv
# Fallback zip:    https://archive.ics.uci.edu/static/public/{id}/{slug}.zip
#
# Import target: LabKey Lists (schema lists), AutoIncrementInteger key.
# Study Datasets are only recommended when a participant-like column AND a
# timepoint-like column are both present; the default is still a List.
#
# Usage:
#   ./install-labkey-uci-datasets.sh
#   ./install-labkey-uci-datasets.sh --limit 5
#   ./install-labkey-uci-datasets.sh --ids 53,2,45 --import \
#       --url https://127.0.0.1:8443 --user admin --password secret
#   ./install-labkey-uci-datasets.sh --search iris --dry-run
#
set -euo pipefail

DATA_DIR="${LK_UCI_DIR:-$HOME/src/labkeyUciData}"
LK_IMPORT=0
LK_DRY_RUN=0
LK_INSECURE="${LK_INSECURE:-0}"
LK_URL="${LK_URL:-https://127.0.0.1:8443}"
LK_USER="${LK_USER:-}"
LK_PASSWORD="${LK_PASSWORD:-}"
LK_APIKEY="${LK_APIKEY:-}"
LK_CONTEXT="${LK_CONTEXT:-auto}"
LK_PROJECT="${LK_PROJECT:-UCI-Labs}"
LK_FOLDER="${LK_FOLDER:-UCI Datasets}"
LK_LIMIT="${LK_LIMIT:-0}"          # 0 = no limit
LK_IDS="${LK_IDS:-}"               # comma-separated UCI ids
LK_SEARCH="${LK_SEARCH:-}"
LK_MAX_BYTES="${LK_MAX_BYTES:-52428800}"   # 50 MiB download cap
LK_MAX_ROWS="${LK_MAX_ROWS:-50000}"        # 0 = no row cap on prepared CSV
LK_SKIP_EXISTING=1
LK_FORCE=0
LK_LANDING_ONLY=0
LK_FLAT=0
UCI_LIST_URL="https://archive.ics.uci.edu/api/datasets/list"
UCI_ITEM_URL="https://archive.ics.uci.edu/api/dataset"

usage() {
  cat <<'EOF'
Download and prepare every tabular UCI ML Repository dataset, then
optionally import each one as a LabKey List.

Options:
  --dir DIR            Work directory (default: $HOME/src/labkeyUciData)
  --ids ID[,ID...]     Only these UCI numeric ids (e.g. 53,2,45)
  --search TEXT        Case-insensitive substring filter on dataset name
  --limit N            Stop after N datasets that actually get processed
  --max-bytes N        Skip downloads larger than N bytes (default 52428800)
  --max-rows N         Truncate prepared CSV after N data rows (default 50000,
                       0 = keep all)
  --force              Re-download / re-prepare even if the folder exists
  --no-skip            Same as --force
  --import             After prepare, create/populate LabKey Lists
  --landing-only       Only rebuild portals (catalog + existing dataset folders)
  --flat               Import all lists into /UCI Datasets (old behaviour)
  --url URL            LabKey base URL (default: https://127.0.0.1:8443)
  --user NAME          Site-admin / folder-admin user
  --password PW        Password
  --apikey KEY         API key instead of password
  --context PATH       App context: auto (default), empty, or labkey
  --project NAME       Destination project (default: UCI-Labs)
  --folder NAME        Destination folder (default: UCI Datasets)
  --insecure           Skip TLS verify (implied for localhost HTTPS)
  --dry-run            Catalog + decide, do not download or import
  -h, --help           Show this help

Layout after a run:
  $DIR/catalog.jsonl
  $DIR/MANIFEST.tsv
  $DIR/FAILED.tsv
  $DIR/datasets/{id}_{slug}/
      metadata.json
      raw/                 original download
      prepared/data.csv    header-cleaned, ready for LabKey
      prepared/preview.csv first 10 rows
      ANALYSIS.md          List vs Study recommendation

UCI tables import as Lists, not Study Datasets, unless both a subject-like
and a time-like column are present. Mixed-type columns and dirty headers
are the usual import failures — this script sanitizes names first.

Data is third-party research data. Review licenses/DOIs before sharing.
EOF
}

log() { printf '[uci-labkey] %s\n' "$*" >&2; }
die() { printf '[uci-labkey] ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)          DATA_DIR="$2"; shift 2 ;;
    --ids)          LK_IDS="$2"; shift 2 ;;
    --search)       LK_SEARCH="$2"; shift 2 ;;
    --limit)        LK_LIMIT="$2"; shift 2 ;;
    --max-bytes)    LK_MAX_BYTES="$2"; shift 2 ;;
    --max-rows)     LK_MAX_ROWS="$2"; shift 2 ;;
    --force|--no-skip) LK_FORCE=1; LK_SKIP_EXISTING=0; shift ;;
    --import)       LK_IMPORT=1; shift ;;
    --landing-only) LK_LANDING_ONLY=1; LK_IMPORT=1; shift ;;
    --flat)         LK_FLAT=1; shift ;;
    --url)          LK_URL="$2"; shift 2 ;;
    --user)         LK_USER="$2"; shift 2 ;;
    --password)     LK_PASSWORD="$2"; shift 2 ;;
    --apikey)       LK_APIKEY="$2"; shift 2 ;;
    --context)      LK_CONTEXT="$2"; shift 2 ;;
    --project)      LK_PROJECT="$2"; shift 2 ;;
    --folder)       LK_FOLDER="$2"; shift 2 ;;
    --insecure)     LK_INSECURE=1; shift ;;
    --dry-run)      LK_DRY_RUN=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "Unknown option: $1" ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
need curl
need python3
need mkdir
need unzip

case "${LK_URL}" in
  https://127.0.0.1*|https://localhost*|https://[::1]*)
    LK_INSECURE=1
    ;;
esac

curl_flags=(-fsSL --retry 3 --retry-delay 2)
api_flags=(-sS --retry 2 --retry-delay 1 -A "Mozilla/5.0 LabKey-UCI-Importer")
if [[ "$LK_INSECURE" -eq 1 ]]; then
  curl_flags+=(-k)
  api_flags+=(-k)
fi

mkdir -p "$DATA_DIR/datasets"
CATALOG="$DATA_DIR/catalog.jsonl"
MANIFEST="$DATA_DIR/MANIFEST.tsv"
FAILED="$DATA_DIR/FAILED.tsv"
HELPER="$DATA_DIR/.uci_prepare.py"

# ---------------------------------------------------------------------------
# Embedded Python: JSON, CSV cleaning, type inference, LabKey payload
# ---------------------------------------------------------------------------
cat > "$HELPER" <<'PY'
#!/usr/bin/env python3
"""Helpers for install-labkey-uci-datasets.sh. Invoked as subcommands."""
from __future__ import annotations

import csv
import json
import os
import re
import sys
from collections import Counter
from typing import Any

SUBJECT_RE = re.compile(
    r"(participant|subject|patient|person|individual|donor|sample_id|subjectid|ptid)",
    re.I,
)
TIME_RE = re.compile(
    r"(visit|timepoint|time_point|study_day|studyday|collection_date|draw_date|^date$|^time$|^day$|datetime)",
    re.I,
)


def scrub(s: str) -> str:
    """Postgres rejects NUL (0x00) and other C0 controls in text columns."""
    if s is None:
        return ""
    s = str(s).replace("\x00", "")
    return re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", s)


def slugify(name: str) -> str:
    s = name.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s or "dataset"


def clean_col(name: str, used: set[str]) -> str:
    raw = scrub(name or "").strip()
    s = re.sub(r"[^A-Za-z0-9_]+", "_", raw)
    s = re.sub(r"_+", "_", s).strip("_")
    if not s:
        s = "col"
    if s[0].isdigit():
        s = "c_" + s
    if s.lower() in {"key", "entityid", "container", "created", "createdby",
                     "modified", "modifiedby", "lsid"}:
        s = "uci_" + s
    # LabKey field name/label limit is 200 characters.
    s = s[:80]
    base = s
    n = 2
    while s.lower() in used:
        suffix = f"_{n}"
        s = (base[: 80 - len(suffix)] + suffix)
        n += 1
    used.add(s.lower())
    return s


def sniff_dialect(sample: str) -> csv.Dialect:
    try:
        return csv.Sniffer().sniff(sample, delimiters=",;\t| ")
    except csv.Error:
        class D(csv.Dialect):
            delimiter = ","
            quotechar = '"'
            doublequote = True
            skipinitialspace = True
            lineterminator = "\n"
            quoting = csv.QUOTE_MINIMAL
        return D()


def looks_header(row: list[str]) -> bool:
    if not row:
        return False
    non_num = 0
    for cell in row:
        cell = (cell or "").strip()
        if not cell:
            continue
        try:
            float(cell)
        except ValueError:
            non_num += 1
    return non_num >= max(1, len([c for c in row if (c or "").strip()]) // 2)


MISSING = {"?", "na", "n/a", "nan", "null", "none", ".", "-", "naN", "NaN", "N/A"}


def is_missing(v: str) -> bool:
    return v.strip() == "" or v.strip().lower() in {m.lower() for m in MISSING}


def infer_type(values: list[str]) -> str:
    nonempty = [v.strip() for v in values if v is not None and not is_missing(str(v))]
    if not nonempty:
        return "string"
    boolish = {"true", "false", "yes", "no", "t", "f", "y", "n"}
    if all(v.lower() in boolish for v in nonempty):
        return "boolean"
    ints = 0
    floats = 0
    max_abs = 0
    for v in nonempty:
        if re.fullmatch(r"[+-]?\d+", v):
            ints += 1
            try:
                max_abs = max(max_abs, abs(int(v)))
            except ValueError:
                return "string"
        elif re.fullmatch(r"[+-]?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?", v):
            floats += 1
        else:
            return "string"
    if floats:
        return "double"
    # LabKey Integer is signed 32-bit. Bigger IDs stay strings.
    if max_abs > 2147483647:
        return "string"
    return "int"


def range_uri(kind: str) -> str:
    return {
        "int": "http://www.w3.org/2001/XMLSchema#int",
        "double": "http://www.w3.org/2001/XMLSchema#double",
        "boolean": "http://www.w3.org/2001/XMLSchema#boolean",
        "string": "http://www.w3.org/2001/XMLSchema#string",
    }[kind]


def cmd_filter_catalog() -> None:
    ids = {x.strip() for x in os.environ.get("LK_IDS", "").split(",") if x.strip()}
    search = os.environ.get("LK_SEARCH", "").strip().lower()
    data = json.load(sys.stdin)
    rows = data.get("data", data)
    out = []
    for row in rows:
        if ids and str(row.get("id")) not in ids:
            continue
        if search and search not in str(row.get("name", "")).lower():
            continue
        out.append({"id": row.get("id"), "name": row.get("name")})
    json.dump(out, sys.stdout)


def cmd_dump_meta() -> None:
    raw = json.load(sys.stdin)
    data = raw.get("data", raw)
    name = data.get("name") or "dataset"
    rec = {
        "uci_id": data.get("uci_id") or data.get("id"),
        "name": scrub(name),
        "slug": slugify(name),
        "repository_url": data.get("repository_url"),
        "data_url": data.get("data_url"),
        "abstract": scrub(data.get("abstract") or ""),
        "area": data.get("area"),
        "tasks": data.get("tasks") or [],
        "characteristics": data.get("characteristics") or [],
        "num_instances": data.get("num_instances"),
        "num_features": data.get("num_features"),
        "feature_types": data.get("feature_types") or [],
        "target_col": data.get("target_col") or [],
        "has_missing_values": data.get("has_missing_values"),
        "year_of_dataset_creation": data.get("year_of_dataset_creation"),
        "dataset_doi": data.get("dataset_doi"),
        "variables": data.get("variables") or [],
        "zip_url": None,
    }
    slug_plus = re.sub(r"[^a-z0-9]+", "+", name.lower()).strip("+")
    rec["zip_url"] = f"https://archive.ics.uci.edu/static/public/{rec['uci_id']}/{slug_plus}.zip"
    json.dump(rec, sys.stdout, indent=2)


def _read_table(path: str) -> tuple[list[str], list[list[str]], str]:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        sample = fh.read(65536)
        fh.seek(0)
        dialect = sniff_dialect(sample)
        # Skip ARFF / comment preambles
        lines = []
        in_data = False
        is_arff = "@relation" in sample.lower() or "@data" in sample.lower()
        raw_rows = []
        for line in fh:
            if is_arff:
                low = line.strip().lower()
                if low.startswith("%") or not line.strip():
                    continue
                if low.startswith("@data"):
                    in_data = True
                    continue
                if low.startswith("@attribute"):
                    # @attribute name type
                    parts = line.strip().split(None, 2)
                    if len(parts) >= 2:
                        lines.append(parts[1].strip("'\""))
                    continue
                if not in_data and low.startswith("@"):
                    continue
            raw_rows.append(next(csv.reader([line], dialect=dialect)))
    if is_arff and lines:
        header = [clean_col(c, set()) for c in lines]  # cleaned later again
        # restore original names for second clean pass
        header = lines
        rows = [r for r in raw_rows if any(c.strip() for c in r)]
        return header, rows, dialect.delimiter
    if not raw_rows:
        return [], [], ","
    first = raw_rows[0]
    if looks_header(first):
        return first, raw_rows[1:], dialect.delimiter
    header = [f"col_{i+1}" for i in range(len(first))]
    return header, raw_rows, dialect.delimiter


def cmd_prepare() -> None:
    src = sys.argv[2]
    dest_dir = sys.argv[3]
    max_rows = int(sys.argv[4])
    os.makedirs(dest_dir, exist_ok=True)
    header, rows, delim = _read_table(src)
    if not header:
        print(json.dumps({"ok": False, "reason": "empty or unreadable table"}))
        return
    used: set[str] = set()
    clean = [clean_col(h, used) for h in header]
    width = len(clean)
    if width > 400:
        print(json.dumps({"ok": False, "reason": f"too many columns ({width})"}))
        return
    sample_cols: list[list[str]] = [[] for _ in range(width)]
    max_len = [0] * width
    kept = 0
    out_csv = os.path.join(dest_dir, "data.csv")
    preview = os.path.join(dest_dir, "preview.csv")
    with open(out_csv, "w", encoding="utf-8", newline="") as fo:
        w = csv.writer(fo)
        w.writerow(clean)
        for row in rows:
            if max_rows and kept >= max_rows:
                break
            if len(row) < width:
                row = row + [""] * (width - len(row))
            elif len(row) > width:
                row = row[:width]
            cleaned_row = []
            for i, cell in enumerate(row):
                val = "" if is_missing(str(cell)) else scrub(str(cell))
                cleaned_row.append(val)
                max_len[i] = max(max_len[i], len(val))
                if kept < 250:
                    sample_cols[i].append(val)
            w.writerow(cleaned_row)
            kept += 1
    with open(out_csv, "r", encoding="utf-8") as fi, open(preview, "w", encoding="utf-8") as po:
        for i, line in enumerate(fi):
            po.write(line)
            if i >= 10:
                break
    types = [infer_type(sample_cols[i]) for i in range(width)]
    subject_cols = [c for c in clean if SUBJECT_RE.search(c)]
    time_cols = [c for c in clean if TIME_RE.search(c)]
    recommend = "list"
    if subject_cols and time_cols:
        recommend = "study_dataset"
    unique_counts = []
    for i in range(width):
        vals = [v for v in sample_cols[i] if v != ""]
        unique_counts.append(len(set(vals)))
    TARGET_RE = re.compile(
        r"^(class|target|label|species|diagnosis|outcome|rings|quality|y|response)$",
        re.I,
    )
    ID_RE = re.compile(r"(^id$|_id$|index|rowid|unnamed|name$|identifier)", re.I)
    fields = []
    for i, (name, kind, original, slen) in enumerate(zip(clean, types, header, max_len)):
        scale = 4000
        if kind == "string":
            scale = min(40000, max(4000, slen + 64))
        nuniq = unique_counts[i]
        role = "feature"
        if ID_RE.search(name) and (kind == "string" or nuniq >= max(20, int(0.8 * max(1, min(kept, 250))))):
            role = "id"
        elif TARGET_RE.search(name):
            role = "target"
        elif i == width - 1 and kind in ("string", "boolean"):
            role = "target"
        elif i == width - 1 and kind in ("int", "long") and 2 <= nuniq <= 20:
            role = "target"
        fields.append({
            "name": name,
            "label": scrub(original or name)[:200],
            "rangeURI": range_uri(kind),
            "inferred": kind,
            "scale": scale,
            "unique_count": nuniq,
            "role": role,
        })
    analysis = {
        "ok": True,
        "source": src,
        "rows_written": kept,
        "n_columns": width,
        "delimiter": delim,
        "recommend": recommend,
        "subject_cols": subject_cols,
        "time_cols": time_cols,
        "fields": fields,
        "task": (
            "classification"
            if any(
                f.get("role") == "target" and f.get("inferred") in ("string", "boolean")
                or (f.get("role") == "target" and int(f.get("unique_count") or 0) <= 20)
                for f in fields
            )
            else (
                "regression"
                if any(f.get("role") == "target" and f.get("inferred") in ("int", "double", "long") for f in fields)
                else "exploratory"
            )
        ),
        "list_kind": "IntList",
        "key_name": "Key",
        "key_type": "AutoIncrementInteger",
    }
    with open(os.path.join(dest_dir, "schema.json"), "w", encoding="utf-8") as fh:
        json.dump(analysis, fh, indent=2)
    md = os.path.join(os.path.dirname(dest_dir), "ANALYSIS.md")
    with open(md, "w", encoding="utf-8") as fh:
        fh.write("# Import analysis\n\n")
        fh.write(f"- Source: `{src}`\n")
        fh.write(f"- Prepared rows: {kept}\n")
        fh.write(f"- Columns: {width}\n")
        fh.write(f"- Recommendation: **{recommend}**\n")
        fh.write(f"- Task guess: **{analysis.get('task')}**\n")
        if recommend == "study_dataset":
            fh.write(
                f"- Subject-like columns: {', '.join(subject_cols)}\n"
                f"- Time-like columns: {', '.join(time_cols)}\n"
                "- Still imported as a List unless you remodel this folder as a Study.\n"
            )
        else:
            fh.write("- No participant+timepoint pair detected. LabKey List is the right target.\n")
        fh.write("\n## Fields\n\n| Original | Clean name | Type |\n|---|---|---|\n")
        for f, orig in zip(fields, header):
            fh.write(f"| {orig} | {f['name']} | {f['inferred']} |\n")
    print(json.dumps({"ok": True, "rows": kept, "cols": width, "recommend": recommend,
                      "csv": out_csv}))


def _lk_type(kind: str) -> str:
    return {"int": "INTEGER", "long": "INTEGER", "double": "DOUBLE", "boolean": "BOOLEAN"}.get(kind, "VARCHAR")


def cmd_chart_plan() -> None:
    """Pick at most 3 HIV-study-style defaults from column roles.

    UCI tables fall into three buckets:
      classification — discrete target (Iris, Wine, Arrhythmia)
      regression     — numeric target with many values (Abalone rings)
      exploratory    — no clear target (clustering / mixed)

    Never chart ID-like columns or high-cardinality categories.
    """
    schema = json.load(open(sys.argv[2], encoding="utf-8"))
    fields = schema.get("fields") or []
    by_name = {f["name"]: f for f in fields}

    def nuniq(f: dict) -> int:
        try:
            return int(f.get("unique_count") or 0)
        except (TypeError, ValueError):
            return 0

    def is_num(f: dict) -> bool:
        return f.get("inferred") in ("int", "double", "long")

    def is_cat(f: dict) -> bool:
        if f.get("role") == "id":
            return False
        if f.get("inferred") in ("string", "boolean"):
            return 2 <= nuniq(f) <= 15 or nuniq(f) == 0
        if is_num(f) and 2 <= nuniq(f) <= 12:
            return True
        return False

    features_num = [f for f in fields if is_num(f) and f.get("role") != "id"]
    low_cats = [f for f in fields if is_cat(f) and f.get("role") != "id"]
    targets = [f for f in fields if f.get("role") == "target"]
    target = targets[0] if targets else None
    task = schema.get("task") or "exploratory"
    if target and is_num(target) and nuniq(target) > 20:
        task = "regression"
    elif target and (not is_num(target) or nuniq(target) <= 20):
        task = "classification"

    def spec(f):
        if not f:
            return None
        return {
            "name": f["name"],
            "label": str(f.get("label") or f["name"])[:80],
            "type": _lk_type(str(f.get("inferred") or "string")),
        }

    def scatter(x, y, color, title):
        return {
            "name": title,
            "renderType": "scatter_plot",
            "x": spec(x),
            "y": spec(y),
            "color": spec(color) if color and color.get("name") not in (x["name"], y["name"]) else None,
        }

    def box(x, y, title):
        return {"name": title, "renderType": "box_plot", "x": spec(x), "y": spec(y), "color": None}

    def bar(x, title):
        return {"name": title, "renderType": "bar_chart", "x": spec(x), "y": None, "color": None}

    plans = []
    grp = None
    if target and is_cat(target):
        grp = target
    elif low_cats:
        grp = low_cats[0]

    feat_nums = [f for f in features_num if not target or f["name"] != target["name"]]

    if task == "classification" and target:
        if grp and (is_cat(grp) or nuniq(grp) <= 15):
            plans.append(bar(grp, f"Class balance ({grp['name']})"))
        if feat_nums and grp:
            plans.append(box(grp, feat_nums[0], f"{feat_nums[0]['name']} by {grp['name']}"))
        if len(feat_nums) >= 2:
            plans.append(scatter(feat_nums[0], feat_nums[1], grp, f"{feat_nums[0]['name']} vs {feat_nums[1]['name']}"))
        elif feat_nums and not grp:
            plans.append(box(None, feat_nums[0], f"Distribution of {feat_nums[0]['name']}"))
    elif task == "regression" and target:
        if feat_nums:
            plans.append(scatter(feat_nums[0], target, grp, f"{feat_nums[0]['name']} vs {target['name']}"))
        if len(feat_nums) >= 2:
            plans.append(scatter(feat_nums[0], feat_nums[1], grp, f"{feat_nums[0]['name']} vs {feat_nums[1]['name']}"))
        if grp:
            plans.append(box(grp, target, f"{target['name']} by {grp['name']}"))
        elif not feat_nums:
            plans.append(box(None, target, f"Distribution of {target['name']}"))
    else:
        if len(feat_nums) >= 2:
            plans.append(scatter(feat_nums[0], feat_nums[1], grp, f"{feat_nums[0]['name']} vs {feat_nums[1]['name']}"))
        if feat_nums and grp:
            plans.append(box(grp, feat_nums[0], f"{feat_nums[0]['name']} by {grp['name']}"))
        if grp:
            plans.append(bar(grp, f"Count by {grp['name']}"))
        if not plans and feat_nums:
            plans.append(box(None, feat_nums[0], f"Distribution of {feat_nums[0]['name']}"))

    # de-dup by (type, x, y)
    seen = set()
    out = []
    for p in plans:
        key = (p["renderType"], (p.get("x") or {}).get("name"), (p.get("y") or {}).get("name"))
        if key in seen:
            continue
        seen.add(key)
        out.append(p)
    json.dump(out[:3], sys.stdout)


def cmd_dataset_wiki() -> None:
    import html as h
    work = sys.argv[2]
    title = sys.argv[3]
    uci_id = sys.argv[4]
    listname = sys.argv[5]
    schema = {}
    meta = {}
    sch = os.path.join(work, "prepared", "schema.json")
    met = os.path.join(work, "metadata.json")
    if os.path.isfile(sch):
        schema = json.load(open(sch, encoding="utf-8"))
    if os.path.isfile(met):
        meta = json.load(open(met, encoding="utf-8"))
    rec = schema.get("recommend") or "list"
    rows = schema.get("rows_written") or ""
    cols = schema.get("n_columns") or ""
    desc = scrub(meta.get("abstract") or meta.get("description") or "")[:1200]
    print(f"<h2>{h.escape(title)}</h2>")
    print(f"<p>UCI dataset <strong>{h.escape(uci_id)}</strong> · imported as List ")
    print(f"<a href=\"query-executeQuery.view?schemaName=lists&amp;query.queryName={h.escape(listname, quote=True)}\">{h.escape(listname)}</a></p>")
    print("<ul>")
    print(f"<li>Rows: {h.escape(str(rows))} · Columns: {h.escape(str(cols))}</li>")
    print(f"<li>Recommendation: <strong>{h.escape(rec)}</strong> (List, not Study Dataset)</li>")
    print(f"<li>Inferred task: <strong>{h.escape(str(schema.get('task') or 'exploratory'))}</strong></li>")
    print(f"<li>Source: <a href=\"https://archive.ics.uci.edu/dataset/{h.escape(uci_id)}\">archive.ics.uci.edu/dataset/{h.escape(uci_id)}</a></li>")
    print("<li><a href=\"list-begin.view\">Manage Lists</a> · ")
    print("<a href=\"query-begin.view?schemaName=lists\">Schema lists</a> · ")
    print("<a href=\"reports-manageViews.view\">Data Views</a></li>")
    print("</ul>")
    if desc:
        print(f"<h3>Description</h3><p>{h.escape(desc)}</p>")
    print("<h3>How to work with this table</h3>")
    print("<ol>")
    print("<li>Use the grid below: filter, sort, export CSV/Excel.</li>")
    print("<li>Open Data Views or the Report web part for the default charts shipped with this folder.</li>")
    print("<li>Charts → Create Chart for additional scatter, box, or bar plots.</li>")
    print("<li>Grid Views → Save a named view; it appears in Data Views.</li>")
    print("<li>Reports → Create R or Python view on the same query.</li>")
    print("</ol>")
    fields = schema.get("fields") or []
    if fields:
        print("<h3>Fields</h3>")
        print("<table><thead><tr><th>Name</th><th>Type</th><th>Role</th></tr></thead><tbody>")
        for f in fields:
            print(
                f"<tr><td>{h.escape(str(f.get('name')))}</td>"
                f"<td>{h.escape(str(f.get('inferred')))}</td>"
                f"<td>{h.escape(str(f.get('role') or 'feature'))}</td></tr>"
            )
        print("</tbody></table>")


def cmd_domain_payload() -> None:
    schema = json.load(open(sys.argv[2], encoding="utf-8"))
    name = scrub(sys.argv[3])[:200]
    desc = scrub(sys.argv[4] if len(sys.argv) > 4 else "")
    fields = [{"name": "Key", "rangeURI": range_uri("int")}]
    for f in schema.get("fields", []):
        item = {
            "name": scrub(str(f["name"]))[:80],
            "rangeURI": f["rangeURI"],
            "label": scrub(str(f.get("label") or f["name"]))[:200],
        }
        if f.get("inferred") == "string" or f.get("scale"):
            item["scale"] = int(f.get("scale") or 4000)
        fields.append(item)
    payload = {
        "kind": "IntList",
        "domainDesign": {
            "name": name,
            "description": desc[:400],
            "fields": fields,
        },
        "options": {"keyName": "Key", "keyType": "AutoIncrementInteger"},
    }
    json.dump(payload, sys.stdout)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: uci_prepare.py filter_catalog|dump_meta|prepare|domain_payload|chart_plan|dataset_wiki")
    cmd = sys.argv[1]
    if cmd == "filter_catalog":
        cmd_filter_catalog()
    elif cmd == "dump_meta":
        cmd_dump_meta()
    elif cmd == "prepare":
        cmd_prepare()
    elif cmd == "domain_payload":
        cmd_domain_payload()
    elif cmd == "chart_plan":
        cmd_chart_plan()
    elif cmd == "dataset_wiki":
        cmd_dataset_wiki()
    else:
        sys.exit(f"unknown subcommand {cmd}")


if __name__ == "__main__":
    main()
PY
chmod +x "$HELPER"

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------
download() {
  local url="$1" dest="$2" label="$3"
  if [[ -s "$dest" && "$LK_FORCE" -eq 0 ]]; then
    log "  already present: $label ($(wc -c < "$dest" | tr -d ' ') bytes)"
    return 0
  fi
  log "  GET $url"
  if ! curl "${curl_flags[@]}" -o "$dest.part" "$url"; then
    rm -f "$dest.part"
    return 1
  fi
  mv "$dest.part" "$dest"
  log "  saved $(wc -c < "$dest" | tr -d ' ') bytes"
}

http_code() {
  printf '%s' "$1" | tr -d '\r' | grep -oE '[0-9]{3}' | tail -n 1
}

json_get() {
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

urlenc() { printf '%s' "$1" | sed 's/ /%20/g'; }

# ---------------------------------------------------------------------------
# Catalog
# ---------------------------------------------------------------------------
fetch_catalog() {
  local tmp="$DATA_DIR/catalog.raw.json"
  if [[ ! -s "$tmp" || "$LK_FORCE" -eq 1 ]]; then
    log "Fetching UCI dataset catalog"
    download "$UCI_LIST_URL" "$tmp" "catalog" || die "Cannot reach $UCI_LIST_URL"
  else
    log "Using cached catalog $tmp"
  fi
  LK_IDS="$LK_IDS" LK_SEARCH="$LK_SEARCH" \
    python3 "$HELPER" filter_catalog < "$tmp" > "$DATA_DIR/catalog.filtered.json"
  python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' \
    "$DATA_DIR/catalog.filtered.json" > "$DATA_DIR/catalog.count"
  log "Catalog entries after filter: $(cat "$DATA_DIR/catalog.count")"
}

# ---------------------------------------------------------------------------
# Per-dataset download / extract / prepare
# ---------------------------------------------------------------------------
pick_source_file() {
  local raw="$1"
  local f
  # Prefer prepared-looking tabular files
  for f in "$raw"/data.csv "$raw"/*.csv "$raw"/*.tsv "$raw"/*.data \
           "$raw"/*.txt "$raw"/*.arff "$raw"/*.xls "$raw"/*.xlsx; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in
      *.names|*.md|*.pdf|readme*|README*) continue ;;
    esac
    printf '%s\n' "$f"
    return 0
  done
  # Recurse one extra level (zips often unpack into a subfolder)
  local extra
  extra="$(find "$raw" -maxdepth 2 -type f \( \
      -name 'data.csv' -o -name '*.csv' -o -name '*.tsv' -o -name '*.data' \
      -o -name '*.arff' \) ! -iname 'readme*' 2>/dev/null | head -n 1 || true)"
  if [[ -n "$extra" ]]; then
    printf '%s\n' "$extra"
    return 0
  fi
  return 1
}

content_length() {
  local url="$1" len
  len="$(curl -sI "${curl_flags[@]}" "$url" 2>/dev/null \
    | awk 'BEGIN{IGNORECASE=1} /^content-length:/{print $2}' \
    | tr -d '\r' | tail -n 1)"
  printf '%s' "${len:-0}"
}

extract_if_archive() {
  local file="$1" dest="$2"
  case "$file" in
    *.zip)
      log "  unzip $(basename "$file")"
      mkdir -p "$dest"
      unzip -q -o "$file" -d "$dest" || return 1
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "$file" -C "$dest"
      ;;
    *.tar)
      tar -xf "$file" -C "$dest"
      ;;
    *.gz)
      local base
      base="$(basename "$file" .gz)"
      gzip -dc "$file" > "$dest/$base"
      ;;
    *)
      cp -f "$file" "$dest/"
      ;;
  esac
}

process_one() {
  local id="$1" name="$2"
  local slug meta_json work raw prep data_url zip_url src size
  slug="$(python3 -c 'import re,sys
s=re.sub(r"[^a-z0-9]+","_", sys.argv[1].strip().lower())
print(re.sub(r"_+","_",s).strip("_") or "dataset")' "$name")"
  work="$DATA_DIR/datasets/${id}_${slug}"
  raw="$work/raw"
  prep="$work/prepared"
  mkdir -p "$raw" "$prep"
  log "Dataset ${id} — ${name}"

  if [[ -s "$work/.imported_ok" && "$LK_FORCE" -eq 0 ]]; then
    if [[ "$LK_IMPORT" -eq 1 && "$LK_FLAT" -eq 0 ]]; then
      local dest="${LK_PROJECT}/${LK_FOLDER}/$(dataset_folder_name "$id" "$name")"
      if folder_exists "$dest"; then
        log "  already imported; refreshing dashboard"
        setup_dataset_portal "$dest" "$work" "$id" "$name" "$(list_name_for "$id" "$name")" || true
        printf 'skip\t%s\t%s\talready-imported\n' "$id" "$name"
        return 0
      fi
      log "  marker present but folder missing — re-importing"
    else
      log "  already imported; skip (use --force to rebuild)"
      printf 'skip\t%s\t%s\talready-imported\n' "$id" "$name"
      return 0
    fi
  fi

  if [[ -s "$prep/data.csv" && "$LK_SKIP_EXISTING" -eq 1 && "$LK_FORCE" -eq 0 && "$LK_IMPORT" -eq 0 ]]; then
    log "  already prepared"
    printf 'skip\t%s\t%s\talready-prepared\n' "$id" "$name"
    return 0
  fi

  # Re-run prepare on cached raw files so '?' / NaN become empty cells.
  if [[ -s "$prep/data.csv" || -s "$raw/data.csv" || -s "$raw/dataset.zip" ]] \
     && [[ "$LK_FORCE" -eq 0 ]]; then
    src="$(pick_source_file "$raw" || true)"
    if [[ -n "$src" && -s "$src" ]]; then
      size="$(wc -c < "$src" | tr -d ' ')"
      if [[ "$size" -le "$LK_MAX_BYTES" ]]; then
        log "  re-preparing from cached $src"
        prep_json="$(python3 "$HELPER" prepare "$src" "$prep" "$LK_MAX_ROWS" || true)"
        if printf '%s' "$prep_json" | grep -q '"ok": true'; then
          if [[ "$LK_IMPORT" -eq 1 ]]; then
            if import_one_dataset "$work" "$id" "$name"; then
              : > "$work/.imported_ok"
              printf 'ok\t%s\t%s\treprepared+imported\n' "$id" "$name"
            else
              printf 'fail\t%s\t%s\tlabkey-import\n' "$id" "$name" | tee -a "$FAILED"
            fi
            return 0
          fi
          printf 'ok\t%s\t%s\treprepared\n' "$id" "$name"
          return 0
        fi
      fi
    fi
  fi

  if [[ "$LK_DRY_RUN" -eq 1 ]]; then
    log "  dry-run: would fetch metadata + data"
    printf 'dry-run\t%s\t%s\n' "$id" "$name"
    return 0
  fi

  meta_json="$work/metadata.json"
  if ! curl "${curl_flags[@]}" "${UCI_ITEM_URL}?id=${id}" \
        | python3 "$HELPER" dump_meta > "$meta_json"; then
    log "  metadata fetch failed"
    printf 'fail\t%s\t%s\tmetadata\n' "$id" "$name" >> "$FAILED"
    return 0
  fi
  data_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("data_url") or "")' "$meta_json")"
  zip_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("zip_url") or "")' "$meta_json")"

  src=""
  if [[ -n "$data_url" ]]; then
    if download "$data_url" "$raw/data.csv" "data.csv"; then
      src="$raw/data.csv"
    fi
  fi
  if [[ -z "$src" && -n "$zip_url" ]]; then
    local zlen
    zlen="$(content_length "$zip_url")"
    if [[ "$zlen" =~ ^[0-9]+$ && "$zlen" -gt "$LK_MAX_BYTES" ]]; then
      log "  skip zip: Content-Length ${zlen} exceeds --max-bytes ${LK_MAX_BYTES}"
      printf 'skip\t%s\t%s\ttoo-large:%s\n' "$id" "$name" "$zlen" >> "$FAILED"
      printf 'skip\t%s\t%s\ttoo-large:%s\n' "$id" "$name" "$zlen"
      return 0
    fi
    if download "$zip_url" "$raw/dataset.zip" "dataset.zip"; then
      extract_if_archive "$raw/dataset.zip" "$raw/unpack" || true
      src="$(pick_source_file "$raw" || true)"
    fi
  fi
  if [[ -z "$src" ]]; then
    log "  no tabular download available (images/text/external only)"
    printf 'skip\t%s\t%s\tno-tabular-file\n' "$id" "$name" >> "$FAILED"
    return 0
  fi

  size="$(wc -c < "$src" | tr -d ' ')"
  if [[ "$size" -gt "$LK_MAX_BYTES" ]]; then
    log "  skip: $size bytes exceeds --max-bytes $LK_MAX_BYTES"
    printf 'skip\t%s\t%s\ttoo-large:%s\n' "$id" "$name" "$size" >> "$FAILED"
    return 0
  fi

  local prep_json
  prep_json="$(python3 "$HELPER" prepare "$src" "$prep" "$LK_MAX_ROWS" || true)"
  if ! printf '%s' "$prep_json" | grep -q '"ok": true'; then
    log "  prepare failed: $prep_json"
    printf 'fail\t%s\t%s\tprepare\n' "$id" "$name" >> "$FAILED"
    return 0
  fi
  log "  prepared $(printf '%s' "$prep_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("{rows} rows, {cols} cols, {recommend}".format(**d))')"
  if [[ "$LK_IMPORT" -eq 1 ]]; then
    if import_one_dataset "$work" "$id" "$name"; then
      : > "$work/.imported_ok"
      printf 'ok\t%s\t%s\t%s\n' "$id" "$name" "$prep/data.csv"
    else
      printf 'fail\t%s\t%s\tlabkey-import\n' "$id" "$name" | tee -a "$FAILED"
    fi
    return 0
  fi
  printf 'ok\t%s\t%s\t%s\n' "$id" "$name" "$prep/data.csv"
}

# ---------------------------------------------------------------------------
# LabKey session + list import
# ---------------------------------------------------------------------------
base=""
csrf=""
cookie_jar=""

probe_context() {
  local candidate="$1" label="$2" body code
  body="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
    "${auth_args[@]}" -H "Accept: application/json" \
    -w '\n%{http_code}' \
    "${candidate}/login-whoAmI.api" 2>/dev/null || true)"
  code="$(printf '%s' "$body" | tail -n 1)"
  body="$(printf '%s' "$body" | sed '$d')"
  if [[ "$code" == "200" ]] && printf '%s' "$body" | grep -qE '"CSRF"|"displayName"|"email"'; then
    log "  context ${label}: HTTP ${code}"
    csrf="$(printf '%s' "$body" | json_get CSRF)"
    return 0
  fi
  return 1
}

login_session() {
  local origin="${LK_URL%/}"
  cookie_jar="$(mktemp)"
  trap 'rm -f "$cookie_jar"' EXIT
  auth_args=()
  if [[ -n "$LK_APIKEY" ]]; then
    auth_args+=(-H "apikey: $LK_APIKEY")
  else
    auth_args+=(-u "${LK_USER}:${LK_PASSWORD}")
  fi
  case "$LK_CONTEXT" in
    auto|AUTO)
      log "Discovering application context on ${origin}"
      if probe_context "$origin" "(root)"; then
        base="$origin"
      elif probe_context "${origin}/labkey" "/labkey"; then
        base="${origin}/labkey"
      else
        die "Cannot reach login-whoAmI.api at ${origin}"
      fi
      ;;
    ""|/) base="$origin" ;;
    *)     base="${origin}/${LK_CONTEXT#/}"; base="${base%/}" ;;
  esac
  if [[ -z "$csrf" ]]; then
    csrf="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
      "${auth_args[@]}" -H "Accept: application/json" \
      "${base}/login-whoAmI.api" | json_get CSRF || true)"
  fi
  [[ -n "$csrf" ]] && log "  session CSRF acquired"
}

lk_post_json() {
  local cpath="$1" action="$2" payload="$3" out="$4"
  local url http
  cpath="${cpath#/}"
  if [[ -n "$cpath" ]]; then
    url="${base}/$(urlenc "$cpath")/${action}"
  else
    url="${base}/${action}"
  fi
  log "  POST ${url}"
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -d "$payload" -o "$out" -w '%{http_code}' "$url" || true)"
  printf '%s' "$(http_code "$http")"
}

ensure_container() {
  local parent="$1" name="$2" ftype="$3" dest payload out http
  if [[ "$parent" == "/" || -z "$parent" ]]; then
    dest="/${name}"; parent=""
  else
    dest="${parent%/}/${name}"
  fi
  log "Ensuring container '${dest}' (${ftype})"
  payload="$(printf '{"name":"%s","title":"%s","folderType":"%s","isWorkbook":false}' \
    "$name" "$name" "$ftype")"
  out="/tmp/labkey-uci-create.json"
  http="$(lk_post_json "$parent" "core-createContainer.api" "$payload" "$out")"
  if grep -qiE 'already exist|duplicate' "$out" 2>/dev/null; then
    log "  already exists"
    return 0
  fi
  if grep -qE '"path"|"name"' "$out" 2>/dev/null; then
    log "  created (HTTP ${http})"
    return 0
  fi
  # 200 on a folder that already exists sometimes returns the container JSON
  if [[ "$http" == "200" || "$http" == "201" ]]; then
    log "  HTTP ${http}"
    return 0
  fi
  log "  create response HTTP ${http}:"
  sed -n '1,12p' "$out" >&2 || true
  return 1
}

lk_post_form_action() {
  local cpath="$1" action="$2" out="$3"
  shift 3
  local url http
  cpath="${cpath#/}"
  if [[ -n "$cpath" ]]; then
    url="${base}/$(urlenc "$cpath")/${action}"
  else
    url="${base}/${action}"
  fi
  log "  POST ${url}"
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -o "$out" -w '%{http_code}' \
    "$@" "$url" || true)"
  printf '%s' "$(http_code "$http")"
}

portal_has_part() {
  local want="$1"
  python3 -c '
import json,sys
want=sys.argv[1].lower()
try:
    d=json.load(open("/tmp/labkey-uci-portal.json",encoding="utf-8"))
except Exception:
    d={}
parts=d.get("webparts") or d.get("parts") or []
if isinstance(parts, dict):
    parts=parts.get("webparts") or parts.get("body") or []
if not isinstance(parts, list):
    raise SystemExit(1)
for p in parts:
    if isinstance(p, dict) and str(p.get("name") or p.get("webPartName") or "").lower()==want:
        raise SystemExit(0)
raise SystemExit(1)
' "$want"
}

add_webpart() {
  local folder="$1" part="$2" page="$3" out="/tmp/labkey-uci-webpart.json" http ret
  # CE 26 AddWebPart is a FormViewAction. After a successful add it calls
  # getSuccessURL() → addReturnUrl(). Without returnUrl that NPEs and
  # floods labkey.log even though the web part may already have been saved.
  if [[ -z "$page" || "$page" == "null" ]]; then
    log "  skip web part ${part}: no pageId"
    return 1
  fi
  fetch_portal "$folder" "$page"
  if portal_has_part "$part"; then
    log "  web part already present: ${part}"
    return 0
  fi
  ret="/$(urlenc "$folder")/project-begin.view"
  http="$(lk_post_form_action "$folder" "project-addWebPart.api" "$out" \
    --data-urlencode "name=${part}" \
    --data-urlencode "location=body" \
    --data-urlencode "pageId=${page}" \
    --data-urlencode "returnUrl=${ret}" \
    --data-urlencode "returnURL=${ret}")"
  if [[ "$http" == "200" || "$http" == "302" || "$http" == "303" ]]; then
    return 0
  fi
  log "  addWebPart ${part} HTTP ${http} — skip"
  return 1
}

discover_page_id() {
  local folder="$1"
  fetch_portal "$folder" "portal.default"
  python3 - <<'PY'
import json,re
allowed={"portal.default","DefaultDashboard","folderDefault","portal"}
page=""
try:
    d=json.load(open("/tmp/labkey-uci-portal.json",encoding="utf-8"))
    page=str(d.get("pageId") or d.get("page") or "")
except Exception:
    page=""
if page in allowed or (page and page not in ("null","None")):
    if page:
        print(page)
        raise SystemExit
html=""
try:
    html=open("/tmp/labkey-uci-begin.html",encoding="utf-8",errors="replace").read()
except Exception:
    pass
for pat in [
    r'["\']pageId["\']\s*:\s*["\'](portal\.default|DefaultDashboard|folderDefault|portal)["\']',
]:
    m=re.search(pat, html)
    if m:
        print(m.group(1))
        raise SystemExit
print("portal.default")
PY
}

fetch_portal() {
  local folder="$1" page="$2"
  : > /tmp/labkey-uci-portal.json
  curl "${api_flags[@]}" --max-redirs 0 \
    "${auth_args[@]}" -b "$cookie_jar" -c "$cookie_jar" \
    -H "Accept: application/json" \
    -o /tmp/labkey-uci-portal.json \
    "${base}/$(urlenc "$folder")/project-getPortal.api?pageId=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$page")" \
    >/dev/null || true
}

list_queries_html() {
  local folder="$1"
  curl "${api_flags[@]}" --max-redirs 0 \
    "${auth_args[@]}" -b "$cookie_jar" -c "$cookie_jar" \
    -H "Accept: application/json" \
    -o /tmp/labkey-uci-queries.json \
    "${base}/$(urlenc "$folder")/query-getQueries.api?schemaName=lists" >/dev/null || true
  python3 - <<'PY'
import json, html
p="/tmp/labkey-uci-queries.json"
try:
    d=json.load(open(p,encoding="utf-8"))
except Exception:
    d={}
qs=d.get("queries") or d.get("queryInfos") or []
names=[]
for q in qs:
    n=q.get("name") or q.get("queryName")
    if n and n != "Key":
        names.append(n)
names=sorted(set(names), key=lambda s: s.lower())
print("<h2>UCI Datasets</h2>")
print("<p>Each UCI table is imported as a LabKey <strong>List</strong> in this folder,")
print("similar to how the HIV Study folder surfaces its study datasets.</p>")
print("<p><a href=\"list-begin.view\">Manage Lists</a> · ")
print("<a href=\"query-begin.view?schemaName=lists\">Schema lists</a></p>")
if not names:
    print("<p><em>No lists yet. Re-run the importer with --import.</em></p>")
else:
    print(f"<p>{len(names)} list(s):</p>")
    print("<table class=\"labkey-data-region\"><thead><tr><th>List</th><th>Open</th></tr></thead><tbody>")
    for n in names:
        esc=html.escape(n)
        href=f"query-executeQuery.view?schemaName=lists&amp;query.queryName={html.escape(n, quote=True)}"
        print(f"<tr><td>{esc}</td><td><a href=\"{href}\">grid</a></td></tr>")
    print("</tbody></table>")
PY
}

save_wiki_home() {
  local folder="$1" title="$2" body="$3" out="/tmp/labkey-uci-wiki.json" http
  for action in wiki-saveWiki.api wiki-save.api wiki-editWiki.post; do
    http="$(lk_post_form_action "$folder" "$action" "$out" \
      --data-urlencode "name=home" \
      --data-urlencode "title=${title}" \
      --data-urlencode "rendererType=HTML" \
      --data-urlencode "body=${body}")"
    if [[ "$http" == "200" || "$http" == "302" ]] && ! grep -qiE 'exception|Error' "$out" 2>/dev/null; then
      log "  wiki saved via ${action} (HTTP ${http})"
      return 0
    fi
  done
  http="$(lk_post_json "$folder" "wiki-saveWiki.api" \
    "$(python3 -c 'import json,sys; print(json.dumps({"name":"home","title":sys.argv[1],"rendererType":"HTML","body":sys.argv[2]}))' "$title" "$body")" \
    "$out")"
  log "  wiki JSON save HTTP ${http}"
  [[ "$http" == "200" ]]
}

bind_wiki_webpart() {
  local folder="$1" page="$2"
  fetch_portal "$folder" "$page"
  python3 - <<'PY' > /tmp/labkey-uci-wiki-wp.json
import json
try:
    d=json.load(open("/tmp/labkey-uci-portal.json",encoding="utf-8"))
except Exception:
    d={}
parts=d.get("webparts") or d.get("parts") or d.get("portal") or []
if isinstance(parts, dict):
    parts=parts.get("webparts") or parts.get("body") or []
found=None
if isinstance(parts, list):
    for p in parts:
        if isinstance(p, dict) and str(p.get("name") or p.get("webPartName") or "").lower()=="wiki":
            found=p
            break
if found:
    wid=found.get("webPartId") or found.get("id") or found.get("portalId")
    print(wid or "")
else:
    print("")
PY
  local wid
  wid="$(tr -d '[:space:]' < /tmp/labkey-uci-wiki-wp.json)"
  [[ -n "$wid" ]] || return 1
  local payload out http
  payload="$(printf '{"webPartId":%s,"properties":{"name":"home","webPartId":"home"}}' "$wid")"
  out="/tmp/labkey-uci-wpupdate.json"
  http="$(lk_post_json "$folder" "project-updateWebPart.api" "$payload" "$out")"
  if [[ "$http" != "200" ]]; then
    http="$(lk_post_form_action "$folder" "project-updateWebPart.api" "$out" \
      --data-urlencode "webPartId=${wid}" \
      --data-urlencode "name=home" \
      --data-urlencode "webPartId.name=home")"
  fi
  log "  wiki web part ${wid} bound to page home (HTTP ${http})"
}

catalog_wiki_html() {
  local folder="$1"
  curl "${api_flags[@]}" --max-redirs 0 \
    "${auth_args[@]}" -b "$cookie_jar" -c "$cookie_jar" \
    -H "Accept: application/json" \
    -o /tmp/labkey-uci-children.json \
    "${base}/$(urlenc "$folder")/project-getContainers.api" >/dev/null || true
  python3 - <<'PY'
import json, html
try:
    d=json.load(open("/tmp/labkey-uci-children.json",encoding="utf-8"))
except Exception:
    d={}
kids=[]
if isinstance(d, list):
    kids=d
else:
    kids=d.get("children") or d.get("containers") or d.get("subfolders") or []
    if isinstance(d.get("container"), dict):
        kids = d["container"].get("children") or kids
names=[]
for k in kids:
    if not isinstance(k, dict):
        continue
    n=k.get("name") or k.get("title")
    if n:
        names.append(n)
names=sorted(set(names), key=lambda s: s.lower())
print("<h2>UCI Datasets</h2>")
print("<p>Each UCI table lives in its <strong>own subfolder</strong>, like the HIV Study under Tutorials.")
print("Open a folder for the grid, wiki, charts, and files of that dataset only.</p>")
print("<p><a href=\"project-begin.view\">This catalog</a> · Subfolders web part below.</p>")
if not names:
    print("<p><em>No dataset folders yet. Run the importer with --import.</em></p>")
else:
    print(f"<p>{len(names)} dataset folder(s):</p>")
    print("<table><thead><tr><th>Folder</th></tr></thead><tbody>")
    for n in names:
        esc=html.escape(n)
        href=html.escape(n, quote=True) + "/project-begin.view"
        print(f"<tr><td><a href=\"{href}\">{esc}</a></td></tr>")
    print("</tbody></table>")
PY
}

ensure_uci_landing() {
  local folder="$1" page body
  page="$(discover_page_id "$folder")"
  log "  catalog pageId=${page}"
  fetch_portal "$folder" "$page"
  add_webpart "$folder" "Data Views" "$page" || true
  body="$(catalog_wiki_html "$folder")"
  save_wiki_home "$folder" "UCI Datasets" "$body" || true
  bind_wiki_webpart "$folder" "$page" || true
  log "  catalog UI: ${base}/$(urlenc "$folder")/project-begin.view"
}

list_name_for() {
  python3 -c 'import sys,re
i,n=sys.argv[1],sys.argv[2]
s=re.sub(r"[^A-Za-z0-9_]+","_", n)[:40].strip("_")
print("UCI_{}_{}".format(i, s or "dataset"))' "$1" "$2"
}

dataset_folder_name() {
  local id="$1" name="$2" slug
  slug="$(python3 -c 'import re,sys
s=re.sub(r"[^A-Za-z0-9]+","_", sys.argv[1].strip())
s=re.sub(r"_+","_",s).strip("_") or "dataset"
print(s[:48])' "$name")"
  printf '%s_%s' "$id" "$slug"
}

folder_exists() {
  local path="$1" http
  http="$(curl "${api_flags[@]}" --max-redirs 0 \
    "${auth_args[@]}" -b "$cookie_jar" -c "$cookie_jar" \
    -o /tmp/labkey-uci-folderprobe.json -w '%{http_code}' \
    "${base}/$(urlenc "$path")/login-whoAmI.api" || true)"
  [[ "$(http_code "$http")" == "200" ]]
}

bind_named_webpart() {
  local folder="$1" page="$2" part="$3"
  shift 3
  fetch_portal "$folder" "$page"
  python3 -c '
import json,sys
want=sys.argv[1].lower()
try:
    d=json.load(open("/tmp/labkey-uci-portal.json",encoding="utf-8"))
except Exception:
    d={}
parts=d.get("webparts") or d.get("parts") or []
if isinstance(parts, dict):
    parts=parts.get("webparts") or parts.get("body") or []
wid=""
if isinstance(parts, list):
    for p in parts:
        if isinstance(p, dict) and str(p.get("name") or p.get("webPartName") or "").lower()==want:
            wid=str(p.get("webPartId") or p.get("id") or "")
            break
print(wid)
' "$part" > /tmp/labkey-uci-wpid.txt
  local wid payload out http
  wid="$(tr -d '[:space:]' < /tmp/labkey-uci-wpid.txt)"
  [[ -n "$wid" ]] || return 1
  payload="$(python3 -c 'import json,sys
props=json.loads(sys.argv[2])
print(json.dumps({"webPartId": int(sys.argv[1]) if sys.argv[1].isdigit() else sys.argv[1], "properties": props}))
' "$wid" "$1")"
  out="/tmp/labkey-uci-wpprops.json"
  http="$(lk_post_json "$folder" "project-updateWebPart.api" "$payload" "$out")"
  if [[ "$http" != "200" ]]; then
    http="$(lk_post_form_action "$folder" "project-updateWebPart.api" "$out" \
      --data-urlencode "webPartId=${wid}" \
      --data-urlencode "schemaName=$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("schemaName",""))')" \
      --data-urlencode "queryName=$(printf '%s' "$1" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("queryName",""))')")"
  fi
  log "  web part ${part} id=${wid} HTTP ${http}"
}

upload_dataset_file() {
  local folder="$1" csv="$2" http
  [[ -s "$csv" ]] || return 0
  local url="${base}/_webdav/$(urlenc "$folder")/@files/data.csv"
  log "  PUT ${url}"
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X PUT \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -H "Content-Type: text/csv" \
    --upload-file "$csv" \
    -o /tmp/labkey-uci-webdav.txt -w '%{http_code}' \
    "$url" || true)"
  log "  webdav PUT HTTP $(http_code "$http")"
}

save_one_chart() {
  local folder="$1" listname="$2" planjson="$3"
  local payload out http
  payload="$(python3 -c '
import json,sys
plan=json.loads(sys.argv[1])
schemaName, query = sys.argv[2], sys.argv[3]
render=plan.get("renderType")
def measure(spec):
    if not spec:
        return None
    m={
        "name": spec["name"],
        "label": spec.get("label") or spec["name"],
        "type": spec.get("type") or "VARCHAR",
        "schemaName": schemaName,
        "queryName": query,
    }
    return m
measures={}
if plan.get("x"):
    measures["x"]=measure(plan["x"])
if plan.get("y"):
    measures["y"]=measure(plan["y"])
if plan.get("color"):
    measures["color"]=measure(plan["color"])
chart={
    "renderType": render,
    "measures": measures,
    "scales": {"x": {"type": "automatic"}, "y": {"type": "automatic"}},
    "labels": {
        "main": plan.get("name") or "Chart",
        "x": (plan.get("x") or {}).get("label") or "",
        "y": (plan.get("y") or {}).get("label") or "",
    },
    "geomOptions": {
        "binThreshold": 6000,
        "opacity": 0.6,
        "pointSize": 5,
        "pointFillColor": "3366FF",
        "colorPaletteScale": "ColorDiscrete",
        "chartLayout": "single",
        "lineWidth": 3,
        "pieInnerRadius": 0,
        "pieOuterRadius": 100,
        "showOutliers": True,
    },
    "pointType": "all",
    "width": 800,
    "height": 480,
}
queryConfig={
    "schemaName": schemaName,
    "queryName": query,
    "viewName": None,
    "maxRows": -1,
    "requiredVersion": 17.1,
}
vis={"chartConfig": chart, "queryConfig": queryConfig}
print(json.dumps({
    "name": plan.get("name") or "Default chart",
    "description": "Auto-created UCI default visualization",
    "type": "ReportService.GenericChartReport",
    "schemaName": schemaName,
    "queryName": query,
    "shared": True,
    "replace": True,
    "thumbnailType": "AUTO",
    "json": json.dumps(vis),
}))
' "$planjson" "lists" "$listname")"
  out="/tmp/labkey-uci-chart.json"
  for action in visualization-saveVisualization.api visualization-saveVisualization.post visualization-genericChartSave.api; do
    http="$(lk_post_json "$folder" "$action" "$payload" "$out")"
    if [[ "$http" == "200" ]] && ! grep -qiE '"success"[[:space:]]*:[[:space:]]*false|exception' "$out" 2>/dev/null; then
      log "  saved chart: $(printf '%s' "$planjson" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("name",""))')"
      python3 -c 'import json,sys
try:
    d=json.load(open("/tmp/labkey-uci-chart.json",encoding="utf-8"))
except Exception:
    d={}
print(d.get("reportId") or d.get("visualizationId") or d.get("id") or "")'
      return 0
    fi
  done
  log "  chart save failed"
  sed -n '1,10p' "$out" >&2 || true
  return 1
}

save_default_chart() {
  local folder="$1" listname="$2" schema="$3" page="${4:-portal.default}"
  [[ -s "$schema" ]] || return 0
  local plans n i plan rid props
  plans="$(python3 "$HELPER" chart_plan "$schema" || true)"
  n="$(printf '%s' "$plans" | python3 -c 'import json,sys
try:
    print(len(json.load(sys.stdin)))
except Exception:
    print(0)')"
  if [[ "$n" -eq 0 ]]; then
    log "  no default chart for this schema"
    return 0
  fi
  log "  creating ${n} default chart(s)"
  for i in $(seq 0 $((n - 1))); do
    plan="$(printf '%s' "$plans" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)[int(sys.argv[1])]))' "$i")"
    rid="$(save_one_chart "$folder" "$listname" "$plan" || true)"
    if [[ "$i" -eq 0 && -n "$rid" ]]; then
      add_webpart "$folder" "Report" "$page" || true
      props="$(python3 -c 'import json,sys; print(json.dumps({"reportId":sys.argv[1],"title":"Default chart"}))' "$rid")"
      bind_named_webpart "$folder" "$page" "Report" "$props" || true
    fi
  done
}

setup_dataset_portal() {
  local folder="$1" work="$2" id="$3" name="$4" listname="$5"
  local page props body
  log "  dashboard for /${folder}"
  page="$(discover_page_id "$folder")"
  add_webpart "$folder" "Query" "$page" || true
  props="$(python3 -c 'import json,sys; print(json.dumps({"schemaName":"lists","queryName":sys.argv[1],"title":sys.argv[2],"allowChooseQuery":"false","allowChooseView":"true"}))' "$listname" "$name")"
  bind_named_webpart "$folder" "$page" "Query" "$props" || true
  add_webpart "$folder" "Data Views" "$page" || true
  add_webpart "$folder" "Files" "$page" || true
  body="$(python3 "$HELPER" dataset_wiki "$work" "$name" "$id" "$listname" || true)"
  save_wiki_home "$folder" "$name" "$body" || true
  bind_wiki_webpart "$folder" "$page" || true
  upload_dataset_file "$folder" "$work/prepared/data.csv" || true
  save_default_chart "$folder" "$listname" "$work/prepared/schema.json" "$page" || true
  log "  open ${base}/$(urlenc "$folder")/project-begin.view"
}

import_one_dataset() {
  local work="$1" id="$2" name="$3" parent child dest listname
  parent="${LK_PROJECT}/${LK_FOLDER}"
  if [[ "$LK_FLAT" -eq 1 ]]; then
    dest="$parent"
  else
    child="$(dataset_folder_name "$id" "$name")"
    dest="${parent}/${child}"
    if ! ensure_container "/${parent}" "$child" "Collaboration"; then
      log "  cannot create dataset folder ${dest}"
      return 1
    fi
  fi
  import_list "$dest" "$work" "$id" "$name" || return 1
  listname="$(list_name_for "$id" "$name")"
  setup_dataset_portal "$dest" "$work" "$id" "$name" "$listname" || true
  return 0
}

list_exists() {
  local folder="$1" listname="$2" http
  http="$(curl "${api_flags[@]}" --max-redirs 0 \
    "${auth_args[@]}" -b "$cookie_jar" -c "$cookie_jar" \
    -H "Accept: application/json" \
    -o /tmp/labkey-uci-getquery.json \
    -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/query-getQuery.api?schemaName=lists&query.queryName=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$listname")&maxRows=1" \
    || true)"
  [[ "$(http_code "$http")" == "200" ]]
}

drop_list() {
  local folder="$1" listname="$2" payload out http
  payload="$(printf '{"schemaName":"lists","queryName":"%s"}' "$listname")"
  out="/tmp/labkey-uci-drop.json"
  http="$(lk_post_json "$folder" "property-deleteDomain.api" "$payload" "$out")"
  if [[ "$http" != "200" ]] || grep -qiE 'exception' "$out" 2>/dev/null; then
    payload="$(printf '{"name":"%s"}' "$listname")"
    http="$(lk_post_json "$folder" "list-deleteListDefinition.api" "$payload" "$out")"
  fi
  log "  dropped list ${listname} (HTTP ${http})"
}

import_list() {
  local folder="$1" work="$2" uci_id="$3" dsname="$4"
  local schema csv listname desc payload out http
  schema="$work/prepared/schema.json"
  csv="$work/prepared/data.csv"
  [[ -s "$csv" && -s "$schema" ]] || { log "  missing prepared files"; return 1; }

  listname="$(python3 -c 'import sys,re
i,n=sys.argv[1],sys.argv[2]
s=re.sub(r"[^A-Za-z0-9_]+","_", n)[:40].strip("_")
print("UCI_{}_{}".format(i, s or "dataset"))' "$uci_id" "$dsname")"
  desc="$(python3 -c 'import json,sys,re
m=json.load(open(sys.argv[1]))
print(re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]","", (m.get("abstract") or m.get("name") or ""))[:400])' "$work/metadata.json" 2>/dev/null || printf '%s' "$dsname")"

  create_list_domain() {
    payload="$(python3 "$HELPER" domain_payload "$schema" "$listname" "$desc")"
    out="/tmp/labkey-uci-domain.json"
    http="$(lk_post_json "$folder" "property-createDomain.api" "$payload" "$out")"
    log "  createDomain HTTP ${http}"
    if grep -qE '"domainId"|"success"[[:space:]]*:[[:space:]]*true' "$out" 2>/dev/null; then
      return 0
    fi
    if grep -qiE 'already exist|duplicate' "$out" 2>/dev/null; then
      log "  domain already exists"
      return 0
    fi
    sed -n '1,20p' "$out" >&2 || true
    return 1
  }

  if list_exists "$folder" "$listname"; then
    log "  list ${listname} exists — dropping so types can be rebuilt"
    drop_list "$folder" "$listname"
  fi
  create_list_domain || return 1

  query_import() {
    out="/tmp/labkey-uci-import.json"
    log "  importing $(wc -l < "$csv" | tr -d ' ') lines into lists.${listname}"
    http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
      ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
      -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
      -F "schemaName=lists" \
      -F "queryName=${listname}" \
      -F "insertOption=IMPORT" \
      -F "importIdentity=false" \
      -F "file=@${csv};type=text/csv" \
      -o "$out" -w '%{http_code}' \
      "${base}/$(urlenc "$folder")/query-import.api" || true)"
    http="$(http_code "$http")"
    log "  query-import HTTP ${http}"
    if [[ "$http" == "200" ]] && grep -qE '"success"[[:space:]]*:[[:space:]]*true' "$out" 2>/dev/null; then
      log "  imported"
      sed -n '1,8p' "$out" >&2 || true
      return 0
    fi
    log "  import rejected:"
    sed -n '1,12p' "$out" >&2 || true
    return 1
  }

  if query_import; then
    return 0
  fi
  log "  retry after drop + recreate"
  drop_list "$folder" "$listname" || true
  create_list_domain || return 1
  query_import
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
: > "$FAILED"
printf 'status\tid\tname\tdetail\n' > "$MANIFEST"

if [[ "$LK_LANDING_ONLY" -eq 0 ]]; then
  fetch_catalog
fi

processed=0
imported=0
failed=0
folder_path="${LK_PROJECT}/${LK_FOLDER}"

if [[ "$LK_IMPORT" -eq 1 ]]; then
  if [[ -z "$LK_APIKEY" && ( -z "$LK_USER" || -z "$LK_PASSWORD" ) ]]; then
    die "--import needs --user/--password or --apikey"
  fi
  login_session
  ensure_container "/" "$LK_PROJECT" "Collaboration" || die "Cannot create project ${LK_PROJECT}"
  ensure_container "/$LK_PROJECT" "$LK_FOLDER" "Collaboration" || die "Cannot create folder ${LK_FOLDER}"
  ensure_uci_landing "$folder_path" || true
fi

if [[ "$LK_LANDING_ONLY" -eq 1 ]]; then
  log "Landing-only: catalog + per-dataset dashboards"
  if [[ "$LK_FLAT" -eq 0 ]]; then
    for meta in "$DATA_DIR"/datasets/*/metadata.json; do
      [[ -f "$meta" ]] || continue
      work="$(dirname "$meta")"
      id="$(python3 -c 'import json,sys,os; d=json.load(open(sys.argv[1])); print(d.get("id") or os.path.basename(os.path.dirname(sys.argv[1])).split("_")[0])' "$meta")"
      name="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("name") or "")' "$meta")"
      [[ -n "$id" && -n "$name" ]] || continue
      dest="${folder_path}/$(dataset_folder_name "$id" "$name")"
      if folder_exists "$dest"; then
        setup_dataset_portal "$dest" "$work" "$id" "$name" "$(list_name_for "$id" "$name")" || true
      fi
    done
  fi
  log "Open ${base}/$(urlenc "$folder_path")/project-begin.view"
  exit 0
fi

# Iterate catalog as id<TAB>name
python3 -c 'import json,sys
for r in json.load(open(sys.argv[1])):
    print("{}\t{}".format(r["id"], r["name"].replace("\t"," ")))
' "$DATA_DIR/catalog.filtered.json" > "$DATA_DIR/catalog.tsv"

while IFS=$'\t' read -r id name; do
  [[ -n "$id" ]] || continue
  if [[ "$LK_LIMIT" -gt 0 && "$processed" -ge "$LK_LIMIT" ]]; then
    log "Reached --limit ${LK_LIMIT}"
    break
  fi
  process_one "$id" "$name" >> "$MANIFEST" || true
  processed=$((processed + 1))
done < "$DATA_DIR/catalog.tsv"
imported="$(grep -c $'^ok\t' "$MANIFEST" || true)"
failed="$(grep -c $'^fail\t' "$MANIFEST" || true)"

if [[ "$LK_IMPORT" -eq 1 ]]; then
  ensure_uci_landing "$folder_path" || true
fi

{
  echo "# UCI → LabKey"
  echo
  echo "Each dataset is downloaded, prepared, and (with --import) loaded as a List"
  echo "in /${LK_PROJECT}/${LK_FOLDER} before the next dataset starts."
  echo
  echo "Each dataset is a subfolder of /${LK_PROJECT}/${LK_FOLDER}"
  echo "(HIV-Study style: one folder, one table, wiki + query + charts)."
  echo
  echo "Catalog:"
  echo "  ${LK_URL%/}/${LK_PROJECT}/$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$LK_FOLDER")/project-begin.view"
  echo
} > "$DATA_DIR/IMPORT.md"

log "Processed ${processed} dataset(s); imported ${imported}; failures in $FAILED"
if [[ "$LK_IMPORT" -eq 1 ]]; then
  log "Lists: ${base}/$(urlenc "$folder_path")/list-begin.view"
else
  log "Download/prepare only. Re-run with --import to load Lists."
fi
log "Manifest: $MANIFEST"
