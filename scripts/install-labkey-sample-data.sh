#!/usr/bin/env bash
# install-labkey-sample-data.sh
#
# Download LabKey's official open tutorial / demo datasets and (optionally)
# import the HIV example study into a running Community Edition server.
#
# These files are fictional but realistic. They are not patient data.
# Source of truth: https://www.labkey.org/download/@files/  and
# https://www.labkey.org/Documentation/wiki-page.view?name=setupDemoStudy
#
# Official archives this script fetches:
#   ImportableDemoStudy.folder.zip
#       Ready-to-import study folder archive (HIV observational demo).
#       Current docs name it ExampleResearchStudy.folder.zip; that filename
#       is not published on /download/@files, so the working ImportableDemo
#       archive is used and copied under the documented name as well.
#   LabKeyDemoFiles.zip
#       Excel/TSV tutorial files (Demographics, Physical Exam, Lab Results,
#       Consent, HIV Test Results, assays, lists, file-repository extras).
#   ProteomicsDemo.zip   (opt-in, ~67 MiB)
#       Older mzXML / MS2 tutorial data.
#   github.com/LabKey/examples
#       Sample scripts (Python upload, study-archive download), not raw data.
#
# Usage:
#   ./install-labkey-sample-data.sh
#   ./install-labkey-sample-data.sh --dir /root/scicore/sample-data
#   ./install-labkey-sample-data.sh --with-proteomics --with-examples
#   LK_URL=https://127.0.0.1:8443 LK_USER=admin LK_PASSWORD=xxx \
#     ./install-labkey-sample-data.sh --import --insecure
#
set -euo pipefail

DATA_DIR="${LK_SAMPLE_DIR:-$HOME/src/labkeySampleData}"
LK_WITH_PROTEOMICS=0
LK_WITH_EXAMPLES=1
LK_EXTRACT=1
LK_IMPORT=0
LK_FORCE="${LK_FORCE:-0}"
LK_INSECURE="${LK_INSECURE:-0}"
LK_URL="${LK_URL:-https://127.0.0.1:8443}"
LK_USER="${LK_USER:-}"
LK_PASSWORD="${LK_PASSWORD:-}"
LK_APIKEY="${LK_APIKEY:-}"
LK_CONTEXT="${LK_CONTEXT:-auto}"      # auto | "" | labkey
LK_PROJECT="${LK_PROJECT:-Tutorials}"
LK_STUDY_FOLDER="${LK_STUDY_FOLDER:-HIV Study}"
DOWNLOAD_BASE="https://www.labkey.org/download/@files"
EXAMPLES_REPO="https://github.com/LabKey/examples.git"

usage() {
  cat <<'EOF'
Download LabKey official sample / tutorial datasets (Community Edition).

Options:
  --dir DIR            Destination (default: $HOME/src/labkeySampleData)
  --with-proteomics    Also fetch ProteomicsDemo.zip (~67 MiB, older MS2)
  --no-examples        Do not clone github.com/LabKey/examples
  --no-extract         Keep zips only; do not unpack LabKeyDemoFiles
  --import             After download, import the demo study into a running
                       LabKey Server (needs --url and credentials)
  --force              Re-download archives and re-extract even when they are
                       already present; re-import instead of reusing the copy
                       on disk. Without it, anything already there is kept.
  --url URL            Server base URL (default: https://127.0.0.1:8443)
  --user NAME          LabKey site-admin user (or $LK_USER)
  --password PW        Password (or $LK_PASSWORD)
  --apikey KEY         API key instead of password (or $LK_APIKEY)
  --context PATH       App context: auto (default), empty, or labkey
  --project NAME       Destination project (default: Tutorials)
  --folder NAME        Destination study folder (default: HIV Study)
  --insecure           Skip TLS verification (implied for localhost HTTPS)
  -h, --help           Show this help

Layout after a successful run:
  $DIR/archives/ImportableDemoStudy.folder.zip   keep zipped for Import Study
  $DIR/archives/ExampleResearchStudy.folder.zip  same bytes, documented name
  $DIR/LabKeyDemoFiles/                          unzipped tutorial files
  $DIR/examples/                                 optional git clone
  $DIR/MANIFEST.txt
  $DIR/IMPORT.md

Import is optional. Without --import, open Admin > Folder > Management >
Import on the target folder and choose the .folder.zip. Do not unzip it first.

The data is fictional (HIV observational demo). Do not treat it as PHI.
EOF
}

# Progress must go to stderr: several helpers return the HTTP code on stdout.
log() { printf '[labkey-data] %s\n' "$*" >&2; }
die() { printf '[labkey-data] ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)              DATA_DIR="$2"; shift 2 ;;
    --with-proteomics)  LK_WITH_PROTEOMICS=1; shift ;;
    --no-examples)      LK_WITH_EXAMPLES=0; shift ;;
    --no-extract)       LK_EXTRACT=0; shift ;;
    --import)           LK_IMPORT=1; shift ;;
    --force)            LK_FORCE=1; shift ;;
    --url)              LK_URL="$2"; shift 2 ;;
    --user)             LK_USER="$2"; shift 2 ;;
    --password)         LK_PASSWORD="$2"; shift 2 ;;
    --apikey)           LK_APIKEY="$2"; shift 2 ;;
    --context)          LK_CONTEXT="$2"; shift 2 ;;
    --project)          LK_PROJECT="$2"; shift 2 ;;
    --folder)           LK_STUDY_FOLDER="$2"; shift 2 ;;
    --insecure)         LK_INSECURE=1; shift ;;
    -h|--help)          usage; exit 0 ;;
    *)                  die "Unknown option: $1" ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
need curl
need unzip
need mkdir
need sha256sum

# Self-signed Photon / embedded-Tomcat certs: skip verify for loopback HTTPS
# even when the caller forgets --insecure.
if [[ "$LK_INSECURE" -eq 0 ]]; then
  case "${LK_URL,,}" in
    https://127.0.0.1*|https://localhost*|https://[::1]*)
      LK_INSECURE=1
      ;;
  esac
fi

curl_flags=(-fsSL --retry 3 --retry-delay 2)
if [[ "$LK_INSECURE" -eq 1 ]]; then
  curl_flags+=(-k)
fi

# Photon / BusyBox: curl -f fails on HTTP errors; -w writes after the body.
download() {
  local url="$1" dest="$2" label="$3"
  # --force means fetch again: a cached archive may be a truncated or stale
  # copy, and that is exactly what a re-run is meant to repair.
  if [[ -s "$dest" && "$LK_FORCE" -eq 0 ]]; then
    log "Already present: $label ($(wc -c < "$dest" | tr -d ' ') bytes)"
    return 0
  fi
  log "Downloading $label"
  log "  $url"
  if ! curl "${curl_flags[@]}" -o "$dest.part" "$url"; then
    rm -f "$dest.part"
    die "Download failed: $url"
  fi
  mv "$dest.part" "$dest"
  log "  saved $(wc -c < "$dest" | tr -d ' ') bytes -> $dest"
}

mkdir -p "$DATA_DIR/archives"
ARCH="$DATA_DIR/archives"

# Primary importable HIV study (works on current CE).
download \
  "$DOWNLOAD_BASE/ImportableDemoStudy.folder.zip" \
  "$ARCH/ImportableDemoStudy.folder.zip" \
  "ImportableDemoStudy.folder.zip"

# Documented filename from setupDemoStudy. Same archive, different name, so
# the UI walk-through in the docs still matches a file on disk.
if [[ ! -e "$ARCH/ExampleResearchStudy.folder.zip" ]]; then
  cp -f "$ARCH/ImportableDemoStudy.folder.zip" "$ARCH/ExampleResearchStudy.folder.zip"
  log "Copied ImportableDemoStudy.folder.zip as ExampleResearchStudy.folder.zip"
fi

download \
  "$DOWNLOAD_BASE/LabKeyDemoFiles.zip" \
  "$ARCH/LabKeyDemoFiles.zip" \
  "LabKeyDemoFiles.zip"

if [[ "$LK_WITH_PROTEOMICS" -eq 1 ]]; then
  download \
    "$DOWNLOAD_BASE/ProteomicsDemo.zip" \
    "$ARCH/ProteomicsDemo.zip" \
    "ProteomicsDemo.zip (~67 MiB)"
fi

if [[ "$LK_EXTRACT" -eq 1 ]]; then
  if [[ ! -d "$DATA_DIR/LabKeyDemoFiles" || "$LK_FORCE" -eq 1 ]]; then
    log "Extracting LabKeyDemoFiles.zip"
    unzip -q -o "$ARCH/LabKeyDemoFiles.zip" -d "$DATA_DIR"
    # Zip may unpack as LabKeyDemoFiles/ or as loose files.
    if [[ ! -d "$DATA_DIR/LabKeyDemoFiles" ]]; then
      mkdir -p "$DATA_DIR/LabKeyDemoFiles"
      # Move anything that is not archives/examples/docs into the folder.
      for item in "$DATA_DIR"/*; do
        base="$(basename "$item")"
        case "$base" in
          archives|examples|LabKeyDemoFiles|MANIFEST.txt|IMPORT.md) ;;
          *) mv "$item" "$DATA_DIR/LabKeyDemoFiles/" ;;
        esac
      done
    fi
  else
    log "Already extracted: $DATA_DIR/LabKeyDemoFiles"
  fi
fi

if [[ "$LK_WITH_EXAMPLES" -eq 1 ]]; then
  need git
  if [[ -d "$DATA_DIR/examples/.git" ]]; then
    log "Updating LabKey/examples"
    git -C "$DATA_DIR/examples" pull --ff-only || \
      log "Fast-forward failed for examples; left at $(git -C "$DATA_DIR/examples" rev-parse --short HEAD)"
  else
    log "Cloning LabKey/examples"
    git clone --depth 1 "$EXAMPLES_REPO" "$DATA_DIR/examples"
  fi
fi

{
  echo "LabKey sample / tutorial data"
  echo "Fetched: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Directory: $DATA_DIR"
  echo
  echo "SHA-256"
  (cd "$ARCH" && sha256sum -- *.zip 2>/dev/null || sha256sum ./*.zip)
  echo
  echo "Contents of LabKeyDemoFiles (top level):"
  if [[ -d "$DATA_DIR/LabKeyDemoFiles" ]]; then
    ls -1 "$DATA_DIR/LabKeyDemoFiles"
  else
    echo "(not extracted)"
  fi
} > "$DATA_DIR/MANIFEST.txt"

cat > "$DATA_DIR/IMPORT.md" <<EOF
# Import the HIV example study

The zip in archives/ must stay zipped. LabKey imports a folder archive,
it does not unpack it for you.

## UI (any CE build)

1. Sign in as a site administrator.
2. Create project **${LK_PROJECT}** (Collaboration) if it does not exist.
3. Inside it, create folder **${LK_STUDY_FOLDER}** of type Study.
4. On the New Study page choose Import Study.
5. Select Local zip archive and choose
   \`archives/ImportableDemoStudy.folder.zip\`
   (or the ExampleResearchStudy.folder.zip copy).
6. Leave "Validate All Queries After Import" selected.
7. Wait until the pipeline job reports Complete.

Live preview of the same fictional study:
https://www.labkey.org/home/Demos/HIV%20Study%20Tutorial/project-begin.view

## From-scratch study (LabKeyDemoFiles)

Unpacked under LabKeyDemoFiles/. Typical tutorial files:

- Datasets/Demographics.xls
- Datasets/Physical Exam.xls (or similar)
- Datasets/Lab Results.xls
- Consent.xls / HIV Test Results.xls / Status Assessment.xls
- Assays/ for the assay-design tutorial
- Lists/ for the file-repository / lists tutorial

Create an empty Study folder and import each spreadsheet under
Manage > Manage Datasets > Create New Dataset > Import from File.

## Command line

    $0 --dir $DATA_DIR --import --url ${LK_URL} --user <admin> --password <pw>

Self-signed Photon HTTPS: add --insecure.

Data is fictional. Do not load it into a production PHI container.
EOF

log "Wrote $DATA_DIR/MANIFEST.txt and $DATA_DIR/IMPORT.md"
log "Sample data is in $DATA_DIR"

# ---------------------------------------------------------------------------
# Optional import into a running server
# ---------------------------------------------------------------------------
if [[ "$LK_IMPORT" -ne 1 ]]; then
  log "Download only. Import later with --import or via the UI (see IMPORT.md)."
  exit 0
fi

if [[ -z "$LK_APIKEY" && ( -z "$LK_USER" || -z "$LK_PASSWORD" ) ]]; then
  die "--import needs --user/--password or --apikey (or LK_USER/LK_PASSWORD/LK_APIKEY)"
fi

# Do not use curl -f on API calls: we need the body of 4xx responses.
# Do not use -L: importFolder.post returns 302 to the pipeline page, and
# following it against a self-signed / hostname-mismatched cert (127.0.0.1
# vs the server's canonical name) loops until curl error 47.
api_flags=(-sS --retry 2 --retry-delay 1)
if [[ "$LK_INSECURE" -eq 1 ]]; then
  api_flags+=(-k)
  log "TLS verify disabled (--insecure or loopback HTTPS)"
fi

origin="${LK_URL%/}"
cookie_jar="$(mktemp)"
csrf=""
trap 'rm -f "$cookie_jar"' EXIT

auth_args=()
if [[ -n "$LK_APIKEY" ]]; then
  auth_args+=(-H "apikey: $LK_APIKEY")
else
  auth_args+=(-u "${LK_USER}:${LK_PASSWORD}")
fi

json_get() {
  # json_get KEY < text   — tiny extractor, no jq required
  local key="$1"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

urlenc() {
  printf '%s' "$1" | sed 's/ /%20/g'
}

# LabKey URL: {origin}{context}/{containerPath}/{controller}-{action}
# Embedded CE 24.3+ defaults to an empty context. Older / WAR installs use /labkey.
# The previous default literally appended "/auto" and every call 404'd.
probe_context() {
  local candidate="$1" label="$2" body code
  body="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
    "${auth_args[@]}" \
    -H "Accept: application/json" \
    -w '\n%{http_code}' \
    "${candidate}/login-whoAmI.api" 2>/dev/null || true)"
  code="$(printf '%s' "$body" | tail -n 1)"
  body="$(printf '%s' "$body" | sed '$d')"
  if [[ "$code" == "200" ]] && printf '%s' "$body" | grep -qE '"CSRF"|"displayName"|"email"'; then
    log "  context ${label}: HTTP ${code} OK"
    csrf="$(printf '%s' "$body" | json_get CSRF)"
    return 0
  fi
  log "  context ${label}: HTTP ${code:-err}"
  return 1
}

resolve_base() {
  local ctx="${LK_CONTEXT}"
  case "$ctx" in
    auto|AUTO)
      log "Discovering application context on ${origin}"
      if probe_context "$origin" "(root)"; then
        base="$origin"
        return 0
      fi
      if probe_context "${origin}/labkey" "/labkey"; then
        base="${origin}/labkey"
        return 0
      fi
      die "Could not reach login-whoAmI.api at ${origin} or ${origin}/labkey. Is the server up?"
      ;;
    ""|/)
      base="$origin"
      ;;
    *)
      base="${origin}/${ctx#/}"
      base="${base%/}"
      ;;
  esac
}

lk_post_json() {
  # lk_post_json CONTAINER_PATH ACTION JSON_BODY OUTFILE
  local cpath="$1" action="$2" payload="$3" out="$4"
  local url http
  cpath="${cpath#/}"
  if [[ -n "$cpath" ]]; then
    url="${base}/$(urlenc "$cpath")/${action}"
  else
    url="${base}/${action}"
  fi
  log "  POST ${url}"
  http="$(curl "${api_flags[@]}" -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" \
    "${auth_args[@]}" \
    -d "$payload" \
    -o "$out" \
    -w '%{http_code}' \
    "$url" || true)"
  printf '%s' "$http"
}

lk_post_form() {
  # lk_post_form CONTAINER_PATH ACTION OUTFILE -- extra curl -F/-d args
  # Writes headers to ${out}.hdr and the Location (if any) to ${out}.loc
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
  : > "${out}.hdr"
  http="$(curl "${api_flags[@]}" --max-redirs 0 -X POST \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" \
    "${auth_args[@]}" \
    -D "${out}.hdr" \
    -o "$out" \
    -w '%{http_code}' \
    "$@" \
    "$url" || true)"
  sed -n 's/^[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]:[[:space:]]*//p' "${out}.hdr" \
    | tr -d '\r' | tail -n 1 > "${out}.loc"
  printf '%s' "$http"
}

http_code() {
  # Last 3-digit status from a curl -w payload (ignores any stray log text).
  printf '%s' "$1" | tr -d '\r' | grep -oE '[0-9]{3}' | tail -n 1
}

import_ok() {
  # import_ok HTTP_CODE BODYFILE
  local http out loc=""
  http="$(http_code "$1")"
  out="$2"
  [[ -s "${out}.loc" ]] && loc="$(cat "${out}.loc")"
  case "$http" in
    200|201)
      if grep -qiE '"success"[[:space:]]*:[[:space:]]*true|pipeline|Complete|Import' "$out" 2>/dev/null; then
        return 0
      fi
      [[ ! -s "$out" ]] && return 0
      return 1
      ;;
    302|303)
      if printf '%s' "$loc" | grep -qiE 'login-login|login\.view'; then
        log "  redirected to login — session/CSRF rejected"
        return 1
      fi
      log "  redirected to ${loc:-<no Location>}"
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

login_session() {
  resolve_base
  log "Opening a session on ${base}"
  local body
  if [[ -z "$csrf" ]]; then
    body="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
      "${auth_args[@]}" \
      -H "Accept: application/json" \
      "${base}/login-whoAmI.api" || true)"
    csrf="$(printf '%s' "$body" | json_get CSRF)"
  fi
  if [[ -z "$csrf" && -z "$LK_APIKEY" ]]; then
    body="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -H "Accept: application/json" \
      --data-urlencode "email=${LK_USER}" \
      --data-urlencode "password=${LK_PASSWORD}" \
      "${base}/login-loginApi.api" || true)"
    csrf="$(printf '%s' "$body" | json_get CSRF)"
  fi
  if [[ -z "$csrf" ]]; then
    body="$(curl "${api_flags[@]}" -c "$cookie_jar" -b "$cookie_jar" \
      "${auth_args[@]}" \
      "${base}/login-whoAmI.api" || true)"
    csrf="$(printf '%s' "$body" | json_get CSRF)"
  fi
  if [[ -n "$csrf" ]]; then
    log "  session CSRF acquired"
  else
    log "  no CSRF token; continuing with basic/API-key auth"
  fi
}

container_exists() {
  local path="$1" http
  path="${path#/}"
  http="$(curl "${api_flags[@]}" \
    "${auth_args[@]}" \
    -b "$cookie_jar" -c "$cookie_jar" \
    -H "Accept: application/json" \
    -o /tmp/labkey-get-container.json \
    -w '%{http_code}' \
    "${base}/$(urlenc "$path")/project-getContainers.api?includeSubfolders=false" || true)"
  [[ "$http" == "200" ]] && grep -q '"path"' /tmp/labkey-get-container.json 2>/dev/null
}

create_container() {
  local parent="$1" name="$2" ftype="$3"
  local dest out http payload
  if [[ "$parent" == "/" || -z "$parent" ]]; then
    dest="/${name}"
    parent=""
  else
    dest="${parent%/}/${name}"
  fi
  log "Ensuring container '${dest}' (type ${ftype})"
  if container_exists "$dest"; then
    log "  already exists"
    return 0
  fi
  payload="$(printf '{"name":"%s","title":"%s","folderType":"%s","isWorkbook":false}' \
    "$name" "$name" "$ftype")"
  out="/tmp/labkey-create-container.json"
  # Official client API: POST {parent}/core-createContainer.api
  http="$(lk_post_json "$parent" "core-createContainer.api" "$payload" "$out")"
  log "  HTTP ${http}"
  if grep -qE '"path"|"name"' "$out" 2>/dev/null && ! grep -qiE '"exception"|"status"[[:space:]]*:[[:space:]]*"Error"' "$out" 2>/dev/null; then
    log "  created"
    return 0
  fi
  if grep -qiE 'already exist|duplicate' "$out" 2>/dev/null; then
    log "  already exists"
    return 0
  fi
  log "  create response:"
  sed -n '1,16p' "$out" 2>/dev/null || true
  if [[ "$http" != "200" && "$http" != "201" ]]; then
    return 1
  fi
}

webdav_put() {
  # webdav_put CONTAINER_PATH LOCAL_ZIP
  local cpath="$1" zip="$2" dest name url http
  name="$(basename "$zip")"
  dest="$(urlenc "${cpath#/}")"
  url="${base}/_webdav/${dest}/@files/${name}"
  log "  PUT ${url}"
  http="$(curl "${api_flags[@]}" --max-redirs 0 -T "$zip" \
    ${csrf:+-H "X-LABKEY-CSRF: $csrf"} \
    -b "$cookie_jar" -c "$cookie_jar" \
    "${auth_args[@]}" \
    -H "Content-Type: application/zip" \
    -o /tmp/labkey-webdav-put.out \
    -w '%{http_code}' \
    "$url" || true)"
  log "  HTTP ${http} (webdav PUT)"
  [[ "$http" == "200" || "$http" == "201" || "$http" == "204" ]]
}

import_study() {
  local dest="$1" zip="$2"
  local out="/tmp/labkey-import-folder.json" http name
  name="$(basename "$zip")"
  log "Importing ${name} into /${dest#/}"

  # 1) Official form action. A 302 to pipeline-status means the job was queued.
  http="$(lk_post_form "$dest" "admin-importFolder.post" "$out" \
    -F "folderZip=@${zip};filename=${name};type=application/zip" \
    -F "validateQueries=true" \
    -F "createSharedDatasets=true" \
    ${csrf:+-F "X-LABKEY-CSRF=${csrf}"})"
  log "  HTTP ${http} (admin-importFolder.post folderZip)"
  if import_ok "$http" "$out"; then
    log "  import request accepted"
    return 0
  fi

  # 2) Alternate multipart field name
  http="$(lk_post_form "$dest" "admin-importFolder.post" "$out" \
    -F "file=@${zip};filename=${name};type=application/zip" \
    -F "validateQueries=true" \
    ${csrf:+-F "X-LABKEY-CSRF=${csrf}"})"
  log "  HTTP ${http} (admin-importFolder.post file)"
  if import_ok "$http" "$out"; then
    log "  import request accepted"
    return 0
  fi

  # 3) Upload via WebDAV then import from the pipeline file root
  log "Trying WebDAV upload + pipeline import"
  if webdav_put "$dest" "$zip"; then
    http="$(lk_post_form "$dest" "admin-importFolder.post" "$out" \
      -F "validateQueries=true" \
      -F "createSharedDatasets=true" \
      --form-string "path=@files/${name}" \
      ${csrf:+-F "X-LABKEY-CSRF=${csrf}"})"
    log "  HTTP ${http} (admin-importFolder.post path=@files/${name})"
    if import_ok "$http" "$out"; then
      log "  import request accepted"
      return 0
    fi
    http="$(lk_post_form "$dest" "pipeline-startFolderImport.api" "$out" \
      --form-string "path=@files/${name}" \
      -F "validateQueries=true" \
      ${csrf:+-F "X-LABKEY-CSRF=${csrf}"})"
    log "  HTTP ${http} (pipeline-startFolderImport.api)"
    if import_ok "$http" "$out"; then
      log "  import request accepted"
      return 0
    fi
  fi

  log "  import did not confirm success. Last response:"
  sed -n '1,24p' "$out" 2>/dev/null || true
  [[ -s "${out}.loc" ]] && log "  Location: $(cat "${out}.loc")"
  log "Fall back to the UI steps in $DATA_DIR/IMPORT.md"
  return 1
}

login_session
create_container "/" "$LK_PROJECT" "Collaboration" || \
  die "Could not create project '${LK_PROJECT}'"
create_container "/$LK_PROJECT" "$LK_STUDY_FOLDER" "Study" || \
  die "Could not create folder '${LK_PROJECT}/${LK_STUDY_FOLDER}'"

study_path="${LK_PROJECT}/${LK_STUDY_FOLDER}"
import_study "$study_path" "$ARCH/ImportableDemoStudy.folder.zip" || \
  die "Automatic import failed; archives are still in $ARCH"

log "Import submitted. Watch Admin Console > Pipeline or the folder's import page."
log "Study URL: ${base}/$(urlenc "$study_path")/project-begin.view"
