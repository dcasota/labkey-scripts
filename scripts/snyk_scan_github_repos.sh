#!/bin/bash
#
# Photon OS helper: discover UniBasel core-facility & related GitHub/GitLab
# repositories, clone them, and run "snyk code test".
#
# Prerequisites (Photon OS):
#   tdnf install -y git
#   Snyk CLI on PATH (npm i -g snyk, or official binary)
#   export SNYK_TOKEN='...'          # Snyk authentication
#   export GITHUB_TOKEN='...'        # optional; raises GitHub API rate limit
#   export GITLAB_TOKEN='...'        # optional; private GitLab projects
#
# Usage:
#   chmod +x snyk_scan_github_repos.sh
#   ./snyk_scan_github_repos.sh [csv_path] [work_dir]
#
#   # Discover only (write CSV, no clone/scan):
#   ./snyk_scan_github_repos.sh --discover-only [csv_path]
#
# Defaults:
#   csv_path = ./unibas_core_facility_repos.csv
#   work_dir = ./cloned_repos
#
# Sources scanned:
#   - Optional seed CSV (argument 1, if present)
#   - GitHub orgs: scicore-unibas-ch, RISE-UNIBAS, dhlab-basel,
#     unibas-medfak, unibas-dmi-hpc, unibas-gravis, MMunibas,
#     bmda-unibas, dbisUnibas, its-unibas
#   - GitLab group: https://gitlab.com/ceda-unibas (all subgroups)
#   - Built-in fallback lists when APIs are rate-limited
#

set -uo pipefail

DISCOVER_ONLY=0
CSV_FILE=""
WORK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --discover-only) DISCOVER_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,35p' "$0"
      exit 0
      ;;
    *)
      if [[ -z "$CSV_FILE" ]]; then
        CSV_FILE="$1"
      elif [[ -z "$WORK_DIR" ]]; then
        WORK_DIR="$1"
      fi
      shift
      ;;
  esac
done

CSV_FILE="${CSV_FILE:-./unibas_core_facility_repos.csv}"
WORK_DIR="${WORK_DIR:-./cloned_repos}"
LOG_FILE="${WORK_DIR}/snyk_scan.log"
SUMMARY_FILE="${WORK_DIR}/snyk_scan_summary.csv"
DISCOVERED_CSV="${WORK_DIR}/discovered_repos.csv"

GITHUB_ORGS=(
  scicore-unibas-ch
  RISE-UNIBAS
  dhlab-basel
  unibas-medfak
  unibas-dmi-hpc
  unibas-gravis
  MMunibas
  bmda-unibas
  dbisUnibas
  its-unibas
)

GITLAB_GROUPS=(
  ceda-unibas
)

die() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

need_cmd git
need_cmd curl
need_cmd python3
if [[ "$DISCOVER_ONLY" -eq 0 ]]; then
  need_cmd snyk
fi

if [[ -z "${SNYK_TOKEN:-}" && "$DISCOVER_ONLY" -eq 0 ]]; then
  echo "WARNING: SNYK_TOKEN is not set. Snyk may fail or be rate-limited." >&2
fi

mkdir -p "$WORK_DIR"
: > "$LOG_FILE"

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Discovery: GitHub org repos (public; GITHUB_TOKEN optional)
# ---------------------------------------------------------------------------
discover_github_org() {
  local org="$1" page=1 out n auth=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  while true; do
    out="$(curl -fsS "${auth[@]}" \
      -H "Accept: application/vnd.github+json" \
      -H "User-Agent: unibas-snyk-scan" \
      "https://api.github.com/orgs/${org}/repos?per_page=100&page=${page}&type=public" 2>/dev/null || true)"
    if [[ -z "$out" ]]; then
      log "WARN: empty GitHub response for org ${org} page ${page}"
      break
    fi
    n="$(printf '%s' "$out" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print(-1); sys.exit(0)
if isinstance(d, dict) and d.get("message"):
    print(-1)
elif isinstance(d, list):
    print(len(d))
else:
    print(0)
')"
    if [[ "$n" == "-1" ]]; then
      log "WARN: GitHub API error for ${org}: $(printf '%s' "$out" | head -c 160)"
      break
    fi
    [[ "$n" == "0" ]] && break
    printf '%s' "$out" | python3 -c '
import json,sys
for r in json.load(sys.stdin):
    if not isinstance(r, dict):
        continue
    org = (r.get("owner") or {}).get("login") or ""
    name = r.get("name") or ""
    url = r.get("clone_url") or r.get("html_url") or ""
    if org and name and url:
        print(f"{org},{name},{url},github")
'
    [[ "$n" -lt 100 ]] && break
    page=$((page + 1))
  done
}

# ---------------------------------------------------------------------------
# Discovery: GitLab group projects (include subgroups)
# ---------------------------------------------------------------------------
discover_gitlab_group() {
  local group="$1" page=1 out n auth=()
  if [[ -n "${GITLAB_TOKEN:-}" ]]; then
    auth=(-H "PRIVATE-TOKEN: ${GITLAB_TOKEN}")
  fi
  while true; do
    out="$(curl -fsS "${auth[@]}" \
      -H "User-Agent: unibas-snyk-scan" \
      "https://gitlab.com/api/v4/groups/$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1],safe=""))' "$group")/projects?include_subgroups=true&per_page=100&page=${page}&simple=true" 2>/dev/null || true)"
    if [[ -z "$out" ]]; then
      log "WARN: empty GitLab response for group ${group} page ${page}"
      break
    fi
    n="$(printf '%s' "$out" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print(-1); sys.exit(0)
if isinstance(d, dict) and d.get("message"):
    print(-1)
elif isinstance(d, list):
    print(len(d))
else:
    print(0)
')"
    if [[ "$n" == "-1" ]]; then
      log "WARN: GitLab API error for ${group}: $(printf '%s' "$out" | head -c 160)"
      break
    fi
    [[ "$n" == "0" ]] && break
    printf '%s' "$out" | python3 -c '
import json,sys
for p in json.load(sys.stdin):
    if not isinstance(p, dict):
        continue
    path = p.get("path_with_namespace") or ""
    if "/" not in path:
        continue
    org, name = path.split("/", 1)
    # keep nested path as repository name (tools/foo)
    name = path.split("/", 1)[1]
    org = path.split("/", 1)[0]
    url = p.get("http_url_to_repo") or p.get("web_url") or ""
    if org and name and url:
        print(f"{org},{name},{url},gitlab")
'
    [[ "$n" -lt 100 ]] && break
    page=$((page + 1))
  done
}

# ---------------------------------------------------------------------------
# Fallback lists when APIs fail (from curated UniBas core-facility inventory)
# ---------------------------------------------------------------------------
fallback_rows() {
  cat <<'FALLBACK'
scicore-unibas-ch,ansible-modules-guacamole,https://github.com/scicore-unibas-ch/ansible-modules-guacamole.git,github
scicore-unibas-ch,gpfs-sge-metrics,https://github.com/scicore-unibas-ch/gpfs-sge-metrics.git,github
scicore-unibas-ch,singularity-slides,https://github.com/scicore-unibas-ch/singularity-slides.git,github
scicore-unibas-ch,ansible-role-slurm,https://github.com/scicore-unibas-ch/ansible-role-slurm.git,github
scicore-unibas-ch,scicore-courses-cloud,https://github.com/scicore-unibas-ch/scicore-courses-cloud.git,github
scicore-unibas-ch,ansible-i2b2-scicore,https://github.com/scicore-unibas-ch/ansible-i2b2-scicore.git,github
scicore-unibas-ch,terraform-provider-apisix,https://github.com/scicore-unibas-ch/terraform-provider-apisix.git,github
scicore-unibas-ch,ansible-role-benji-backup,https://github.com/scicore-unibas-ch/ansible-role-benji-backup.git,github
scicore-unibas-ch,ansible-role-biomedit-transfers-tool,https://github.com/scicore-unibas-ch/ansible-role-biomedit-transfers-tool.git,github
scicore-unibas-ch,data-engineer-assignment,https://github.com/scicore-unibas-ch/data-engineer-assignment.git,github
scicore-unibas-ch,sc_rstudio,https://github.com/scicore-unibas-ch/sc_rstudio.git,github
scicore-unibas-ch,ansible-role-docker,https://github.com/scicore-unibas-ch/ansible-role-docker.git,github
scicore-unibas-ch,singularity-container-freesurfer,https://github.com/scicore-unibas-ch/singularity-container-freesurfer.git,github
scicore-unibas-ch,NNHatSolver,https://github.com/scicore-unibas-ch/NNHatSolver.git,github
scicore-unibas-ch,dlcm-offline-page,https://github.com/scicore-unibas-ch/dlcm-offline-page.git,github
scicore-unibas-ch,easybuild-lmod-tutorial,https://github.com/scicore-unibas-ch/easybuild-lmod-tutorial.git,github
RISE-UNIBAS,humanities_data_benchmark,https://github.com/RISE-UNIBAS/humanities_data_benchmark.git,github
RISE-UNIBAS,transkribus-custom-ner-de,https://github.com/RISE-UNIBAS/transkribus-custom-ner-de.git,github
RISE-UNIBAS,clean-code,https://github.com/RISE-UNIBAS/clean-code.git,github
RISE-UNIBAS,networks_gephi,https://github.com/RISE-UNIBAS/networks_gephi.git,github
RISE-UNIBAS,stylometry_R,https://github.com/RISE-UNIBAS/stylometry_R.git,github
RISE-UNIBAS,selenium-examples,https://github.com/RISE-UNIBAS/selenium-examples.git,github
RISE-UNIBAS,generic_llm_api_client,https://github.com/RISE-UNIBAS/generic_llm_api_client.git,github
dhlab-basel,JDNConvertibleCalendar,https://github.com/dhlab-basel/JDNConvertibleCalendar.git,github
dhlab-basel,beol,https://github.com/dhlab-basel/beol.git,github
dhlab-basel,JourneyStar,https://github.com/dhlab-basel/JourneyStar.git,github
dhlab-basel,0807-mls-app,https://github.com/dhlab-basel/0807-mls-app.git,github
ceda-unibas,moral-content-search,https://gitlab.com/ceda-unibas/moral-content-search.git,gitlab
ceda-unibas,tools/data-annotations,https://gitlab.com/ceda-unibas/tools/data-annotations.git,gitlab
ceda-unibas,tools/unibas-docs-copier,https://gitlab.com/ceda-unibas/tools/unibas-docs-copier.git,gitlab
ceda-unibas,trainings/pids-lecture,https://gitlab.com/ceda-unibas/trainings/pids-lecture.git,gitlab
ceda-unibas,snakemake-dvc-poc,https://gitlab.com/ceda-unibas/snakemake-dvc-poc.git,gitlab
ceda-unibas,behavior-twin,https://gitlab.com/ceda-unibas/behavior-twin.git,gitlab
ceda-unibas,nuclear-magnetic-resonance,https://gitlab.com/ceda-unibas/nuclear-magnetic-resonance.git,gitlab
ceda-unibas,cell-lineage-metaloci-computation,https://gitlab.com/ceda-unibas/cell-lineage-metaloci-computation.git,gitlab
ceda-unibas,cell-lineage-identification,https://gitlab.com/ceda-unibas/cell-lineage-identification.git,gitlab
ceda-unibas,llm-api-poc,https://gitlab.com/ceda-unibas/llm-api-poc.git,gitlab
ceda-unibas,tools/dotenv-copier,https://gitlab.com/ceda-unibas/tools/dotenv-copier.git,gitlab
ceda-unibas,tools/ceda-renovate,https://gitlab.com/ceda-unibas/tools/ceda-renovate.git,gitlab
ceda-unibas,open-alex-networks,https://gitlab.com/ceda-unibas/open-alex-networks.git,gitlab
ceda-unibas,ludok-tools,https://gitlab.com/ceda-unibas/ludok-tools.git,gitlab
ceda-unibas,gitlab-profile,https://gitlab.com/ceda-unibas/gitlab-profile.git,gitlab
ceda-unibas,tools/ceda-project-copier,https://gitlab.com/ceda-unibas/tools/ceda-project-copier.git,gitlab
ceda-unibas,bav,https://gitlab.com/ceda-unibas/bav.git,gitlab
ceda-unibas,ceda-cookiecutter-uv,https://gitlab.com/ceda-unibas/ceda-cookiecutter-uv.git,gitlab
ceda-unibas,myotube-characterization,https://gitlab.com/ceda-unibas/myotube-characterization.git,gitlab
ceda-unibas,fast-noise-to-signal,https://gitlab.com/ceda-unibas/fast-noise-to-signal.git,gitlab
ceda-unibas,behavioral-fingerprinting-of-fruit-flies,https://gitlab.com/ceda-unibas/behavioral-fingerprinting-of-fruit-flies.git,gitlab
ceda-unibas,sleep-brain-atlas,https://gitlab.com/ceda-unibas/sleep-brain-atlas.git,gitlab
ceda-unibas,sleepy-fly-brains,https://gitlab.com/ceda-unibas/sleepy-fly-brains.git,gitlab
ceda-unibas,spine-curvatures,https://gitlab.com/ceda-unibas/spine-curvatures.git,gitlab
ceda-unibas,neural-graphs-mice-development,https://gitlab.com/ceda-unibas/neural-graphs-mice-development.git,gitlab
ceda-unibas,nlp-job-ads,https://gitlab.com/ceda-unibas/nlp-job-ads.git,gitlab
FALLBACK
}

# ---------------------------------------------------------------------------
# Build unified CSV (organization,repository,url,platform)
# ---------------------------------------------------------------------------
build_repo_csv() {
  local tmp raw_count dedup_count
  tmp="$(mktemp)"
  echo "organization,repository,url,platform" > "$tmp"

  # Seed CSV (legacy 3-column or 4-column)
  if [[ -f "$CSV_FILE" ]]; then
    log "Merging seed CSV: $CSV_FILE"
    tail -n +2 "$CSV_FILE" | tr -d '\r' | while IFS=',' read -r organization repository url platform || [[ -n "${organization:-}" ]]; do
      organization="${organization//[[:space:]]/}"
      repository="${repository//[[:space:]]/}"
      url="${url//[[:space:]]/}"
      platform="${platform//[[:space:]]/}"
      [[ -z "$organization" || -z "$repository" || -z "$url" ]] && continue
      if [[ -z "$platform" ]]; then
        if [[ "$url" == *gitlab* ]]; then platform=gitlab; else platform=github; fi
      fi
      # normalise clone URL
      if [[ "$url" != *.git ]]; then
        url="${url%.git}.git"
        url="${url%.git}.git"
      fi
      case "$url" in
        http://*|https://*|git@*) ;;
        *) url="https://github.com/${organization}/${repository}.git" ;;
      esac
      echo "${organization},${repository},${url},${platform}"
    done >> "$tmp"
  fi

  log "Discovering GitHub organizations…"
  local org gh_lines
  for org in "${GITHUB_ORGS[@]}"; do
    log "  GitHub org: ${org}"
    gh_lines="$(discover_github_org "$org" | wc -l | tr -d ' ')"
    if [[ "${gh_lines:-0}" -eq 0 ]]; then
      log "  (no API results for ${org}; fallback may apply)"
    else
      log "  found ${gh_lines} repos"
      discover_github_org "$org" >> "$tmp"
    fi
  done

  log "Discovering GitLab groups…"
  local grp gl_lines
  for grp in "${GITLAB_GROUPS[@]}"; do
    log "  GitLab group: ${grp}"
    gl_lines="$(discover_gitlab_group "$grp" | wc -l | tr -d ' ')"
    if [[ "${gl_lines:-0}" -eq 0 ]]; then
      log "  (no API results for ${grp}; fallback may apply)"
    else
      log "  found ${gl_lines} projects"
      discover_gitlab_group "$grp" >> "$tmp"
    fi
  done

  # Always merge fallback so known core-facility repos are present even on rate limit
  log "Merging curated fallback inventory…"
  fallback_rows >> "$tmp"

  # Deduplicate by organization+repository (keep first URL)
  python3 - "$tmp" "$DISCOVERED_CSV" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
seen = set()
rows = []
with open(src, encoding="utf-8") as fh:
    header = fh.readline()
    for line in fh:
        line = line.strip()
        if not line:
            continue
        parts = line.split(",", 3)
        if len(parts) < 4:
            continue
        org, repo, url, platform = (p.strip() for p in parts)
        key = (org.lower(), repo.lower())
        if key in seen:
            continue
        seen.add(key)
        if not url.endswith(".git"):
            url = url.rstrip("/") + ".git"
        rows.append((org, repo, url, platform))
rows.sort(key=lambda r: (r[3], r[0].lower(), r[1].lower()))
with open(dst, "w", encoding="utf-8") as fh:
    fh.write("organization,repository,url,platform\n")
    for r in rows:
        fh.write(",".join(r) + "\n")
print(len(rows))
PY
  raw_count="$(wc -l < "$tmp" | tr -d ' ')"
  dedup_count="$(tail -n +2 "$DISCOVERED_CSV" | wc -l | tr -d ' ')"
  log "Discovery complete: ${dedup_count} unique repos (raw lines≈${raw_count}) → ${DISCOVERED_CSV}"
  rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Clone + Snyk
# ---------------------------------------------------------------------------
scan_repos() {
  echo "organization,repository,url,platform,clone_status,snyk_exit_code" > "$SUMMARY_FILE"

  tail -n +2 "$DISCOVERED_CSV" | tr -d '\r' | while IFS=',' read -r organization repository url platform || [[ -n "${organization:-}" ]]; do
    organization="${organization//[[:space:]]/}"
    repository="${repository//[[:space:]]/}"
    url="${url//[[:space:]]/}"
    platform="${platform//[[:space:]]/}"
    platform="${platform:-github}"

    if [[ -z "$organization" || -z "$repository" || -z "$url" ]]; then
      log "SKIP empty or malformed row"
      continue
    fi

    # Safe directory name (GitLab nested paths)
    safe_repo="${repository//\//__}"
    clone_dir="${WORK_DIR}/${organization}__${safe_repo}"
    log "===== ${organization}/${repository} (${platform}) ====="
    log "URL: $url"

    clone_status="ok"
    if [[ -d "${clone_dir}/.git" ]]; then
      log "Already cloned; fetching updates"
      if ! git -C "$clone_dir" fetch --all --prune >>"$LOG_FILE" 2>&1; then
        clone_status="fetch_failed"
        log "WARN: git fetch failed for ${organization}/${repository}"
      fi
    else
      if ! git clone --depth 1 "$url" "$clone_dir" >>"$LOG_FILE" 2>&1; then
        clone_status="clone_failed"
        log "ERROR: git clone failed for ${organization}/${repository}"
        echo "${organization},${repository},${url},${platform},${clone_status}," >> "$SUMMARY_FILE"
        continue
      fi
    fi

    snyk_rc=0
    (
      cd "$clone_dir" || exit 1
      # Non-zero exit when issues are found is expected.
      snyk code test
    ) >>"$LOG_FILE" 2>&1 || snyk_rc=$?

    log "snyk code test exit code: ${snyk_rc} (${organization}/${repository})"
    echo "${organization},${repository},${url},${platform},${clone_status},${snyk_rc}" >> "$SUMMARY_FILE"
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log "Work dir: $WORK_DIR"
build_repo_csv

# Refresh the default CSV path with the discovered set for reproducibility
cp -f "$DISCOVERED_CSV" "$CSV_FILE" 2>/dev/null || true
log "Canonical inventory written to ${CSV_FILE}"

if [[ "$DISCOVER_ONLY" -eq 1 ]]; then
  log "Discover-only mode; skipping clone/snyk."
  log "Repos: ${DISCOVERED_CSV}"
  exit 0
fi

scan_repos

log "Done. Summary: ${SUMMARY_FILE}"
log "Full log: ${LOG_FILE}"
log "Inventory: ${DISCOVERED_CSV}"
