#!/usr/bin/env bash
# install-labkey-v940-evidence.sh
#
# Curated public evidence shelf for intismeran autogene (mRNA-4157 / V940)
# + pembrolizumab. Top-level LabKey project like Tutorials / UCI-Labs.
#
# Downloads only public registry, publication, melanoma-reference and
# safety extracts. No Moderna/Merck IPD, no FASTQ, no USB/SPHN patients.
#
set -euo pipefail

DATA_DIR="${LK_V940_DIR:-$HOME/src/labkeyV940Evidence}"
LK_IMPORT=0
LK_DRY_RUN=0
LK_INSECURE="${LK_INSECURE:-0}"
LK_URL="${LK_URL:-https://127.0.0.1:8443}"
LK_USER="${LK_USER:-}"
LK_PASSWORD="${LK_PASSWORD:-}"
LK_APIKEY="${LK_APIKEY:-}"
LK_CONTEXT="${LK_CONTEXT:-auto}"
LK_PROJECT="${LK_PROJECT:-V940-Evidence}"
LK_FOLDER="${LK_FOLDER:-Evidence Shelf}"
LK_LIMIT="${LK_LIMIT:-0}"
LK_IDS="${LK_IDS:-}"
LK_SEARCH="${LK_SEARCH:-}"
LK_MAX_BYTES="${LK_MAX_BYTES:-52428800}"
LK_MAX_ROWS="${LK_MAX_ROWS:-20000}"
LK_FORCE=0
LK_LANDING_ONLY=0

usage() {
  cat <<'EOF'
Public V940 / KEYNOTE-942 evidence → LabKey Lists + HIV/UCI-style folders.

  ./install-labkey-v940-evidence.sh --dry-run
  ./install-labkey-v940-evidence.sh --import \
      --url https://127.0.0.1:8443 --user admin --password secret --insecure

Layout:
  /V940-Evidence/Evidence Shelf/{id}
    Wiki · Query · Data Views · Files · default charts

Sources:
  v940_trials, kn942_overview, kn942_arms, kn942_outcomes,
  interpath001_overview, interpath001_arms, interpath001_outcomes,
  interpath012_overview, kn603_overview, kn603_arms,
  pubmed_intismeran, cbioportal_melanoma, openfda_pembrolizumab,
  published_claims, evidence_score (computed), translational_links

Not downloaded: trial IPD, vaccine FASTA, WES/RNA-seq, USB/SPHN rows.

Exit codes: 0 all ok, 2 some sources failed, 1 fatal.
EOF
}

FAIL_COUNT=0
log() { printf '[v940-evidence] %s\n' "$*" >&2; }
warn() { printf '[v940-evidence] WARN: %s\n' "$*" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
die() { printf '[v940-evidence] ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)          DATA_DIR="$2"; shift 2 ;;
    --ids)          LK_IDS="$2"; shift 2 ;;
    --search)       LK_SEARCH="$2"; shift 2 ;;
    --limit)        LK_LIMIT="$2"; shift 2 ;;
    --max-bytes)    LK_MAX_BYTES="$2"; shift 2 ;;
    --max-rows)     LK_MAX_ROWS="$2"; shift 2 ;;
    --force)        LK_FORCE=1; shift ;;
    --import)       LK_IMPORT=1; shift ;;
    --landing-only) LK_LANDING_ONLY=1; LK_IMPORT=1; shift ;;
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
need curl; need python3; need zip

case "${LK_URL}" in
  https://127.0.0.1*|https://localhost*|https://[::1]*) LK_INSECURE=1 ;;
esac

curl_flags=(-fsSL --retry 3 --retry-delay 2 -A "Mozilla/5.0 LabKey-V940-Evidence")
api_flags=(-sS --retry 2 --retry-delay 1 -A "Mozilla/5.0 LabKey-V940-Evidence")
if [[ "$LK_INSECURE" -eq 1 ]]; then
  curl_flags+=(-k); api_flags+=(-k)
  export V940_INSECURE=1
fi

mkdir -p "$DATA_DIR/sources"
MANIFEST="$DATA_DIR/MANIFEST.tsv"
FAILED="$DATA_DIR/FAILED.tsv"
CATALOG="$DATA_DIR/catalog.json"
HELPER="$DATA_DIR/.v940_prepare.py"

cat > "$CATALOG" <<'JSON'
[
  {"id":"v940_trials","name":"V940 / intismeran trials","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov","license":"public","format":"ctg_search","url":"https://clinicaltrials.gov/api/v2/studies?query.term=intismeran%20OR%20mRNA-4157%20OR%20V940%20OR%20KEYNOTE-942&pageSize=50","note":"Search snapshot of public trial records. Not IPD."},
  {"id":"kn942_overview","name":"KEYNOTE-942 overview","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT03897881","license":"public","format":"ctg_overview","url":"https://clinicaltrials.gov/api/v2/studies/NCT03897881","note":"Phase 2b adjuvant melanoma. Sponsor ModernaTX. NCT03897881."},
  {"id":"kn942_arms","name":"KEYNOTE-942 arms","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT03897881","license":"public","format":"ctg_arms","url":"https://clinicaltrials.gov/api/v2/studies/NCT03897881"},
  {"id":"kn942_outcomes","name":"KEYNOTE-942 outcomes","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT03897881","license":"public","format":"ctg_outcomes","url":"https://clinicaltrials.gov/api/v2/studies/NCT03897881"},
  {"id":"interpath001_overview","name":"INTerpath-001 overview","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT05933577","license":"public","format":"ctg_overview","url":"https://clinicaltrials.gov/api/v2/studies/NCT05933577","note":"Phase 3 adjuvant melanoma V940-001. Sponsor MSD. NCT05933577."},
  {"id":"interpath001_arms","name":"INTerpath-001 arms","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT05933577","license":"public","format":"ctg_arms","url":"https://clinicaltrials.gov/api/v2/studies/NCT05933577"},
  {"id":"interpath001_outcomes","name":"INTerpath-001 outcomes","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT05933577","license":"public","format":"ctg_outcomes","url":"https://clinicaltrials.gov/api/v2/studies/NCT05933577"},
  {"id":"interpath012_overview","name":"INTerpath-012 overview","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT06961006","license":"public","format":"ctg_overview","url":"https://clinicaltrials.gov/api/v2/studies/NCT06961006","note":"Phase 2 first-line advanced melanoma. NCT06961006."},
  {"id":"kn603_overview","name":"KEYNOTE-603 overview","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT03313778","license":"public","format":"ctg_overview","url":"https://clinicaltrials.gov/api/v2/studies/NCT03313778","note":"Phase 1 first-in-human mRNA-4157. NCT03313778."},
  {"id":"kn603_arms","name":"KEYNOTE-603 arms","org":"ClinicalTrials.gov","kind":"registry","homepage":"https://clinicaltrials.gov/study/NCT03313778","license":"public","format":"ctg_arms","url":"https://clinicaltrials.gov/api/v2/studies/NCT03313778"},
  {"id":"pubmed_intismeran","name":"PubMed intismeran / mRNA-4157","org":"NCBI","kind":"publications","homepage":"https://pubmed.ncbi.nlm.nih.gov","license":"NCBI public","format":"pubmed","url":"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmax=80&retmode=json&term=intismeran%20OR%20mRNA-4157%20OR%20V940%20neoantigen"},
  {"id":"cbioportal_melanoma","name":"cBioPortal melanoma studies","org":"cBioPortal","kind":"biomarker_reference","homepage":"https://www.cbioportal.org","license":"study-specific","format":"json_records","url":"https://www.cbioportal.org/api/studies","json_path":"","filter_text":"melanoma","note":"Public melanoma cohorts for TMB/BRAF context. Not V940 IPD."},
  {"id":"openfda_pembrolizumab","name":"OpenFDA pembrolizumab reactions","org":"FDA","kind":"safety","homepage":"https://open.fda.gov","license":"public domain","format":"openfda","url":"https://api.fda.gov/drug/event.json?search=patient.drug.medicinalproduct:pembrolizumab+AND+patient.drug.drugindication:melanoma&limit=100","note":"Spontaneous reports, not trial AEs. Confounding possible."},
  {"id":"published_claims","name":"Published endpoint claims","org":"Lancet / JCO / Merck-Moderna","kind":"evidence","homepage":"https://pubmed.ncbi.nlm.nih.gov","license":"cite original papers","format":"curated","url":"","note":"Cited aggregate HRs only. Not IPD. Score in evidence_score."},
  {"id":"translational_links","name":"Translational supplements","org":"AACR / Figshare / posters","kind":"translational","homepage":"https://doi.org/10.1158/2159-8290.27435520","license":"publisher","format":"curated_links","url":"","note":"KEYNOTE-603 peptide/HLA supplement and KEYNOTE-942 poster pointers. Not IPD."}
]
JSON

cat > "$HELPER" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import csv, json, os, re, sys, time
from typing import Any
from urllib.request import Request, urlopen

def scrub(s: Any) -> str:
    if s is None:
        return ""
    if isinstance(s, (dict, list)):
        s = json.dumps(s, ensure_ascii=False)
    return re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", str(s).replace("\x00", ""))[:4000]

def clean_col(name: str, used: set[str]) -> str:
    s = re.sub(r"[^A-Za-z0-9_]+", "_", scrub(name)).strip("_") or "col"
    if s[0].isdigit():
        s = "c_" + s
    if s.lower() in {"key", "entityid", "container"}:
        s = "ev_" + s
    s = s[:80]
    base, n = s, 2
    while s.lower() in used:
        s = f"{base[:76]}_{n}"
        n += 1
    used.add(s.lower())
    return s

def flatten(obj: Any, prefix: str = "") -> dict[str, str]:
    out: dict[str, str] = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}_{k}" if prefix else str(k)
            if isinstance(v, dict):
                out.update(flatten(v, key))
            elif isinstance(v, list):
                if v and all(isinstance(i, (str, int, float, bool)) or i is None for i in v):
                    out[key] = ";".join(scrub(i) for i in v)
                else:
                    out[key] = scrub(v)[:2000]
            else:
                out[key] = scrub(v)
    else:
        out[prefix or "value"] = scrub(obj)
    return out

def infer_type(vals: list[str]) -> str:
    nonempty = [v for v in vals if v != ""]
    if not nonempty:
        return "string"
    if all(re.fullmatch(r"-?\d+", v) for v in nonempty):
        return "int"
    if all(re.fullmatch(r"-?\d+(\.\d+)?([eE][-+]?\d+)?", v) for v in nonempty):
        return "double"
    return "string"

def range_uri(kind: str) -> str:
    return {
        "int": "http://www.w3.org/2001/XMLSchema#int",
        "double": "http://www.w3.org/2001/XMLSchema#double",
    }.get(kind, "http://www.w3.org/2001/XMLSchema#string")

def write_rows(path: str, rows: list[dict[str, str]], max_rows: int) -> tuple[int, list[dict]]:
    if not rows:
        return 0, []
    keys: list[str] = []
    seen: set[str] = set()
    for r in rows:
        for k in r:
            if k not in seen:
                seen.add(k)
                keys.append(k)
    used: set[str] = set()
    headers = [clean_col(k, used) for k in keys]
    samples = {h: [] for h in headers}
    n = 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(headers)
        for r in rows:
            if max_rows and n >= max_rows:
                break
            vals = [r.get(k, "") for k in keys]
            w.writerow(vals)
            if n < 250:
                for h, v in zip(headers, vals):
                    samples[h].append(v)
            n += 1
    fields = []
    for h, orig in zip(headers, keys):
        kind = infer_type(samples[h])
        uniq = len({v for v in samples[h] if v != ""})
        fields.append({"name": h, "label": scrub(orig)[:200], "inferred": kind,
                       "rangeURI": range_uri(kind), "unique_count": uniq, "scale": 4000})
    return n, fields

def load_json(src: str) -> Any:
    with open(src, encoding="utf-8") as fh:
        return json.load(fh)

def proto(data: Any) -> dict:
    if isinstance(data, dict) and "protocolSection" in data:
        return data["protocolSection"]
    if isinstance(data, dict) and isinstance(data.get("studies"), list) and data["studies"]:
        return (data["studies"][0] or {}).get("protocolSection") or {}
    return data if isinstance(data, dict) else {}

def ctg_overview_rows(data: Any) -> list[dict[str, str]]:
    p = proto(data)
    ident = p.get("identificationModule") or {}
    status = p.get("statusModule") or {}
    design = p.get("designModule") or {}
    cond = p.get("conditionsModule") or {}
    desc = p.get("descriptionModule") or {}
    row = {
        "nct_id": ident.get("nctId") or "",
        "brief_title": ident.get("briefTitle") or "",
        "official_title": ident.get("officialTitle") or "",
        "acronym": ident.get("acronym") or "",
        "org": ((ident.get("organization") or {}).get("fullName")) or "",
        "overall_status": status.get("overallStatus") or "",
        "start_date": ((status.get("startDateStruct") or {}).get("date")) or "",
        "primary_completion": ((status.get("primaryCompletionDateStruct") or {}).get("date")) or "",
        "study_type": design.get("studyType") or "",
        "phases": ";".join(design.get("phases") or []),
        "enrollment": str((design.get("enrollmentInfo") or {}).get("count") or ""),
        "allocation": ((design.get("designInfo") or {}).get("allocation")) or "",
        "masking": (((design.get("designInfo") or {}).get("maskingInfo") or {}).get("masking")) or "",
        "conditions": ";".join(cond.get("conditions") or []),
        "brief_summary": (desc.get("briefSummary") or "")[:1500],
    }
    return [ {k: scrub(v) for k, v in row.items()} ]

def ctg_arm_rows(data: Any) -> list[dict[str, str]]:
    arms = ((proto(data).get("armsInterventionsModule") or {}).get("armGroups")) or []
    rows = []
    for a in arms:
        rows.append({
            "label": scrub(a.get("label")),
            "type": scrub(a.get("type")),
            "description": scrub(a.get("description")),
            "interventions": ";".join(scrub(x) for x in (a.get("interventionNames") or [])),
        })
    return rows

def ctg_outcome_rows(data: Any) -> list[dict[str, str]]:
    om = proto(data).get("outcomesModule") or {}
    rows = []
    for kind, key in (("primary", "primaryOutcomes"), ("secondary", "secondaryOutcomes"), ("other", "otherOutcomes")):
        for o in om.get(key) or []:
            rows.append({
                "kind": kind,
                "measure": scrub(o.get("measure")),
                "description": scrub(o.get("description")),
                "time_frame": scrub(o.get("timeFrame")),
            })
    return rows

def ctg_search_rows(data: Any) -> list[dict[str, str]]:
    rows = []
    for st in data.get("studies") or []:
        p = st.get("protocolSection") or {}
        ident = p.get("identificationModule") or {}
        status = p.get("statusModule") or {}
        design = p.get("designModule") or {}
        rows.append({
            "nct_id": scrub(ident.get("nctId")),
            "brief_title": scrub(ident.get("briefTitle")),
            "acronym": scrub(ident.get("acronym")),
            "org": scrub((ident.get("organization") or {}).get("fullName")),
            "status": scrub(status.get("overallStatus")),
            "phases": ";".join(design.get("phases") or []),
            "enrollment": str((design.get("enrollmentInfo") or {}).get("count") or ""),
            "study_type": scrub(design.get("studyType")),
        })
    return rows

def pubmed_rows(src: str) -> list[dict[str, str]]:
    raw = load_json(src)
    ids = ((raw.get("esearchresult") or {}).get("idlist")) or []
    if not ids:
        return []
    url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&retmode=json&id=" + ",".join(ids[:80])
    req = Request(url, headers={"User-Agent": "LabKey-V940-Evidence"})
    try:
        with urlopen(req, timeout=60) as resp:
            summary = json.loads(resp.read().decode("utf-8"))
    except Exception:
        return [{"pmid": i, "title": "", "source": "", "pubdate": "", "authors": "", "doi": "",
                 "pubmed_url": f"https://pubmed.ncbi.nlm.nih.gov/{i}/"} for i in ids[:80]]
    result = (summary.get("result") or {})
    rows = []
    for pid in ids:
        rec = result.get(pid) or {}
        if not rec:
            continue
        rows.append({
            "pmid": pid,
            "title": scrub(rec.get("title")),
            "source": scrub(rec.get("source")),
            "pubdate": scrub(rec.get("pubdate")),
            "authors": ";".join(scrub((a or {}).get("name")) for a in (rec.get("authors") or [])[:12]),
            "doi": next((scrub(x.get("value")) for x in (rec.get("articleids") or []) if x.get("idtype") == "doi"), ""),
            "pubmed_url": f"https://pubmed.ncbi.nlm.nih.gov/{pid}/",
        })
    return rows

def openfda_rows(data: Any) -> list[dict[str, str]]:
    rows = []
    for ev in data.get("results") or []:
        patient = ev.get("patient") or {}
        reactions = ";".join(scrub((r or {}).get("reactionmeddrapt")) for r in (patient.get("reaction") or [])[:8])
        drugs = ";".join(scrub((d or {}).get("medicinalproduct")) for d in (patient.get("drug") or [])[:8])
        rows.append({
            "safetyreportid": scrub(ev.get("safetyreportid")),
            "receive_date": scrub(ev.get("receivedate")),
            "serious": scrub(ev.get("serious")),
            "reactions": reactions,
            "drugs": drugs,
            "patient_sex": scrub((patient.get("patientsex"))),
            "patient_age": scrub(patient.get("patientonsetage")),
        })
    return rows

CURATED_CLAIMS = [
    {"claim_id":"KN942-RFS-LANCET-2024","nct_id":"NCT03897881","endpoint":"RFS","hr":"0.561","hr_low":"0.309","hr_high":"1.017","p_value":"0.053","population":"ITT resected IIIB-IV","cite":"Lancet 2024; PMID see pubmed_intismeran","evidence_class":"phase2b_randomized","note":"Aggregate published HR, not IPD"},
    {"claim_id":"KN942-RFS-3Y","nct_id":"NCT03897881","endpoint":"RFS","hr":"0.510","hr_low":"0.351","hr_high":"0.743","p_value":"","population":"median follow-up ~3y","cite":"JCO OA-25-00008","evidence_class":"phase2b_update","note":"80% CI in source"},
    {"claim_id":"KN942-DMFS-3Y","nct_id":"NCT03897881","endpoint":"DMFS","hr":"0.384","hr_low":"0.227","hr_high":"0.650","p_value":"","population":"median follow-up ~3y","cite":"JCO OA-25-00008","evidence_class":"phase2b_update","note":"80% CI in source"},
    {"claim_id":"KN942-RFS-5Y","nct_id":"NCT03897881","endpoint":"RFS","hr":"0.51","hr_low":"0.294","hr_high":"0.887","p_value":"","population":"5-year update ASCO 2026","cite":"JCO 2026 ahead of print","evidence_class":"phase2b_update","note":"49% risk reduction as reported"},
    {"claim_id":"INTERPATH001-TOPLINE","nct_id":"NCT05933577","endpoint":"RFS_and_DMFS","hr":"","hr_low":"","hr_high":"","p_value":"","population":"resected IIB-IV","cite":"Merck/Moderna press 2026-08-19","evidence_class":"phase3_topline","note":"Endpoints met; numeric HR not in press release"},
]

TRANSLATIONAL_LINKS = [
    {"link_id":"KN603-FIGSHARE-HLA","nct_id":"NCT03313778","title":"KEYNOTE-603 peptide/HLA supplement",
     "url":"https://doi.org/10.1158/2159-8290.27435520","kind":"supplement","format":"figshare",
     "note":"Public metadata/supplement. Not patient FASTA dumps."},
    {"link_id":"KN603-CTGOV","nct_id":"NCT03313778","title":"KEYNOTE-603 registry",
     "url":"https://clinicaltrials.gov/study/NCT03313778","kind":"registry","format":"html",
     "note":"Phase 1 personalized vaccine study."},
    {"link_id":"KN942-CTGOV","nct_id":"NCT03897881","title":"KEYNOTE-942 registry",
     "url":"https://clinicaltrials.gov/study/NCT03897881","kind":"registry","format":"html",
     "note":"Phase 2b adjuvant melanoma."},
    {"link_id":"INTERPATH001-CTGOV","nct_id":"NCT05933577","title":"INTerpath-001 registry",
     "url":"https://clinicaltrials.gov/study/NCT05933577","kind":"registry","format":"html",
     "note":"Phase 3. No IPD on this shelf."},
]

def cmd_prepare() -> None:
    src, dest, fmt, jpath, max_rows = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6])
    filt = sys.argv[7] if len(sys.argv) > 7 else ""
    os.makedirs(dest, exist_ok=True)
    out = os.path.join(dest, "data.csv")
    data = None
    if fmt not in {"catalog_only", "curated", "curated_links", "score"}:
        try:
            data = load_json(src)
        except Exception as exc:
            print(json.dumps({"ok": False, "rows": 0, "error": f"json: {exc}"}))
            return
    rows: list[dict[str, str]] = []
    try:
        if fmt == "ctg_overview":
            rows = ctg_overview_rows(data)
        elif fmt == "ctg_arms":
            rows = ctg_arm_rows(data)
        elif fmt == "ctg_outcomes":
            rows = ctg_outcome_rows(data)
        elif fmt == "ctg_search":
            rows = ctg_search_rows(data)
        elif fmt == "pubmed":
            rows = pubmed_rows(src)
        elif fmt == "openfda":
            rows = openfda_rows(data)
        elif fmt == "curated":
            rows = [{k: scrub(v) for k, v in r.items()} for r in CURATED_CLAIMS]
        elif fmt == "curated_links":
            rows = [{k: scrub(v) for k, v in r.items()} for r in TRANSLATIONAL_LINKS]
        elif fmt == "json_records":
            items = data
            if jpath:
                for part in jpath.split("."):
                    items = (items or {}).get(part) if isinstance(items, dict) else items
            if isinstance(items, list):
                rows = [flatten(x) for x in items]
                if filt:
                    fl = filt.lower()
                    rows = [r for r in rows if fl in " ".join(r.values()).lower()]
            elif isinstance(items, dict):
                rows = [flatten(items)]
    except Exception as exc:
        print(json.dumps({"ok": False, "rows": 0, "error": str(exc)}))
        return
    n, fields = write_rows(out, rows, max_rows)
    schema = {"ok": n > 0, "rows_written": n, "n_columns": len(fields), "fields": fields}
    with open(os.path.join(dest, "schema.json"), "w", encoding="utf-8") as fh:
        json.dump(schema, fh, indent=2)
    print(json.dumps({"ok": n > 0, "rows": n, "csv": out}))

def cmd_score() -> None:
    catalog = json.load(open(sys.argv[2], encoding="utf-8"))
    root = sys.argv[3]
    dest = sys.argv[4]
    rows = []
    for rec in catalog:
        sid = rec["id"]
        schema_path = os.path.join(root, "sources", sid, "prepared", "schema.json")
        csv_path = os.path.join(root, "sources", sid, "prepared", "data.csv")
        n = 0
        cols = 0
        if os.path.isfile(schema_path):
            try:
                sch = json.load(open(schema_path, encoding="utf-8"))
                n = int(sch.get("rows_written") or 0)
                cols = int(sch.get("n_columns") or 0)
            except Exception:
                n = 0
        kind = rec.get("kind") or ""
        fmt = rec.get("format") or ""
        score = 10
        caveats = []
        if fmt == "catalog_only":
            score = 25
            caveats.append("link-only, no table")
        elif n <= 0:
            score = 5
            caveats.append("no rows prepared")
        else:
            score = 30 + min(25, n) + min(15, cols)
            if fmt.startswith("ctg"):
                score += 15
            if fmt == "curated":
                score = 72
                caveats.append("cited aggregates only")
            if kind == "publications":
                score += 10
            if kind == "safety":
                score = min(score, 45)
                caveats.append("spontaneous reports")
            if kind == "biomarker_reference":
                caveats.append("not V940 IPD")
                score = min(score, 60)
        score = max(0, min(100, score))
        grade = "A" if score >= 80 else "B" if score >= 60 else "C" if score >= 40 else "D"
        rows.append({
            "source_id": sid, "name": rec.get("name") or sid, "kind": kind, "format": fmt,
            "rows": str(n), "columns": str(cols), "score": str(score), "grade": grade,
            "usable_in_labkey": "yes" if n > 0 or fmt == "catalog_only" else "no",
            "caveats": "; ".join(caveats) or "ok",
            "homepage": rec.get("homepage") or "",
        })
    n, fields = write_rows(dest, rows, 0)
    schema_dir = os.path.dirname(dest)
    with open(os.path.join(schema_dir, "schema.json"), "w", encoding="utf-8") as fh:
        json.dump({"ok": n > 0, "rows_written": n, "n_columns": len(fields), "fields": fields}, fh, indent=2)
    print(json.dumps({"ok": n > 0, "rows": n}))

def cmd_student_populate() -> None:
    dest = sys.argv[2]
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    extra = [
        {"claim_id": "KN942-RFS-KEYTRUDA-PRESS", "nct_id": "NCT03897881",
         "endpoint": "RFS", "hr": "", "hr_low": "", "hr_high": "", "p_value": "",
         "population": "mid-stage + multi-year RFS updates",
         "cite": "Fierce Biotech / BioPhase Dive (trade press)",
         "evidence_class": "trade_press",
         "note": "Seminar claim. Pointers only until NCT/PMID chain is filled."},
    ]
    rows = []
    for c in CURATED_CLAIMS + extra:
        nct = (c.get("nct_id") or "").strip()
        hr = (c.get("hr") or "").strip()
        klass = c.get("evidence_class") or ""
        cite = c.get("cite") or ""
        cl = cite.lower()
        has_paper = any(x in cl for x in ("pmid", "lancet", "jco", "doi"))
        has_press = any(x in cl for x in ("press", "fierce", "biophase"))
        pmid = ""
        m = re.search(r"PMID\s*[: ]\s*(\d+)", cite, re.I)
        if m:
            pmid = m.group(1)
        if not nct:
            score, grade, reason = 20, "D", "No NCT"
        elif hr and has_paper and klass == "phase2b_randomized":
            score, grade, reason = 90, "A", "Randomized mid-stage HR with journal cite"
        elif hr and has_paper:
            score, grade, reason = 75, "B", "Follow-up HR with journal cite"
        elif hr and nct:
            score, grade, reason = 65, "B", "Registry + numeric HR"
        elif klass == "phase3_topline" or (has_press and not hr):
            score, grade, reason = 48, "C", "Press/topline without numeric HR"
        else:
            score, grade, reason = 30, "D", "Insufficient public numbers"
        hr_rep = hr
        if hr and (c.get("hr_low") or c.get("hr_high")):
            hr_rep = f"{hr} ({c.get('hr_low') or '?'}–{c.get('hr_high') or '?'})"
        rows.append({
            "reviewer": "auto",
            "claim_id": c.get("claim_id") or "",
            "nct_id": nct,
            "pmid": pmid,
            "hr_reported": hr_rep,
            "hr_in_paper": hr if has_paper else "",
            "follow_up": c.get("population") or "",
            "press_url": "",
            "grade": grade,
            "suggested_grade": grade,
            "rubric_score": str(score),
            "rubric_reason": reason,
            "evidence_class": klass,
            "endpoint": c.get("endpoint") or "",
            "notes": c.get("note") or "",
            "date": time.strftime("%Y-%m-%d"),
        })
    n, fields = write_rows(dest, rows, 0)
    schema_dir = os.path.dirname(dest)
    with open(os.path.join(schema_dir, "schema.json"), "w", encoding="utf-8") as fh:
        json.dump({"ok": n > 0, "rows_written": n, "n_columns": len(fields), "fields": fields}, fh, indent=2)
    print(json.dumps({"ok": n > 0, "rows": n}))

def cmd_domain() -> None:
    schema = json.load(open(sys.argv[2], encoding="utf-8"))
    name = scrub(sys.argv[3])[:200]
    desc = scrub(sys.argv[4] if len(sys.argv) > 4 else "")[:400]
    fields = [{"name": "Key", "rangeURI": range_uri("int")}]
    for f in schema.get("fields") or []:
        item = {"name": scrub(f["name"])[:80], "rangeURI": f.get("rangeURI") or range_uri("string"),
                "label": scrub(f.get("label") or f["name"])[:200]}
        if f.get("inferred") == "string":
            item["scale"] = int(f.get("scale") or 4000)
        fields.append(item)
    json.dump({"kind": "IntList", "domainDesign": {"name": name, "description": desc, "fields": fields},
               "options": {"keyName": "Key", "keyType": "AutoIncrementInteger"}}, sys.stdout)

def _lk_type(kind: str) -> str:
    return {"int": "INTEGER", "double": "DOUBLE"}.get(kind, "VARCHAR")

def cmd_chart_plan() -> None:
    schema = json.load(open(sys.argv[2], encoding="utf-8"))
    fields = schema.get("fields") or []
    by = {f["name"].lower(): f for f in fields}
    nums = [f for f in fields if f.get("inferred") in ("int", "double")
            and not str(f.get("name","")).lower().endswith("id")]
    cats = [f for f in fields if f.get("inferred") == "string"
            and 2 <= int(f.get("unique_count") or 0) <= 16
            and not str(f.get("name","")).lower() in {"homepage","cite","note","description","title"}]
    def spec(f):
        return {"name": f["name"], "label": str(f.get("label") or f["name"])[:80], "type": _lk_type(str(f.get("inferred")))}
    plans = []
    if "score" in by and "grade" in by:
        plans.append({"name": "Evidence score by grade", "renderType": "box_plot", "x": spec(by["grade"]), "y": spec(by["score"])})
        plans.append({"name": "Sources by grade", "renderType": "bar_chart", "x": spec(by["grade"])})
    if "hr" in by and "endpoint" in by:
        plans.append({"name": "Published HR by endpoint", "renderType": "box_plot", "x": spec(by["endpoint"]), "y": spec(by["hr"])})
    if "enrollment" in by and "phases" in by:
        plans.append({"name": "Enrollment by phase", "renderType": "box_plot", "x": spec(by["phases"]), "y": spec(by["enrollment"])})
    if "serious" in by:
        plans.append({"name": "OpenFDA serious flag", "renderType": "bar_chart", "x": spec(by["serious"])})
    if not plans and nums and cats:
        plans.append({"name": f"{nums[0]['name']} by {cats[0]['name']}", "renderType": "box_plot",
                      "x": spec(cats[0]), "y": spec(nums[0])})
    if not any(p.get("renderType") == "bar_chart" for p in plans) and cats:
        plans.append({"name": f"Count by {cats[0]['name']}", "renderType": "bar_chart", "x": spec(cats[0])})
    json.dump(plans[:3], sys.stdout)

def cmd_folder_xml() -> None:
    listname, title = sys.argv[2], sys.argv[3]
    dest = sys.argv[4] if len(sys.argv) > 4 else ""
    q = ""
    if listname:
        q = f'''      <webpart>
        <name>Query</name>
        <index>1</index>
        <location>body</location>
        <permanent>false</permanent>
        <properties>
          <property key="title" value="{title}"/>
          <property key="schemaName" value="lists"/>
          <property key="queryName" value="{listname}"/>
        </properties>
      </webpart>
'''
    folder_xml = '''<?xml version="1.0" encoding="UTF-8"?>
<folder xmlns="http://labkey.org/folder/xml">
  <folderType>
    <name>Collaboration</name>
  </folderType>
</folder>
'''
    pages_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<pages xmlns="http://labkey.org/folder/xml">
  <page name="default">
    <webpart>
      <name>Wiki</name>
      <index>0</index>
      <location>body</location>
      <permanent>false</permanent>
      <properties>
        <property key="name" value="home"/>
      </properties>
    </webpart>
{q}    <webpart>
      <name>Data Views</name>
      <index>2</index>
      <location>body</location>
      <permanent>false</permanent>
    </webpart>
    <webpart>
      <name>Files</name>
      <index>3</index>
      <location>body</location>
      <permanent>false</permanent>
    </webpart>
  </page>
</pages>
'''
    if dest:
        os.makedirs(dest, exist_ok=True)
        open(os.path.join(dest, "folder.xml"), "w", encoding="utf-8").write(folder_xml)
        open(os.path.join(dest, "pages.xml"), "w", encoding="utf-8").write(pages_xml)
        print(dest)
    else:
        print(folder_xml)

def cmd_rows() -> None:
    import csv as _csv
    path = sys.argv[2]
    with open(path, encoding="utf-8", newline="") as fh:
        rows = [{k: scrub(v) for k, v in rec.items() if k} for rec in _csv.DictReader(fh)]
    json.dump(rows, sys.stdout)

def cmd_wiki_fields() -> None:
    import re
    html = open("/tmp/v940-wikiedit.html", encoding="utf-8", errors="replace").read()
    fields = {}
    for m in re.finditer(r"<input[^>]+>", html, re.I):
        tag = m.group(0)
        n = re.search(r'name=["\']([^"\']+)["\']', tag, re.I)
        v = re.search(r'value=["\']([^"\']*)["\']', tag, re.I)
        if n:
            fields[n.group(1)] = v.group(1) if v else ""
    for m in re.finditer(
        r'<(?:input|select)[^>]+name=["\']([^"\']+)["\'][^>]*>', html, re.I
    ):
        if m.group(1) not in fields:
            fields[m.group(1)] = ""
    action = ""
    for m in re.finditer(r"<form[^>]*>", html, re.I):
        tag = m.group(0)
        if re.search(r"saveWiki|editWiki|wiki-", tag, re.I):
            a = re.search(r'action=["\']([^"\']+)["\']', tag, re.I)
            if a:
                action = a.group(1)
                break
    if not action:
        a = re.search(r'<form[^>]+action=["\']([^"\']+)["\']', html, re.I)
        action = a.group(1) if a else ""
    entity = (
        fields.get("entityId")
        or fields.get("entityid")
        or fields.get("wiki.entityId")
        or ""
    )
    if not entity:
        m = re.search(
            r'entityId["\s:=]+["\']([0-9a-fA-F-]{36})["\']', html
        )
        entity = m.group(1) if m else ""
    if entity:
        fields["entityId"] = entity
    vers = [int(x) for x in re.findall(r"pageVersionId[^0-9]{0,40}(\d+)", html)]
    if vers:
        fields["pageVersionId"] = str(max(vers))
    fields["name"] = fields.get("name") or "home"
    fields["title"] = sys.argv[2]
    fields["body"] = sys.argv[3]
    fields["rendererType"] = "HTML"
    fields["save"] = "Save"
    if len(sys.argv) > 4 and sys.argv[4]:
        fields["X-LABKEY-CSRF"] = sys.argv[4]
    json.dump(
        {"action": action, "entityId": entity, "fields": fields},
        sys.stdout,
    )

if __name__ == "__main__":
    {"prepare": cmd_prepare, "domain": cmd_domain, "chart_plan": cmd_chart_plan,
     "folder_xml": cmd_folder_xml, "score": cmd_score, "rows": cmd_rows,
     "wiki_fields": cmd_wiki_fields,
     "student_populate": cmd_student_populate}[sys.argv[1]]()
PY
chmod +x "$HELPER"

urlenc() { printf '%s' "$1" | sed 's/ /%20/g'; }
http_code() { printf '%s' "$1" | tr -cd '0-9' | tail -c 3; }
json_get() { python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print(d.get(sys.argv[1]) or "")' "$1"; }

base=""; csrf=""; cookie_jar=""

probe_context() {
  local candidate="$1" body code
  body="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
    "${auth_args[@]}" -H "Accept: application/json" \
    -w '\n%{http_code}' "${candidate}/login-whoAmI.api" 2>/dev/null || true)"
  code="$(printf '%s' "$body" | tail -n 1)"
  body="$(printf '%s' "$body" | sed '$d')"
  if [[ "$code" == "200" ]] && printf '%s' "$body" | grep -qE '"CSRF"'; then
    csrf="$(printf '%s' "$body" | json_get CSRF)"; return 0
  fi
  return 1
}

login_session() {
  local origin="${LK_URL%/}"
  cookie_jar="$(mktemp)"
  trap 'rm -f "$cookie_jar"' EXIT
  auth_args=()
  if [[ -n "$LK_APIKEY" ]]; then auth_args+=(-H "apikey: $LK_APIKEY")
  else auth_args+=(-u "${LK_USER}:${LK_PASSWORD}"); fi
  case "$LK_CONTEXT" in
    auto|AUTO)
      if probe_context "$origin"; then base="$origin"
      elif probe_context "${origin}/labkey"; then base="${origin}/labkey"
      else die "Cannot reach login-whoAmI.api"; fi ;;
    ""|/) base="$origin" ;;
    *) base="${origin}/${LK_CONTEXT#/}"; base="${base%/}" ;;
  esac
  [[ -n "$csrf" ]] || csrf="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
    "${auth_args[@]}" "${base}/login-whoAmI.api" | json_get CSRF || true)"
  log "session on ${base}"
}

lk_post_json() {
  local cpath="$1" action="$2" payload="$3" out="$4" url
  cpath="${cpath#/}"
  url="${base}/${action}"
  [[ -n "$cpath" ]] && url="${base}/$(urlenc "$cpath")/${action}"
  curl "${api_flags[@]}" --max-redirs 0 -X POST \
    -H "Content-Type: application/json" -H "Accept: application/json" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -d "$payload" -o "$out" -w '%{http_code}' "$url" || true
}

ensure_container() {
  local parent="$1" name="$2" payload
  payload="$(printf '{"name":"%s","title":"%s","folderType":"Collaboration","isWorkbook":false}' "$name" "$name")"
  lk_post_json "$parent" "core-createContainer.api" "$payload" "/tmp/v940-create.json" >/dev/null || true
}

wiki_pick() {
  python3 -c '
import json,re,sys
want_title=(sys.argv[1] or "").strip().lower()
want_name=(sys.argv[2] or "home").strip().lower()
raw=""
for path in ("/tmp/v940-wikipages.json","/tmp/v940-getwiki.json"):
    try:
        raw += open(path,encoding="utf-8",errors="replace").read()+"\n"
    except Exception:
        pass
data=None
try:
    data=json.loads(raw.strip().splitlines()[0] if raw.strip() else "{}")
except Exception:
    data=None
pages=[]
def walk(obj):
    if isinstance(obj, dict):
        if obj.get("entityId") or obj.get("name") or obj.get("title"):
            pages.append(obj)
        for v in obj.values():
            walk(v)
    elif isinstance(obj, list):
        for i in obj:
            walk(i)
if data is not None:
    walk(data)
picked=None
for p in pages:
    name=str(p.get("name") or "").lower()
    title=str(p.get("title") or "").lower()
    if name in {want_name, want_title} or title==want_title:
        picked=p
        break
if picked is None:
    for p in pages:
        if str(p.get("name") or "").lower()=="home":
            picked=p
            break
entity=(picked or {}).get("entityId") or (picked or {}).get("entityid") or ""
if not entity:
    m=re.search(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", raw)
    entity=m.group(0) if m else ""
name=(picked or {}).get("name") or "home"
row=(picked or {}).get("rowId") or (picked or {}).get("pageId") or ""
ver=(picked or {}).get("pageVersionId") or (picked or {}).get("version") or ""
if not ver and isinstance(picked, dict):
    wv=(picked.get("wikiVersion") or picked.get("page") or {})
    if isinstance(wv, dict):
        ver=wv.get("pageVersionId") or ver
print("|".join([str(entity), str(name), str(row), str(ver or "")]))
' "$1" "$2"
}

save_wiki() {
  local folder="$1" title="$2" body="$3" page="${4:-home}" http entity
  rm -f /tmp/v940-wikiedit.html /tmp/v940-wikifields.json /tmp/v940-wiki.json
  curl "${api_flags[@]}" --max-redirs 5 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" \
    -o /tmp/v940-wikiedit.html \
    "${base}/$(urlenc "$folder")/wiki-editWiki.view?name=${page}" >/dev/null || true
  python3 "$HELPER" wiki_fields "$title" "$body" "${csrf:-}" \
    > /tmp/v940-wikifields.json 2>/dev/null || true
  entity="$(python3 -c 'import json; print(json.load(open("/tmp/v940-wikifields.json")).get("entityId") or "")' 2>/dev/null || true)"
  rowid="$(python3 -c 'import json; print((json.load(open("/tmp/v940-wikifields.json")).get("fields") or {}).get("rowId") or "")' 2>/dev/null || true)"
  printf '%s' "$body" > /tmp/v940-wikibody.html
  ver="$(python3 -c 'import json; print((json.load(open("/tmp/v940-wikifields.json")).get("fields") or {}).get("pageVersionId") or "")' 2>/dev/null || true)"
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -F "name=${page}" \
    -F "title=${title}" \
    -F "rendererType=HTML" \
    -F "body=</tmp/v940-wikibody.html" \
    -F "save=Save" \
    ${entity:+-F "entityId=${entity}"} \
    ${rowid:+-F "rowId=${rowid}"} \
    ${ver:+-F "pageVersionId=${ver}"} \
    -o /tmp/v940-wiki.json -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/wiki-saveWiki.post" || true)"
  curl "${api_flags[@]}" --max-redirs 5 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" \
    -o /tmp/v940-wikipage.html \
    "${base}/$(urlenc "$folder")/wiki-page.view?name=${page}" >/dev/null || true
  if ! grep -q "Kuratiertes öffentliches" /tmp/v940-wikipage.html 2>/dev/null \
     && grep -qiE "Exercise|Onboarding|Hazard|Cox|Kaplan|Rubric|Registry|claim|pembrolizumab" /tmp/v940-wikipage.html 2>/dev/null; then
    log "  wiki ${page} updated in English entity=${entity:-none} (${title})"
  else
    log "  wiki ${page} HTTP $(http_code "$http") entity=${entity:-none} (${title})"
    log "  wiki error: $(head -c 180 /tmp/v940-wiki.json 2>/dev/null | tr '\n' ' ')"
  fi
}

json_ok() {
  python3 -c '
import json,sys
raw=open(sys.argv[1],encoding="utf-8",errors="replace").read().strip()
if not raw:
    raise SystemExit(1)
try:
    d=json.loads(raw)
except Exception:
    raise SystemExit(2)
if not isinstance(d, dict):
    raise SystemExit(0)
if d.get("success") is False or d.get("exception"):
    raise SystemExit(1)
raise SystemExit(0)
' "$1"
}

list_rowcount() {
  local folder="$1" listname="$2"
  curl "${api_flags[@]}" --max-redirs 0 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" -H "Accept: application/json" \
    -o /tmp/v940-q.json -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/query-getQuery.api?schemaName=lists&query.queryName=${listname}&maxRows=1" \
    >/tmp/v940-q.http || true
  python3 -c '
import json
try:
    d=json.load(open("/tmp/v940-q.json",encoding="utf-8"))
except Exception:
    d={}
print(d.get("rowCount") if d.get("rowCount") is not None else len(d.get("rows") or []))
' 2>/dev/null || echo 0
}

list_exists() {
  local folder="$1" listname="$2"
  curl "${api_flags[@]}" --max-redirs 0 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" -H "Accept: application/json" \
    -o /tmp/v940-q.json -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/query-getQuery.api?schemaName=lists&query.queryName=${listname}&maxRows=1" \
    >/tmp/v940-q.http || true
  [[ "$(http_code "$(cat /tmp/v940-q.http)")" == "200" ]]
}

import_list() {
  local folder="$1" csv="$2" schema="$3" listname="$4" desc="$5" payload http n
  [[ -s "$csv" && -s "$schema" ]] || return 1
  if list_exists "$folder" "$listname" && [[ "$LK_FORCE" -eq 0 ]]; then
    n="$(list_rowcount "$folder" "$listname")"
    log "  list ${listname} exists (rows≈${n})"
    return 0
  fi
  payload="$(python3 "$HELPER" domain "$schema" "$listname" "$desc")"
  http="$(lk_post_json "$folder" "property-createDomain.api" "$payload" "/tmp/v940-domain.json")"
  log "  createDomain HTTP $(http_code "$http")"
  if grep -qiE '"success"[[:space:]]*:[[:space:]]*false' /tmp/v940-domain.json 2>/dev/null; then
    if ! grep -qiE 'already exists|Duplicate' /tmp/v940-domain.json 2>/dev/null; then
      log "  createDomain body: $(head -c 240 /tmp/v940-domain.json | tr '\n' ' ')"
    fi
  fi

  python3 "$HELPER" rows "$csv" > /tmp/v940-rows.json
  payload="$(python3 -c 'import json,sys
rows=json.load(open(sys.argv[1],encoding="utf-8"))
if isinstance(rows, dict):
    rows=rows.get("rows") or []
print(json.dumps({"schemaName":"lists","queryName":sys.argv[2],"rows":rows}))
' /tmp/v940-rows.json "$listname")"
  http="$(lk_post_json "$folder" "query-insertRows.api" "$payload" "/tmp/v940-insert.json")"
  log "  insertRows HTTP $(http_code "$http")"
  if json_ok /tmp/v940-insert.json; then
    log "  imported via insertRows"
    return 0
  fi

  http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
    -H "Accept: application/json" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -F "schemaName=lists" -F "queryName=${listname}" \
    -F "insertOption=INSERT" -F "importIdentity=false" \
    -F "file=@${csv};type=text/csv" \
    -o /tmp/v940-import.json -w '%{http_code}' \
    "${base}/$(urlenc "$folder")/query-import.api" || true)"
  log "  query-import HTTP $(http_code "$http")"
  if json_ok /tmp/v940-import.json; then
    log "  imported via query-import"
    return 0
  fi

  if list_exists "$folder" "$listname"; then
    n="$(list_rowcount "$folder" "$listname")"
    if [[ "${n:-0}" -gt 0 ]]; then
      log "  list ${listname} readable after import (rows≈${n})"
      return 0
    fi
  fi
  log "  import body: $(head -c 280 /tmp/v940-insert.json /tmp/v940-import.json 2>/dev/null | tr '\n' ' ')"
  return 1
}

save_evidence_query() {
  local folder="$1" payload
  payload='{"schemaName":"lists","queryName":"EvidenceEvaluation","metadata":{"tables":{"EvidenceEvaluation":{"tableTitle":"Evidence evaluation"}}},"sql":"SELECT source_id, name, kind, format, rows, columns, score, grade, usable_in_labkey, caveats, homepage\nFROM EV_evidence_score\nWHERE usable_in_labkey = '\''yes'\''\nORDER BY score DESC","description":"Ranked public evidence sources for V940 / KEYNOTE-942"}'
  lk_post_json "$folder" "query-saveQuery.api" "$payload" "/tmp/v940-savequery.json" >/dev/null || true
  if grep -qiE 'exception|"success"[[:space:]]*:[[:space:]]*false' /tmp/v940-savequery.json 2>/dev/null; then
    payload='{"schemaName":"lists","queryName":"EvidenceEvaluation","sql":"SELECT * FROM EV_evidence_score"}'
    lk_post_json "$folder" "query-saveQuery.api" "$payload" "/tmp/v940-savequery.json" >/dev/null || true
  fi
  log "  saved query lists.EvidenceEvaluation (if permitted)"
}

apply_folder_portal() {
  return 0
  local folder="$1" listname="$2" title="$3" wikibody="${4:-}" tmp
  tmp="$(mktemp -d)"
  python3 "$HELPER" folder_xml "$listname" "$title" "$tmp" >/dev/null
  if [[ -n "$wikibody" ]]; then
    python3 -c '
import html,sys,pathlib
title, body, root = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
(root/"wiki").mkdir(exist_ok=True)
(root/"wiki"/"home.html").write_text(body, encoding="utf-8")
esc=html.escape(title)
(root/"wikis.xml").write_text(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    "<wikis xmlns=\"http://labkey.org/wiki/xml\">\n"
    "  <pages><page name=\"home\" title=\"%s\"/></pages>\n"
    "</wikis>\n" % esc, encoding="utf-8")
' "$title" "$wikibody" "$tmp"
  fi
  (
    cd "$tmp"
    zip -q folder.zip folder.xml pages.xml
    [[ -f wikis.xml ]] && zip -q folder.zip wikis.xml wiki/home.html
  )
  curl "${api_flags[@]}" --max-redirs 0 -X POST \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    -F "folderZip=@${tmp}/folder.zip;type=application/zip" \
    -o /tmp/v940-folderimport.json -w '  folder.xml HTTP %{http_code}\n' \
    "${base}/$(urlenc "$folder")/admin-importFolder.post" >&2 || true
  rm -rf "$tmp"
}

upload_csv() {
  local folder="$1" csv="$2"
  [[ -s "$csv" ]] || return 0
  curl "${api_flags[@]}" --max-redirs 0 -X PUT \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    --data-binary @"$csv" \
    -o /tmp/v940-dav.json -w '  webdav PUT HTTP %{http_code}\n' \
    "${base}/_webdav/$(urlenc "$folder")/@files/data.csv" >&2 || true
}

save_one_chart() {
  local folder="$1" listname="$2" planjson="$3" payload http
  payload="$(python3 -c '
import json,sys
plan=json.loads(sys.argv[1]); schemaName=sys.argv[2]; query=sys.argv[3]
def measure(spec):
    if not spec: return None
    return {"name": spec.get("name"), "label": spec.get("label") or spec.get("name"),
            "type": spec.get("type") or "VARCHAR", "schemaName": schemaName, "queryName": query}
measures={}
if plan.get("x"): measures["x"]=measure(plan["x"])
if plan.get("y"): measures["y"]=measure(plan["y"])
render=plan.get("renderType") or "bar_chart"
if render=="box_plot" and (not plan.get("y") or (plan.get("y") or {}).get("type")=="VARCHAR"):
    render="bar_chart"
    measures.pop("y", None)
vis={"chartConfig":{
        "renderType":render,
        "measures":measures,
        "scales":{"x":{"type":"automatic"},"y":{"type":"automatic"}},
        "labels":{"main":plan.get("name") or "Chart",
                  "x":(plan.get("x") or {}).get("label") or "",
                  "y":(plan.get("y") or {}).get("label") or ""},
        "geomOptions":{"binThreshold":6000,"opacity":0.6,"pointSize":5,
                       "pointFillColor":"3366FF","colorPaletteScale":"ColorDiscrete",
                       "chartLayout":"single","showOutliers":True},
        "pointType":"all","width":800,"height":480},
     "queryConfig":{"schemaName":schemaName,"queryName":query,"viewName":None,
                    "maxRows":-1,"requiredVersion":17.1}}
print(json.dumps({"name":plan.get("name") or "Default chart","description":"V940 evidence default view",
    "type":"ReportService.GenericChartReport","schemaName":schemaName,"queryName":query,
    "shared":True,"replace":True,"thumbnailType":"AUTO","json":json.dumps(vis)}))
' "$planjson" "lists" "$listname")"
  for action in visualization-saveVisualization.api visualization-genericChartSave.api; do
    http="$(lk_post_json "$folder" "$action" "$payload" "/tmp/v940-chart.json")"
    if [[ "$(http_code "$http")" == "200" ]] && ! grep -qiE '"success"[[:space:]]*:[[:space:]]*false|exception' /tmp/v940-chart.json 2>/dev/null; then
      log "  saved chart"
      return 0
    fi
  done
  return 0
}

save_default_charts() {
  local folder="$1" listname="$2" schema="$3" plans n i plan
  [[ -s "$schema" ]] || return 0
  plans="$(python3 "$HELPER" chart_plan "$schema" || true)"
  n="$(printf '%s' "$plans" | python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)))
except Exception: print(0)')"
  [[ "$n" -gt 0 ]] || return 0
  for i in $(seq 0 $((n - 1))); do
    plan="$(printf '%s' "$plans" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)[int(sys.argv[1])]))' "$i")"
    save_one_chart "$folder" "$listname" "$plan" || true
  done
}

source_wiki() {
  local name="$1" org="$2" kind="$3" homepage="$4" license="$5" listname="$6" note="$7"
  cat <<EOF
<h2>${name}</h2>
<p><strong>${org}</strong> · ${kind} · ${license}</p>
<p><a href="${homepage}">${homepage}</a></p>
<p>${note}</p>
<p>List: <a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=${listname}">${listname}</a></p>
<h3>How to follow the evidence</h3>
<ol>
<li>Registry record, arms and endpoints in this folder.</li>
<li>Publications in pubmed_intismeran (PMID/DOI).</li>
<li>Translational supplements are links only (no IPD).</li>
<li>cBioPortal melanoma studies as independent biomarker context.</li>
<li>OpenFDA spontaneous reports, not trial adverse events.</li>
</ol>
<p><a href="../project-begin.view">Back to the shelf</a> · <a href="reports-manageViews.view">Data Views</a></p>
EOF
}

project_wiki() {
  cat <<EOF
<h2>V940 Evidence — student onboarding</h2>
<p>This project holds <strong>public</strong> evidence for
intismeran autogene (mRNA-4157 / V940) plus pembrolizumab (Keytruda).
Open the folder <a href="Evidence%20Shelf/project-begin.view"><strong>Evidence Shelf</strong></a>
for the source tables. The icons you see here are those source folders.</p>
<h3>Your exercise</h3>
<p>45–60 minutes. Grade one press sentence against the shelf. Hand in
<strong>one new row</strong> in
<a href="Evidence%20Shelf/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_student_review">EV_student_review</a>
(<code>reviewer</code> = your name). Do not edit <code>auto</code> rows.</p>
<p>Start:
<a href="Evidence%20Shelf/wiki-page.view?name=claim">Exercise brief</a> ·
<a href="Evidence%20Shelf/wiki-page.view?name=hr">Hazard ratio</a> ·
<a href="Evidence%20Shelf/wiki-page.view?name=cox">Cox model</a> ·
<a href="Evidence%20Shelf/wiki-page.view?name=km">Kaplan–Meier</a> ·
<a href="Evidence%20Shelf/wiki-page.view?name=endpoints">Endpoints</a> ·
<a href="Evidence%20Shelf/wiki-page.view?name=rubric">Rubric</a></p>
<p>You will <em>interpret</em> published HRs. You will not refit Cox or KM
(no patient-level follow-up times on this server).</p>
EOF
}

landing_wiki() {
  cat <<EOF
<h2>Onboarding — V940 Evidence Shelf</h2>
<p>You are in the working folder. Subfolders above are one public source each.
This wiki is the exercise brief. Methods pages:
<a href="wiki-page.view?name=hr">HR</a> ·
<a href="wiki-page.view?name=cox">Cox</a> ·
<a href="wiki-page.view?name=km">Kaplan–Meier</a> ·
<a href="wiki-page.view?name=endpoints">Endpoints</a>.</p>
<h3>Your exercise (45–60 min)</h3>
<p>Decide whether public numbers support: <em>KEYNOTE-942 V940 + pembrolizumab
reduced the hazard of recurrence or death vs pembrolizumab alone.</em></p>
<p><strong>Hand-in:</strong>
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_student_review">EV_student_review</a>
→ Insert one row. <code>reviewer</code> = your name. Do not edit <code>auto</code> rows.</p>
<h3>How to follow the evidence</h3>
<ol>
<li><strong>v940_trials</strong> — which studies are publicly registered.</li>
<li><strong>kn942_*</strong> — KEYNOTE-942 (NCT03897881): design, arms, endpoints.</li>
<li><strong>interpath001_*</strong> — Phase 3 INTerpath-001 (NCT05933577).</li>
<li><strong>pubmed_intismeran</strong> — papers with PMID/DOI; HR/KM live in the papers, not as IPD.</li>
<li><strong>translational_links</strong> — Figshare peptide/HLA (KEYNOTE-603) and poster pointers.</li>
<li><strong>cbioportal_melanoma</strong> — public melanoma cohorts (TMB/BRAF context).</li>
<li><strong>openfda_pembrolizumab</strong> — spontaneous reports, separate from trial safety.</li>
</ol>
<p>Query <strong>lists.EvidenceEvaluation</strong> on this landing folder ranks sources by score/grade.
published_claims holds cited aggregate HRs (not IPD). Charts are under Data Views.</p>
<h3>Exercise (students)</h3>
<p><strong>Task (45–60 min):</strong> Decide whether the press sentence about
V940 + Keytruda mid-stage RFS is supported by public evidence on this shelf.
Submit <em>one new row</em> in
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_student_review"><strong>EV_student_review</strong></a>
with your name in <code>reviewer</code>.</p>
<p>Do not edit the six <code>reviewer=auto</code> rows. Those are the answer key
(suggested grades). Your row is the homework.</p>
<ol>
<li><a href="wiki-page.view?name=claim">Read the claim</a></li>
<li><a href="wiki-page.view?name=step-registry">Check the registry</a> (NCT, phase, arms)</li>
<li><a href="wiki-page.view?name=hr">How HR is calculated</a></li>
<li><a href="wiki-page.view?name=step-claims">Copy a published HR</a></li>
<li><a href="wiki-page.view?name=step-papers">Confirm PMID/DOI</a></li>
<li><a href="wiki-page.view?name=step-phase3">Do not mix in Phase 3 topline</a></li>
<li><a href="wiki-page.view?name=step-press">Treat Fierce/BioPhase as pointers only</a></li>
<li><a href="wiki-page.view?name=rubric">Give grade A–D</a> and compare with <code>suggested_grade</code></li>
</ol>
<p>Scored view:
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=StudentReviewScored">StudentReviewScored</a>.</p>
<p>Not included: patient-specific vaccine sequences, trial WES/RNA-seq, USB/SPHN records.</p>
EOF
}

student_wiki_claim() {
  cat <<'EOF'
<h2>Exercise</h2>
<p>Time: 45–60 minutes. Do not change rows where <code>reviewer = auto</code>.</p>
<h3>1. What you hand in</h3>
<p>Open
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_student_review">EV_student_review</a>
→ <strong>Insert</strong>. One row. <code>reviewer</code> = your name.</p>
<h3>2. The sentence you are grading</h3>
<blockquote>
Mid-stage trial data, including extended multi-year recurrence-free survival
updates, provide the foundational clinical context for the platform’s efficacy
when combined with Keytruda. Detailed scientific breakdowns are regularly
archived via medical reporting platforms like Fierce Biotech and BioPhase Dive.
</blockquote>
<p>That is press language. Test this narrower claim instead:</p>
<p><em>In KEYNOTE-942, V940 plus pembrolizumab reduced the hazard of
recurrence or death compared with pembrolizumab alone.</em></p>
<h3>3. Do this in order</h3>
<ol>
<li><a href="wiki-page.view?name=step-registry">Confirm the trial</a> (NCT, phase, arms).</li>
<li><a href="wiki-page.view?name=hr">Read how HR is calculated</a>, then
    <a href="wiki-page.view?name=step-claims">copy one HR</a> from published_claims.</li>
<li><a href="wiki-page.view?name=step-papers">Find a PMID/DOI</a>.</li>
<li><a href="wiki-page.view?name=step-phase3">Keep Phase 3 separate</a>.</li>
<li><a href="wiki-page.view?name=step-press">Use Fierce/BioPhase only as a pointer</a>.</li>
<li><a href="wiki-page.view?name=rubric">Assign A–D</a> and compare with <code>suggested_grade</code>.</li>
</ol>
<h3>4. Your row</h3>
<table>
<tr><th>Column</th><th>Write</th></tr>
<tr><td>reviewer</td><td>Your name</td></tr>
<tr><td>claim_id</td><td>KN942-RFS-KEYTRUDA-PRESS</td></tr>
<tr><td>nct_id</td><td>NCT03897881 if the registry matches</td></tr>
<tr><td>pmid</td><td>From pubmed_intismeran, or blank</td></tr>
<tr><td>hr_reported</td><td>e.g. 0.561 (0.309–1.017)</td></tr>
<tr><td>hr_in_paper</td><td>HR printed in the paper, or blank</td></tr>
<tr><td>follow_up</td><td>Primary vs ~3 year vs 5 year</td></tr>
<tr><td>press_url</td><td>Only if the article cites NCT or PMID</td></tr>
<tr><td>grade</td><td>A, B, C, or D</td></tr>
<tr><td>notes</td><td>supported / partly / not — one sentence</td></tr>
</table>
EOF
}

student_wiki_hr() {
  cat <<'EOF'
<h2>How the hazard ratio (HR) is calculated</h2>
<p>The shelf does <strong>not</strong> recompute HRs. Values in
<code>hr_reported</code> are copied from publications. You only need to
interpret them.</p>
<h3>What HR means</h3>
<p>RFS (recurrence-free survival) is analysed with a Cox model. The
<strong>hazard</strong> is the instantaneous rate of recurrence or death.
The HR is:</p>
<p>HR = hazard(V940 + pembrolizumab) / hazard(pembrolizumab alone)</p>
<ul>
<li>HR = 1 — no difference</li>
<li>HR &lt; 1 — combination has a lower hazard (favourable)</li>
<li>HR &gt; 1 — combination has a higher hazard (unfavourable)</li>
</ul>
<p>Approximate relative risk reduction ≈ (1 − HR) × 100%.
Example: HR 0.561 ≈ 44% lower hazard, not a 44% higher cure rate
and not a 44 percentage-point difference in RFS.</p>
<h3>Confidence interval and p-value</h3>
<p>published_claims stores HR as
<code>hr (hr_low–hr_high)</code>.</p>
<ul>
<li>If the interval contains 1, the result is compatible with no
    difference at that confidence level.</li>
<li>KN942-RFS-LANCET-2024: 0.561 (0.309–1.017), p = 0.053 —
    the 95% CI crosses 1, so the primary analysis is not significant
    at α = 0.05.</li>
<li>Later updates (3-year, 5-year) report other HRs and sometimes
    80% CIs. A narrower CI is not the same as a 95% CI. Do not mix them.</li>
</ul>
<h3>What you cannot do on this shelf</h3>
<p>There is no patient-level time-to-event file. You cannot rebuild
the Cox model, Kaplan–Meier curves, or number-at-risk tables here.
If the paper and published_claims disagree, trust the paper and say so
in <code>notes</code>.</p>
<p>Next: <a href="wiki-page.view?name=cox">Cox proportional hazards</a> ·
<a href="wiki-page.view?name=step-claims">Published claims</a>.</p>
EOF
}

student_wiki_cox() {
  cat <<'EOF'
<h2>Cox proportional hazards</h2>
<p>KEYNOTE-942 RFS/DMFS HRs come from a Cox model, not from a t-test
on percentages at a fixed time.</p>
<h3>Hazard</h3>
<p>If T is time to recurrence or death, the hazard is</p>
<p>h(t) = lim<sub>Δt→0</sub> P(t ≤ T &lt; t+Δt | T ≥ t) / Δt</p>
<p>It is a rate, not a probability. Censored patients (still event-free
at last visit) contribute to the risk set until they leave follow-up.</p>
<h3>Proportional hazards model</h3>
<p>h(t | X) = h<sub>0</sub>(t) · exp(β′X)</p>
<p>For one binary treatment (1 = V940+pembro, 0 = pembro):</p>
<p>HR = exp(β) = h(t | treated) / h(t | control)</p>
<p>h<sub>0</sub>(t) is unspecified (semi-parametric). β is estimated by
maximising the partial likelihood over event times only.</p>
<h3>Assumptions you should name</h3>
<ul>
<li>Proportional hazards: the HR is constant over time. Check in the
    paper (Schoenfeld, log-log plots). If PH fails, a single HR is a
    time-averaged summary, not a full description.</li>
<li>Independent censoring: drop-out is not informative given covariates.</li>
<li>Correct event definition: RFS vs DMFS vs OS — see
    <a href="wiki-page.view?name=endpoints">endpoints</a>.</li>
</ul>
<p>This shelf has no (time, event, arm) rows, so you cannot estimate β.
You only read published exp(β) and its CI.</p>
<p><a href="wiki-page.view?name=km">Kaplan–Meier</a></p>
EOF
}

student_wiki_km() {
  cat <<'EOF'
<h2>Kaplan–Meier survival curves</h2>
<p>Papers plot KM curves for RFS/DMFS. The shelf does not store the
curve coordinates. You still need to know what the figure is.</p>
<h3>Estimator</h3>
<p>Order distinct event times  t<sub>1</sub> &lt; t<sub>2</sub> &lt; … .
At t<sub>j</sub> let d<sub>j</sub> = number of events and
n<sub>j</sub> = number still at risk (not yet failed or censored).</p>
<p>Ŝ(t) = Π<sub>t<sub>j</sub> ≤ t</sub> (1 − d<sub>j</sub>/n<sub>j</sub>)</p>
<p>Ŝ(t) is the estimated probability of still being event-free at time t.
Vertical drops are events; tick marks are censoring.</p>
<h3>What KM is not</h3>
<ul>
<li>Not the same as the Cox HR. KM is a descriptive curve per arm;
    Cox is a model for the ratio of hazards.</li>
<li>A difference in Ŝ at one time (e.g. 3-year RFS 74% vs 56%) is
    <strong>not</strong> 1 − HR. Those percents are a snapshot; the HR
    uses the whole time-to-event history.</li>
<li>Greenwood SEs and log-rank tests (compare curves) live in the paper,
    not in LabKey lists.</li>
</ul>
<h3>Log-rank (idea)</h3>
<p>At each event time, compare observed events on the combination arm
with the number expected if arms shared the same hazard. Summing
(O−E) gives the log-rank statistic. p = 0.053 in the Lancet primary
RFS analysis is this kind of test (or the Cox score/Wald test), not a
chi-square on 2×2 counts.</p>
<p><a href="wiki-page.view?name=endpoints">Endpoints</a></p>
EOF
}

student_wiki_endpoints() {
  cat <<'EOF'
<h2>Endpoints and other quantities</h2>
<table>
<tr><th>Name</th><th>Typical event</th></tr>
<tr><td>RFS</td><td>Recurrence or death (primary in KEYNOTE-942)</td></tr>
<tr><td>DMFS</td><td>Distant metastasis or death</td></tr>
<tr><td>OS</td><td>Death from any cause (often immature in adjuvant melanoma)</td></tr>
</table>
<h3>Do not confuse</h3>
<ul>
<li><strong>HR</strong> — ratio of hazards (Cox).</li>
<li><strong>RR</strong> — risk ratio of two binary proportions.</li>
<li><strong>OR</strong> — odds ratio (logistic). Not used for RFS here.</li>
<li><strong>Absolute difference</strong> — Ŝ<sub>A</sub>(t) − Ŝ<sub>B</sub>(t)
    at one t. A “49% risk reduction” in a press line is usually 1−HR,
    not this difference.</li>
</ul>
<h3>Confidence interval for an HR</h3>
<p>If se is the standard error of β̂, a 95% CI for the HR is</p>
<p>exp( β̂ ± 1.96 · se )</p>
<p>An 80% CI uses 1.28 instead of 1.96 and is narrower. Mixing 80% and
95% intervals is a common error when reading 3-year updates.</p>
<h3>Why LabKey cannot redo the calculus</h3>
<p>Need per-patient: arm, event indicator, time, strata. Those IPD are
not public. published_claims is a citation table only.</p>
<p>Back: <a href="wiki-page.view?name=claim">exercise</a> ·
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_student_review">EV_student_review</a></p>
EOF
}

student_wiki_registry() {
  cat <<'EOF'
<h2>Step 1 — Registry</h2>
<p>Confirm phase, population, arms, and endpoints. Do not use press language yet.</p>
<ul>
<li><a href="v940_trials/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_v940_trials">EV_v940_trials</a></li>
<li><a href="kn942_overview/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_kn942_overview">EV_kn942_overview</a> (NCT03897881)</li>
<li><a href="kn942_arms/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_kn942_arms">EV_kn942_arms</a></li>
<li><a href="kn942_outcomes/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_kn942_outcomes">EV_kn942_outcomes</a></li>
</ul>
<p>Write NCT, phase, and whether the control is pembrolizumab monotherapy into
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_student_review">EV_student_review</a>.</p>
<p>Next: <a href="wiki-page.view?name=step-claims">Published claims</a>.</p>
EOF
}

student_wiki_claims() {
  cat <<'EOF'
<h2>Step 2 — Published endpoint claims</h2>
<p>Copy the cited aggregate HR, CI, p-value, population, and citation.
These are not IPD.</p>
<p><a href="published_claims/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_published_claims">EV_published_claims</a></p>
<p>If a row has no HR, the claim is incomplete. Record
<code>hr_reported</code> in EV_student_review.</p>
<p>Next: <a href="wiki-page.view?name=step-papers">Papers</a>.</p>
EOF
}

student_wiki_papers() {
  cat <<'EOF'
<h2>Step 3 — Papers (PMID / DOI)</h2>
<p>Open the primary paper from
<a href="pubmed_intismeran/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_pubmed_intismeran">EV_pubmed_intismeran</a>.
Check that the HR and follow-up time match published_claims.</p>
<p>Write <code>pmid</code>, <code>hr_in_paper</code>, and <code>follow_up</code>
into EV_student_review.</p>
<p>Next: <a href="wiki-page.view?name=step-phase3">Phase 3</a>.</p>
EOF
}

student_wiki_phase3() {
  cat <<'EOF'
<h2>Step 4 — Phase 3</h2>
<p>INTerpath-001 (NCT05933577) is a different evidence class from KEYNOTE-942.</p>
<ul>
<li><a href="interpath001_overview/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_interpath001_overview">overview</a></li>
<li><a href="interpath001_arms/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_interpath001_arms">arms</a></li>
<li><a href="interpath001_outcomes/query-executeQuery.view?schemaName=lists&amp;query.queryName=EV_interpath001_outcomes">outcomes</a></li>
</ul>
<p>A topline “endpoints met” without a numeric HR is press, not a published KM/HR.
Do not mix Phase 2b HRs with Phase 3 status.</p>
<p>Next: <a href="wiki-page.view?name=step-press">Trade press</a>.</p>
EOF
}

student_wiki_press() {
  cat <<'EOF'
<h2>Step 5 — Trade press</h2>
<p>Fierce Biotech and BioPhase Dive are <strong>not</strong> imported as evidence
tables. Use them only as pointers.</p>
<p>Required chain: article URL → NCT or PMID/DOI → a row already on this shelf.
No chain = do not use the article as evidence.</p>
<p>Optional fields in EV_student_review: <code>press_url</code>.</p>
<p>Do not confuse OpenFDA spontaneous reports with trial adverse events
(<a href="openfda_pembrolizumab/project-begin.view">openfda_pembrolizumab</a>).</p>
<p>Next: <a href="wiki-page.view?name=rubric">Rubric</a>.</p>
EOF
}

student_wiki_rubric() {
  cat <<'EOF'
<h2>Rubric</h2>
<p>Grade the <em>claim</em>, not the vaccine. EvidenceEvaluation grades
<em>sources</em>. <strong>suggested_grade</strong> / <strong>rubric_score</strong>
are filled automatically when the list is populated.</p>
<table>
<tr><th>Grade</th><th>Score</th><th>Meaning</th></tr>
<tr><td>A</td><td>80–100</td><td>Randomized mid-stage HR + journal cite + NCT.</td></tr>
<tr><td>B</td><td>60–79</td><td>Registry + numeric HR (update or no full paper).</td></tr>
<tr><td>C</td><td>40–59</td><td>Press / topline only (Fierce, BioPhase, company release).</td></tr>
<tr><td>D</td><td>0–39</td><td>No NCT and no DOI/PMID.</td></tr>
</table>
<p>Auto rows use reviewer=<code>auto</code>. Add your own row (reviewer = your name)
and set <code>grade</code> if you disagree with <code>suggested_grade</code>.</p>
<p>Query
<a href="query-executeQuery.view?schemaName=lists&amp;query.queryName=StudentReviewScored">StudentReviewScored</a>
sorts by rubric_score.</p>
<p><a href="project-begin.view">Back to the shelf</a></p>
EOF
}

write_student_review_files() {
  local dir="$DATA_DIR/sources/student_review/prepared"
  mkdir -p "$dir"
  python3 "$HELPER" student_populate "$dir/data.csv"
}

delete_list() {
  local folder="$1" listname="$2"
  lk_post_json "$folder" "list-deleteListDefinition.api" \
    "$(printf '{"name":"%s","listName":"%s"}' "$listname" "$listname")" \
    "/tmp/v940-dellist.json" >/dev/null || true
  lk_post_json "$folder" "property-deleteDomain.api" \
    "$(printf '{"schemaName":"lists","queryName":"%s","domainKind":"IntList"}' "$listname")" \
    "/tmp/v940-deldom.json" >/dev/null || true
}

save_student_query() {
  local folder="$1" payload http
  payload='{"schemaName":"lists","queryName":"StudentReviewScored","sql":"SELECT reviewer, claim_id, nct_id, pmid, hr_reported, hr_in_paper, follow_up, grade, suggested_grade, rubric_score, rubric_reason, evidence_class, endpoint, notes, date FROM EV_student_review","description":"Student review with rubric columns"}'
  http="$(lk_post_json "$folder" "query-saveQuery.api" "$payload" "/tmp/v940-savequery.json")"
  if grep -qiE 'exception|"success"[[:space:]]*:[[:space:]]*false' /tmp/v940-savequery.json 2>/dev/null; then
    log "  saveQuery retry: $(head -c 160 /tmp/v940-savequery.json | tr '\n' ' ')"
    payload='{"schemaName":"lists","queryName":"StudentReviewScored","sql":"SELECT * FROM EV_student_review"}'
    http="$(lk_post_json "$folder" "query-saveQuery.api" "$payload" "/tmp/v940-savequery.json")"
  fi
  log "  StudentReviewScored HTTP $(http_code "$http") $(head -c 120 /tmp/v940-savequery.json 2>/dev/null | tr '\n' ' ')"
}

bind_wiki_home() {
  local folder="$1" wid payload
  curl "${api_flags[@]}" --max-redirs 0 "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" -H "Accept: application/json" \
    -o /tmp/v940-portal.json \
    "${base}/$(urlenc "$folder")/project-getPortal.api" >/dev/null || true
  wid="$(python3 -c '
import json
try:
    d=json.load(open("/tmp/v940-portal.json",encoding="utf-8"))
except Exception:
    d={}
parts=d.get("webparts") or d.get("parts") or []
if isinstance(parts, dict):
    parts=parts.get("webparts") or parts.get("body") or []
for p in parts if isinstance(parts, list) else []:
    if isinstance(p, dict) and "wiki" in str(p.get("name") or p.get("webPartName") or "").lower():
        print(p.get("webPartId") or p.get("id") or "")
        break
' 2>/dev/null || true)"
  [[ -n "$wid" ]] || return 0
  payload="$(printf '{"webPartId":%s,"properties":{"name":"home"}}' "$wid")"
  lk_post_json "$folder" "project-updateWebPart.api" "$payload" "/tmp/v940-wp.json" >/dev/null || true
  log "  wiki web part bound to home (${wid})"
}

setup_student_path() {
  local folder="${LK_PROJECT}/${LK_FOLDER}"
  write_student_review_files
  if list_exists "$folder" "EV_student_review"; then
    delete_list "$folder" "EV_student_review"
  fi
  LK_FORCE=1 import_list "$folder" \
    "$DATA_DIR/sources/student_review/prepared/data.csv" \
    "$DATA_DIR/sources/student_review/prepared/schema.json" \
    "EV_student_review" "Student review" || true
  if list_exists "$folder" "StudentReviewScored"; then
    delete_list "$folder" "StudentReviewScored"
  fi
  LK_FORCE=1 import_list "$folder" \
    "$DATA_DIR/sources/student_review/prepared/data.csv" \
    "$DATA_DIR/sources/student_review/prepared/schema.json" \
    "StudentReviewScored" "Student review scored" || true
  save_student_query "$folder" || true
  save_default_charts "$folder" "EV_student_review" \
    "$DATA_DIR/sources/student_review/prepared/schema.json" || true
  save_wiki "$folder" "The claim to test" "$(student_wiki_claim)" "claim" || true
  save_wiki "$folder" "How HR is calculated" "$(student_wiki_hr)" "hr" || true
  save_wiki "$folder" "Cox proportional hazards" "$(student_wiki_cox)" "cox" || true
  save_wiki "$folder" "Kaplan-Meier survival curves" "$(student_wiki_km)" "km" || true
  save_wiki "$folder" "Endpoints and other quantities" "$(student_wiki_endpoints)" "endpoints" || true
  save_wiki "$folder" "Step 1 — Registry" "$(student_wiki_registry)" "step-registry" || true
  save_wiki "$folder" "Step 2 — Published claims" "$(student_wiki_claims)" "step-claims" || true
  save_wiki "$folder" "Step 3 — Papers" "$(student_wiki_papers)" "step-papers" || true
  save_wiki "$folder" "Step 4 — Phase 3" "$(student_wiki_phase3)" "step-phase3" || true
  save_wiki "$folder" "Step 5 — Trade press" "$(student_wiki_press)" "step-press" || true
  save_wiki "$folder" "Rubric A–D" "$(student_wiki_rubric)" "rubric" || true
  bind_wiki_home "$folder" || true
  save_wiki "${LK_PROJECT}" "V940 Evidence" "$(project_wiki)" "home" || true
  bind_wiki_home "${LK_PROJECT}" || true
  log "  student review path ready (auto-populated list + rubric scores)"
}

setup_source_portal() {
  local folder="$1" work="$2" name="$3" listname="$4"
  local org kind homepage license note body
  org="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("org",""))' "$work/metadata.json")"
  kind="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("kind",""))' "$work/metadata.json")"
  homepage="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("homepage",""))' "$work/metadata.json")"
  license="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("license",""))' "$work/metadata.json")"
  note="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("note") or "")' "$work/metadata.json")"
  body="$(source_wiki "$name" "$org" "$kind" "$homepage" "$license" "$listname" "$note")"
  apply_folder_portal "$folder" "$listname" "$name" "$body" || true
  save_wiki "$folder" "$name" "$body"
  printf '%s\n' "$body" > /tmp/v940-readme.html
  curl "${api_flags[@]}" --max-redirs 0 -X PUT \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" "${auth_args[@]}" \
    --data-binary @/tmp/v940-readme.html \
    -o /tmp/v940-dav-readme.json \
    "${base}/_webdav/$(urlenc "$folder")/@files/README.html" >/dev/null || true
  upload_csv "$folder" "$work/prepared/data.csv" || true
  save_default_charts "$folder" "$listname" "$work/prepared/schema.json" || true
}

download_source() {
  local url="$1" dest="$2" http
  if [[ -s "$dest" && "$LK_FORCE" -eq 0 ]]; then
    log "  cached"; return 0
  fi
  log "  GET $url"
  http="$(curl "${curl_flags[@]}" --max-time 90 --max-filesize "$LK_MAX_BYTES" \
    -o "$dest.part" -w '%{http_code}' "$url" || true)"
  http="$(http_code "$http")"
  if [[ "$http" != "200" || ! -s "$dest.part" ]]; then
    warn "download HTTP ${http:-000} for $url"
    rm -f "$dest.part"
    return 1
  fi
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$dest.part" 2>/dev/null; then
    warn "payload is not JSON: $url"
    rm -f "$dest.part"
    return 1
  fi
  mv "$dest.part" "$dest"
}

process_one() {
  local id="$1" rec name fmt url jpath filt work dest listname prep_json
  rec="$(python3 -c 'import json,sys
for r in json.load(open(sys.argv[1])):
    if r["id"]==sys.argv[2]:
        json.dump(r,sys.stdout); break
' "$CATALOG" "$id")"
  [[ -n "$rec" ]] || return 0
  name="$(printf '%s' "$rec" | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')"
  fmt="$(printf '%s' "$rec" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("format",""))')"
  url="$(printf '%s' "$rec" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url",""))')"
  jpath="$(printf '%s' "$rec" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("json_path") or "")')"
  filt="$(printf '%s' "$rec" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("filter_text") or "")')"
  work="$DATA_DIR/sources/${id}"
  mkdir -p "$work/raw" "$work/prepared"
  printf '%s\n' "$rec" > "$work/metadata.json"
  dest="${LK_PROJECT}/${LK_FOLDER}/${id}"
  listname="$(python3 -c 'import re,sys; print("EV_"+re.sub(r"[^A-Za-z0-9_]+","_",sys.argv[1])[:40])' "$id")"
  log "Source ${id} — ${name}"

  if [[ "$LK_DRY_RUN" -eq 1 ]]; then
    printf 'dry-run\t%s\t%s\n' "$id" "$name"; return 0
  fi
  if [[ "$LK_LANDING_ONLY" -eq 1 ]]; then
    ensure_container "/${LK_PROJECT}/${LK_FOLDER}" "$id" || true
    setup_source_portal "$dest" "$work" "$name" "$listname" || true
    printf 'landing\t%s\t%s\n' "$id" "$name"; return 0
  fi
  if [[ "$fmt" == "catalog_only" ]]; then
    if [[ "$LK_IMPORT" -eq 1 ]]; then
      ensure_container "/${LK_PROJECT}/${LK_FOLDER}" "$id" || true
      setup_source_portal "$dest" "$work" "$name" "$listname" || true
    fi
    printf 'skip\t%s\t%s\tcatalog-only\n' "$id" "$name"; return 0
  fi
  if [[ "$fmt" != "curated" && "$fmt" != "curated_links" ]]; then
    if [[ -z "$url" ]]; then
      warn "no url for ${id}"
      printf 'fail\t%s\t%s\tno-url\n' "$id" "$name" | tee -a "$FAILED"; return 0
    fi
    if ! download_source "$url" "$work/raw/payload"; then
      printf 'fail\t%s\t%s\tdownload\n' "$id" "$name" | tee -a "$FAILED"; return 0
    fi
  else
    printf '%s\n' '{}' > "$work/raw/payload"
  fi
  prep_json="$(python3 "$HELPER" prepare "$work/raw/payload" "$work/prepared" "$fmt" "$jpath" "$LK_MAX_ROWS" "$filt" || true)"
  if ! printf '%s' "$prep_json" | grep -q '"ok": true'; then
    warn "prepare failed ${id}: $prep_json"
    printf 'fail\t%s\t%s\tprepare\n' "$id" "$name" | tee -a "$FAILED"; return 0
  fi
  log "  prepared $prep_json"
  if [[ "$LK_IMPORT" -eq 1 ]]; then
    ensure_container "/${LK_PROJECT}/${LK_FOLDER}" "$id" || true
    if import_list "$dest" "$work/prepared/data.csv" "$work/prepared/schema.json" "$listname" "$name"; then
      setup_source_portal "$dest" "$work" "$name" "$listname" || true
      printf 'ok\t%s\t%s\n' "$id" "$name"
    else
      warn "import failed ${id}"
      printf 'fail\t%s\t%s\timport\n' "$id" "$name" | tee -a "$FAILED"
    fi
    return 0
  fi
  printf 'ok\t%s\t%s\n' "$id" "$name"
}

: > "$FAILED"
printf 'status\tid\tname\n' > "$MANIFEST"
mapfile -t ALL_IDS < <(python3 -c 'import json,sys
ids=[x for x in sys.argv[1].split(",") if x]
search=(sys.argv[2] or "").lower()
for r in json.load(open(sys.argv[3])):
    if ids and r["id"] not in ids: continue
    blob=" ".join([r["id"], r["name"], r.get("kind","")]).lower()
    if search and search not in blob: continue
    print(r["id"])
' "$LK_IDS" "$LK_SEARCH" "$CATALOG")

if [[ "$LK_IMPORT" -eq 1 ]]; then
  [[ -n "$LK_APIKEY" || ( -n "$LK_USER" && -n "$LK_PASSWORD" ) ]] || die "--import needs credentials"
  login_session
  ensure_container "/" "$LK_PROJECT"
  ensure_container "/$LK_PROJECT" "$LK_FOLDER"
  apply_folder_portal "${LK_PROJECT}/${LK_FOLDER}" "" "Evidence Shelf" "$(landing_wiki)" || true
  save_wiki "${LK_PROJECT}/${LK_FOLDER}" "Evidence Shelf" "$(landing_wiki)"
fi

processed=0
for id in "${ALL_IDS[@]}"; do
  [[ -n "$id" ]] || continue
  if [[ "$LK_LIMIT" -gt 0 && "$processed" -ge "$LK_LIMIT" ]]; then break; fi
  process_one "$id" >> "$MANIFEST" || true
  processed=$((processed + 1))
done
# Evidence-evaluation table + LabKey query/charts on the landing folder
if [[ "$LK_DRY_RUN" -eq 0 ]]; then
  mkdir -p "$DATA_DIR/sources/evidence_score/prepared"
  if python3 "$HELPER" score "$CATALOG" "$DATA_DIR" "$DATA_DIR/sources/evidence_score/prepared/data.csv"; then
    python3 -c 'import json; json.dump({"id":"evidence_score","name":"Evidence score","org":"OSM rubric","kind":"evidence","homepage":"","license":"internal","note":"Computed completeness grade, not clinical efficacy."}, open("'"$DATA_DIR"'/sources/evidence_score/metadata.json","w"))'
    if [[ "$LK_IMPORT" -eq 1 ]]; then
      ensure_container "/${LK_PROJECT}/${LK_FOLDER}" "evidence_score" || true
      if import_list "${LK_PROJECT}/${LK_FOLDER}/evidence_score" \
          "$DATA_DIR/sources/evidence_score/prepared/data.csv" \
          "$DATA_DIR/sources/evidence_score/prepared/schema.json" \
          "EV_evidence_score" "Evidence score"; then
        # same list on landing so EvidenceEvaluation query has a target
        import_list "${LK_PROJECT}/${LK_FOLDER}" \
          "$DATA_DIR/sources/evidence_score/prepared/data.csv" \
          "$DATA_DIR/sources/evidence_score/prepared/schema.json" \
          "EV_evidence_score" "Evidence score" || true
        setup_source_portal "${LK_PROJECT}/${LK_FOLDER}/evidence_score" \
          "$DATA_DIR/sources/evidence_score" "Evidence score" "EV_evidence_score" || true
        save_default_charts "${LK_PROJECT}/${LK_FOLDER}/evidence_score" "EV_evidence_score" \
          "$DATA_DIR/sources/evidence_score/prepared/schema.json" || true
        save_default_charts "${LK_PROJECT}/${LK_FOLDER}" "EV_evidence_score" \
          "$DATA_DIR/sources/evidence_score/prepared/schema.json" || true
        save_evidence_query "${LK_PROJECT}/${LK_FOLDER}" || true
        save_evidence_query "${LK_PROJECT}/${LK_FOLDER}/evidence_score" || true
        apply_folder_portal "${LK_PROJECT}/${LK_FOLDER}" "EV_evidence_score" "Evidence evaluation" "$(landing_wiki)" || true
        save_wiki "${LK_PROJECT}/${LK_FOLDER}" "Evidence Shelf" "$(landing_wiki)" || true
        setup_student_path || true
        printf 'ok\tevidence_score\tEvidence score\n' >> "$MANIFEST"
      else
        warn "could not import evidence_score"
      fi
    fi
  else
    warn "evidence score compute failed"
  fi
fi

if [[ "$LK_IMPORT" -eq 1 ]]; then
  setup_student_path || true
fi
log "Processed ${processed}. Failures=${FAIL_COUNT}. Manifest $MANIFEST"
if [[ "$LK_IMPORT" -eq 1 ]]; then
  log "Open ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/project-begin.view"
  log "Query: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/query-executeQuery.view?schemaName=lists&query.queryName=EvidenceEvaluation"
  log "Review: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/wiki-page.view?name=claim"
  log "List: ${base}/$(urlenc "${LK_PROJECT}/${LK_FOLDER}")/query-executeQuery.view?schemaName=lists&query.queryName=EV_student_review"
fi
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  log "Some sources failed — see $FAILED"
  exit 2
fi
