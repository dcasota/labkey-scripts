#!/usr/bin/env bash
# build-labkey-community.sh
#
# Clone LabKey Server Community Edition sources, compile them, and stage the
# development (or production) deployment tree.
#
# Official enlistment (LabKey docs):
#   github.com/LabKey/server
#   github.com/LabKey/platform        -> server/modules/platform
#   github.com/LabKey/commonAssays    -> server/modules/commonAssays
# Optional:
#   github.com/LabKey/testAutomation  -> server/testAutomation
#
# Prerequisites (Photon OS):
#   tdnf install -y git postgresql18 postgresql18-server openjdk25
#   - Git
#   - OpenJDK 25 (JAVA_HOME is set if tdnf laid it down)
#   - PostgreSQL 18 listening locally (needed for pickPg / a runnable staged server)
#   - Network access to github.com and LabKey's Maven/Artifactory
#
# Usage:
#   ./build-labkey-community.sh
#   ./build-labkey-community.sh --branch release26.7 --dir "$HOME/src/labkey"
#   ./build-labkey-community.sh --prod --with-tests
#   LK_PG_USER=labkey LK_PG_PASSWORD=secret ./build-labkey-community.sh
#
# Staged output:
#   $LK_DIR/build/deploy
#
set -euo pipefail

LK_DIR="${LK_DIR:-$HOME/src/labkeyEnlistment}"
LK_BRANCH="${LK_BRANCH:-develop}"
LK_WITH_TESTS=0
LK_PROD=0
LK_SKIP_BUILD=0
LK_SKIP_CLONE=0
LK_START=1
LK_DAEMON=0
LK_START_ONLY=0
LK_PG_USER="${LK_PG_USER:-postgres}"
LK_PG_PASSWORD="${LK_PG_PASSWORD:-sasa}"
LK_PG_HOST="${LK_PG_HOST:-localhost}"
LK_PG_PORT="${LK_PG_PORT:-5432}"
LK_PG_DATABASE="${LK_PG_DATABASE:-labkey}"
LK_PGDATA="${LK_PGDATA:-/var/lib/labkey/pgsql}"
LK_HTTPS="${LK_HTTPS:-1}"
LK_HTTPS_PORT="${LK_HTTPS_PORT:-8443}"
LK_HTTP_PORT="${LK_HTTP_PORT:-8080}"
LK_KEYSTORE_PASS="${LK_KEYSTORE_PASS:-changeit}"
LK_SITE_SHORT_NAME="${LK_SITE_SHORT_NAME:-sciCORE LabKey}"
LK_SITE_DESCRIPTION="${LK_SITE_DESCRIPTION:-sciCORE LabKey collaboration server (University of Basel)}"
LK_SITE_ORG="${LK_SITE_ORG:-sciCORE, University of Basel}"
LK_SITE_EMAIL="${LK_SITE_EMAIL:-scicore@unibas.ch}"
LK_SITE_THEME="${LK_SITE_THEME:-Seattle}"
REMOTE_BASE="https://github.com/LabKey"

usage() {
  cat <<'EOF'
Clone, compile, and stage LabKey Community Edition from source.

Options:
  --dir DIR          Enlistment directory (default: $HOME/src/labkeyEnlistment)
  --branch NAME      Git branch or tag in every repo (default: develop)
  --prod             Production-mode stage (gradlew deployApp -PdeployMode=prod)
  --with-tests       Also clone server/testAutomation
  --skip-clone       Reuse an existing enlistment; only compile/stage
  --skip-build       Clone/update only; do not compile
  --start            After staging, start Postgres + LabKey (default)
  --no-start         Do not start LabKey
  --start-only       Skip clone/build; provision DB and start the staged server
  --daemon           Start LabKey in the background
  --https            Enable HTTPS on 8443 (default)
  --no-https         HTTP only on 8080
  --https-port N     HTTPS port (default: 8443)
  --pg-user NAME     PostgreSQL user written to pg.properties
  --pg-password PW   PostgreSQL password written to pg.properties
  --pg-host HOST     PostgreSQL host (default: localhost)
  --pg-port PORT     PostgreSQL port (default: 5432)
  --pg-database DB   PostgreSQL database (default: labkey)
  -h, --help         Show this help

Environment:
  JAVA_HOME          JDK 25 home
  GIT_ACCESS_TOKEN   GitHub token (optional; used for clone + Gradle GitHub API)
  LK_*               Same as the flags above (LK_DIR, LK_BRANCH, ...)
EOF
}

log() { printf '[labkey] %s\n' "$*"; }
die() { printf '[labkey] ERROR: %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

java_major() {
  local bin="${1:-java}"
  # BusyBox-safe: do not use awk -F[".].  Example line:
  #   openjdk version "25.0.2-internal" 2026-01-20
  "$bin" -version 2>&1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -n 1
}

is_jdk25() {
  local bin="$1"
  [[ -x "$bin" ]] || return 1
  [[ "$(java_major "$bin")" == "25" ]]
}

# Photon often has both:
#   /usr/lib/jvm/OpenJDK-21   <- default /usr/bin/java
#   /usr/lib/jvm/OpenJDK-25   <- required for LabKey sourceCompatibility=25
# Never trust PATH or an existing JAVA_HOME if it is 21.
find_jdk25_home() {
  local candidate bin
  local -a homes=(
    /usr/lib/jvm/OpenJDK-25
    /usr/lib/jvm/openjdk-25
    /usr/lib/jvm/java-25-openjdk
    /usr/lib/jvm/jdk-25
    /usr/lib/jvm/jre-25
    /usr/java/openjdk-25
  )
  if [[ -n "${JAVA_HOME:-}" ]]; then
    homes+=("$JAVA_HOME")
  fi
  if [[ -d /usr/lib/jvm ]]; then
    for candidate in /usr/lib/jvm/*; do
      homes+=("$candidate")
    done
  fi

  for candidate in "${homes[@]}"; do
    bin="$candidate/bin/java"
    if is_jdk25 "$bin"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

select_jdk25() {
  local home path_java path_major old_home
  old_home="${JAVA_HOME:-}"
  path_java="$(command -v java 2>/dev/null || true)"
  if [[ -n "$path_java" ]]; then
    path_major="$(java_major "$path_java" || true)"
    log "PATH java is $path_java (major ${path_major:-unknown})"
  fi
  if [[ -x /usr/lib/jvm/OpenJDK-21/bin/java ]]; then
    log "Also present: /usr/lib/jvm/OpenJDK-21 (ignored for this build)"
  fi

  if ! home="$(find_jdk25_home)"; then
    return 1
  fi

  export JAVA_HOME="$home"
  # Drop any previously selected JDK from PATH, then prepend 25.
  export PATH="$JAVA_HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  if [[ -n "$old_home" && "$old_home" != "$JAVA_HOME" ]]; then
    log "Overriding JAVA_HOME=$old_home -> $JAVA_HOME"
  fi
  log "Using JDK 25 at JAVA_HOME=$JAVA_HOME"
  return 0
}

install_photon_prereqs() {
  if ! command -v tdnf >/dev/null 2>&1; then
    log "tdnf not found; skipping Photon package install"
    return 0
  fi
  log "Installing Photon OS prerequisites: git postgresql18 postgresql18-server openjdk25"
  local pkg
  for pkg in git openjdk25 postgresql18 postgresql18-server; do
    if [[ "$(id -u)" -eq 0 ]]; then
      tdnf install -y "$pkg" || log "tdnf could not install $pkg (ok if already present under another name)"
    else
      sudo tdnf install -y "$pkg" || log "tdnf could not install $pkg (ok if already present under another name)"
    fi
  done
}

# Photon OS uses BusyBox xargs. Gradle's gradlew does:
#   eval "set -- $(printf '%s\n' "$DEFAULT_JVM_OPTS ..." | xargs -n1 | ...)"
# GNU xargs strips the quotes in DEFAULT_JVM_OPTS='"-Xmx64m" "-Xms64m"'.
# BusyBox xargs keeps them, so java receives the token "-Xmx64m" and
# reports: Could not find or load main class "-Xmx64m"
patch_gradlew_for_busybox() {
  local gw="${LK_DIR}/gradlew"
  [[ -f "$gw" ]] || return 0
  if grep -q 'DEFAULT_JVM_OPTS='"'"'"-Xmx64m" "-Xms64m"'"'" "$gw" \
     || grep -q "DEFAULT_JVM_OPTS=.*-Xmx64m" "$gw"; then
    log "Patching gradlew DEFAULT_JVM_OPTS for BusyBox xargs (Photon OS)"
    sed -i \
      -e 's/^DEFAULT_JVM_OPTS=.*/DEFAULT_JVM_OPTS="-Xmx64m -Xms64m"/' \
      "$gw"
  fi
}

prepare_gradle_env() {
  unset GRADLE_OPTS JAVA_OPTS _JAVA_OPTIONS JAVA_TOOL_OPTIONS
  export GRADLE_OPTS=""
  export JAVA_OPTS=""

  local java_bin="${JAVA_HOME:-}/bin/java"
  [[ -x "$java_bin" ]] || java_bin="$(command -v java)"
  log "java: $java_bin"
  "$java_bin" -version 2>&1 | sed 's/^/[labkey]   /' || true
  log "JAVA_HOME=${JAVA_HOME-<unset>}"
}

run_gradle() {
  prepare_gradle_env
  local wrapper="${LK_DIR}/gradle/wrapper/gradle-wrapper.jar"
  local java_bin="${JAVA_HOME}/bin/java"
  [[ -f "$wrapper" ]] || die "Missing Gradle wrapper jar: $wrapper"
  is_jdk25 "$java_bin" || die "Refusing to build with $java_bin (need JDK 25, Photon also has OpenJDK-21)"

  log "Launching Gradle via $java_bin -jar gradle-wrapper.jar (bypassing gradlew)"
  "$java_bin" \
    -Xmx64m \
    -Xms64m \
    -Dfile.encoding=UTF-8 \
    -Dorg.gradle.appname=gradlew \
    -jar "$wrapper" \
    --no-daemon \
    "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)          LK_DIR="$2"; shift 2 ;;
    --branch)       LK_BRANCH="$2"; shift 2 ;;
    --prod)         LK_PROD=1; shift ;;
    --with-tests)   LK_WITH_TESTS=1; shift ;;
    --skip-clone)   LK_SKIP_CLONE=1; shift ;;
    --skip-build)   LK_SKIP_BUILD=1; shift ;;
    --start)        LK_START=1; shift ;;
    --no-start)     LK_START=0; shift ;;
    --start-only)   LK_START_ONLY=1; LK_SKIP_CLONE=1; LK_SKIP_BUILD=1; LK_START=1; shift ;;
    --daemon)       LK_DAEMON=1; shift ;;
    --https)        LK_HTTPS=1; shift ;;
    --no-https)     LK_HTTPS=0; shift ;;
    --https-port)   LK_HTTPS_PORT="$2"; shift 2 ;;
    --pg-user)      LK_PG_USER="$2"; shift 2 ;;
    --pg-password)  LK_PG_PASSWORD="$2"; shift 2 ;;
    --pg-host)      LK_PG_HOST="$2"; shift 2 ;;
    --pg-port)      LK_PG_PORT="$2"; shift 2 ;;
    --pg-database)  LK_PG_DATABASE="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "Unknown option: $1 (try --help)" ;;
  esac
done

install_photon_prereqs

need git
need bash

if [[ "$LK_SKIP_BUILD" -eq 0 || "$LK_START" -eq 1 ]]; then
  if ! select_jdk25; then
    die "LabKey needs JDK 25 (sourceCompatibility=25). Found no java 25 after tdnf install openjdk25. PATH java is: $(command -v java 2>/dev/null || echo missing). Install openjdk25 and re-run, or set JAVA_HOME to a JDK 25 home."
  fi
  if ! is_jdk25 "$JAVA_HOME/bin/java"; then
    die "JAVA_HOME=$JAVA_HOME is not JDK 25. LabKey compile fails with: invalid source release: 25"
  fi
fi

github_url() {
  local repo="$1"
  if [[ -n "${GIT_ACCESS_TOKEN:-}" ]]; then
    printf 'https://%s@github.com/LabKey/%s.git' "$GIT_ACCESS_TOKEN" "$repo"
  else
    printf '%s/%s.git' "$REMOTE_BASE" "$repo"
  fi
}

clone_or_update() {
  local dest="$1" repo="$2"
  if [[ -d "$dest/.git" ]]; then
    log "Updating $repo in $dest (branch $LK_BRANCH)"
    git -C "$dest" fetch --prune origin
    git -C "$dest" checkout "$LK_BRANCH"
    git -C "$dest" pull --ff-only origin "$LK_BRANCH" || \
      log "Fast-forward pull failed for $repo; left at $(git -C "$dest" rev-parse --short HEAD)"
  else
    log "Cloning $repo -> $dest"
    mkdir -p "$(dirname "$dest")"
    git clone --branch "$LK_BRANCH" --single-branch "$(github_url "$repo")" "$dest"
  fi
}

ensure_user_gradle_properties() {
  local gradle_dir="${HOME}/.gradle"
  local dest="${gradle_dir}/gradle.properties"
  local template="${LK_DIR}/gradle/global_gradle.properties_template"
  mkdir -p "$gradle_dir"
  if [[ ! -f "$dest" ]]; then
    if [[ -f "$template" ]]; then
      log "Creating $dest from LabKey template"
      cp "$template" "$dest"
    else
      log "Creating minimal $dest"
      cat >"$dest" <<'EOF'
deployMode=dev
EOF
    fi
  else
    log "Using existing $dest"
  fi
}

configure_pg_properties() {
  local pg="${LK_DIR}/server/configs/pg.properties"
  [[ -f "$pg" ]] || die "Missing $pg — unexpected enlistment layout"
  log "Writing PostgreSQL settings into server/configs/pg.properties"
  # Keep other keys; only override connection fields.
  local tmp
  tmp="$(mktemp)"
  awk -v user="$LK_PG_USER" -v pass="$LK_PG_PASSWORD" \
      -v host="$LK_PG_HOST" -v port="$LK_PG_PORT" -v db="$LK_PG_DATABASE" '
    BEGIN { u=0; p=0; h=0; o=0; d=0 }
    /^jdbcUser=/            { print "jdbcUser=" user; u=1; next }
    /^jdbcPassword=/        { print "jdbcPassword=" pass; p=1; next }
    /^databaseDefaultHost=/ { print "databaseDefaultHost=" host; h=1; next }
    /^databaseDefaultPort=/ { print "databaseDefaultPort=" port; o=1; next }
    /^databaseDefault=/     { print "databaseDefault=" db; d=1; next }
    { print }
    END {
      if (!u) print "jdbcUser=" user
      if (!p) print "jdbcPassword=" pass
      if (!h) print "databaseDefaultHost=" host
      if (!o) print "databaseDefaultPort=" port
      if (!d) print "databaseDefault=" db
    }
  ' "$pg" >"$tmp"
  mv "$tmp" "$pg"
}

# --- clone -----------------------------------------------------------------

if [[ "$LK_SKIP_CLONE" -eq 0 ]]; then
  mkdir -p "$(dirname "$LK_DIR")"
  clone_or_update "$LK_DIR" server
  clone_or_update "$LK_DIR/server/modules/platform" platform
  clone_or_update "$LK_DIR/server/modules/commonAssays" commonAssays
  clone_or_update "$LK_DIR/server/modules/targetedms" targetedms
  if [[ "$LK_WITH_TESTS" -eq 1 ]]; then
    clone_or_update "$LK_DIR/server/testAutomation" testAutomation
  fi
else
  [[ -d "$LK_DIR" ]] || die "--skip-clone given but $LK_DIR does not exist"
  log "Skipping clone; using $LK_DIR"
fi

[[ -f "$LK_DIR/gradlew" ]] || die "gradlew not found in $LK_DIR"
[[ -f "$LK_DIR/gradle/wrapper/gradle-wrapper.jar" ]] || die "gradle-wrapper.jar not found in $LK_DIR"

patch_gradlew_for_busybox
ensure_user_gradle_properties

# --- compile + stage -------------------------------------------------------

if [[ "$LK_SKIP_BUILD" -eq 1 && "$LK_START" -eq 0 ]]; then
  log "Skip-build requested. Sources are in $LK_DIR"
  exit 0
fi

find_pg_bin() {
  local name="$1" p
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  for p in \
    /usr/pgsql/18/bin/"$name" \
    /usr/pgsql-18/bin/"$name" \
    /usr/lib/postgresql/18/bin/"$name" \
    /usr/bin/"$name"
  do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

ensure_postgres_os_user() {
  if id postgres >/dev/null 2>&1; then
    return 0
  fi
  log "Creating OS user postgres"
  if command -v useradd >/dev/null 2>&1; then
    useradd -r -m -d /var/lib/pgsql -s /bin/bash postgres || true
  fi
  id postgres >/dev/null 2>&1 || die "Could not create OS user postgres (required; the server will not run as root)"
}

as_postgres() {
  if [[ "$(id -u)" -eq 0 ]]; then
    su -s /bin/bash postgres -c "$*"
  else
    sudo -u postgres bash -c "$*"
  fi
}

pg_ready() {
  local ready
  ready="$(find_pg_bin pg_isready || true)"
  [[ -n "$ready" ]] || return 1
  "$ready" -h "$LK_PG_HOST" -p "$LK_PG_PORT" >/dev/null 2>&1
}

dump_pg_failure() {
  log "PostgreSQL failed to listen on ${LK_PG_HOST}:${LK_PG_PORT}"
  log "PGDATA=$LK_PGDATA"
  log "initdb=$(find_pg_bin initdb || echo missing)  pg_ctl=$(find_pg_bin pg_ctl || echo missing)"
  [[ -f "$LK_PGDATA/logfile" ]] && tail -n 40 "$LK_PGDATA/logfile" | sed 's/^/[labkey] pg: /'
  command -v journalctl >/dev/null 2>&1 && \
    journalctl -u postgresql -u postgresql-18 -u postgresql18 --no-pager -n 20 2>/dev/null | sed 's/^/[labkey] journal: /' || true
}

start_postgres() {
  log "Starting PostgreSQL (Photon: dedicated cluster at $LK_PGDATA)"
  ensure_postgres_os_user

  local initdb_bin pg_ctl_bin
  initdb_bin="$(find_pg_bin initdb)" || die "initdb not found. On Photon install the server package: tdnf install -y postgresql18-server"
  pg_ctl_bin="$(find_pg_bin pg_ctl)" || die "pg_ctl not found. tdnf install -y postgresql18-server"

  mkdir -p "$(dirname "$LK_PGDATA")"
  if [[ ! -f "$LK_PGDATA/PG_VERSION" ]]; then
    log "initdb -D $LK_PGDATA"
    rm -rf "$LK_PGDATA"
    mkdir -p "$LK_PGDATA"
    chown -R postgres:postgres "$(dirname "$LK_PGDATA")"
    as_postgres "$initdb_bin -D '$LK_PGDATA' --encoding=UTF8 --locale=C --auth-local=trust --auth-host=scram-sha-256"
    # Allow TCP auth from localhost with a password.
    if [[ -f "$LK_PGDATA/pg_hba.conf" ]]; then
      printf '\nhost all all 127.0.0.1/32 scram-sha-256\nhost all all ::1/128 scram-sha-256\n' >>"$LK_PGDATA/pg_hba.conf"
    fi
    if [[ -f "$LK_PGDATA/postgresql.conf" ]]; then
      sed -i \
        -e "s/^#\\?listen_addresses.*/listen_addresses = '*'/" \
        -e "s/^#\\?port = .*/port = ${LK_PG_PORT}/" \
        "$LK_PGDATA/postgresql.conf"
    fi
    chown -R postgres:postgres "$LK_PGDATA"
  fi

  if pg_ready; then
    log "PostgreSQL already accepting connections on ${LK_PG_HOST}:${LK_PG_PORT}"
    return 0
  fi

  log "pg_ctl start -D $LK_PGDATA"
  as_postgres "$pg_ctl_bin -D '$LK_PGDATA' -l '$LK_PGDATA/logfile' -o '-p ${LK_PG_PORT}' -w start" || true

  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    pg_ready && break
    sleep 1
  done
  if ! pg_ready; then
    dump_pg_failure
    die "PostgreSQL is not accepting connections on ${LK_PG_HOST}:${LK_PG_PORT}"
  fi
  log "PostgreSQL is ready on ${LK_PG_HOST}:${LK_PG_PORT}"
}

provision_database() {
  local psql_bin
  psql_bin="$(find_pg_bin psql)" || die "psql not found"
  log "Ensuring role '$LK_PG_USER' and database '$LK_PG_DATABASE'"
  as_postgres "$psql_bin -p ${LK_PG_PORT} -d postgres -v ON_ERROR_STOP=1" <<SQL || true
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${LK_PG_USER}') THEN
    CREATE ROLE ${LK_PG_USER} LOGIN PASSWORD '${LK_PG_PASSWORD}';
  ELSE
    ALTER ROLE ${LK_PG_USER} WITH LOGIN PASSWORD '${LK_PG_PASSWORD}';
  END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${LK_PG_DATABASE} OWNER ${LK_PG_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${LK_PG_DATABASE}')\gexec
SQL
  log "Database ${LK_PG_DATABASE} is present"
}

find_labkey_jar() {
  # Source deployApp does not produce the binary-distribution name
  # labkeyServer.jar. Spring Boot bootJar is typically embedded.jar
  # (or another single *.jar) under build/deploy/embedded.
  local embed="${LK_DIR}/build/deploy/embedded"
  local jar
  local -a found=()

  # Versioned Spring Boot jar, e.g. embedded-26.7.5.jar
  for jar in \
    "$embed"/embedded-*.jar \
    "$embed/embedded.jar" \
    "$embed/labkeyServer.jar" \
    "$embed/labkey-embedded.jar"
  do
    if [[ -f "$jar" ]]; then
      printf '%s\n' "$jar"
      return 0
    fi
  done

  if [[ -d "$embed" ]]; then
    for jar in "$embed"/*.jar; do
      [[ -f "$jar" ]] && found+=("$jar")
    done
  fi
  if [[ ${#found[@]} -eq 1 ]]; then
    printf '%s\n' "${found[0]}"
    return 0
  fi

  for jar in "${LK_DIR}/server/embedded/build/libs/"*.jar; do
    if [[ -f "$jar" ]]; then
      printf '%s\n' "$jar"
      return 0
    fi
  done
  return 1
}

labkey_http_port() {
  local props="${LK_DIR}/build/deploy/embedded/config/application.properties"
  local port=""
  if [[ -f "$props" ]]; then
    port="$(sed -n 's/^[[:space:]]*server\.port[[:space:]]*=[[:space:]]*//p' "$props" | tail -n 1)"
  fi
  if [[ "$LK_HTTPS" -eq 1 ]]; then
    [[ -n "$port" ]] || port="$LK_HTTPS_PORT"
  else
    [[ -n "$port" ]] || port="$LK_HTTP_PORT"
  fi
  printf '%s\n' "$port"
}

set_prop() {
  local file="$1" key="$2" value="$3"
  [[ -f "$file" ]] || return 1
  if grep -Eq "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i "s|^[[:space:]]*#*[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >>"$file"
  fi
}

ensure_listen_all() {
  local props="${LK_DIR}/build/deploy/embedded/config/application.properties"
  [[ -f "$props" ]] || return 0
  set_prop "$props" server.address 0.0.0.0
  log "Set server.address=0.0.0.0 in application.properties"
}

ensure_keystore() {
  local store="$1"
  local keytool_bin="${JAVA_HOME}/bin/keytool"
  [[ -x "$keytool_bin" ]] || keytool_bin="$(command -v keytool)"
  [[ -x "$keytool_bin" ]] || die "keytool not found (need JDK 25)"

  if [[ -f "$store" ]]; then
    log "Using existing keystore $store"
    return 0
  fi

  local host_ip host_name dname san
  host_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  host_name="$(hostname -f 2>/dev/null || hostname)"
  dname="CN=${host_name},OU=sciCORE,O=University of Basel,C=CH"
  san="DNS:${host_name},DNS:localhost,IP:127.0.0.1"
  [[ -n "$host_ip" ]] && san="${san},IP:${host_ip}"

  mkdir -p "$(dirname "$store")"
  log "Creating self-signed PKCS12 keystore $store (non-interactive)"
  if ! "$keytool_bin" -genkeypair \
    -noprompt \
    -alias tomcat \
    -keyalg RSA \
    -keysize 2048 \
    -validity 3650 \
    -storetype PKCS12 \
    -keystore "$store" \
    -storepass "$LK_KEYSTORE_PASS" \
    -keypass "$LK_KEYSTORE_PASS" \
    -dname "$dname" \
    -ext "SAN=${san}"
  then
    log "keytool SAN failed; retrying without SAN"
    rm -f "$store"
    "$keytool_bin" -genkeypair \
      -noprompt \
      -alias tomcat \
      -keyalg RSA \
      -keysize 2048 \
      -validity 3650 \
      -storetype PKCS12 \
      -keystore "$store" \
      -storepass "$LK_KEYSTORE_PASS" \
      -keypass "$LK_KEYSTORE_PASS" \
      -dname "$dname"
  fi
  [[ -f "$store" ]] || return 1
}

configure_https() {
  local props="${LK_DIR}/build/deploy/embedded/config/application.properties"
  local store="${LK_DIR}/build/deploy/embedded/labkey.p12"
  [[ -f "$props" ]] || die "Missing $props"

  if [[ "$LK_HTTPS" -ne 1 ]]; then
    log "HTTPS disabled (--no-https)"
    set_prop "$props" server.port "$LK_HTTP_PORT"
    set_prop "$props" server.ssl.enabled false
    return 0
  fi

  if ! ensure_keystore "$store"; then
    log "Keystore creation failed; falling back to HTTP on $LK_HTTP_PORT"
    LK_HTTPS=0
    set_prop "$props" server.port "$LK_HTTP_PORT"
    set_prop "$props" server.ssl.enabled false
    return 0
  fi

  set_prop "$props" server.port "$LK_HTTPS_PORT"
  set_prop "$props" server.ssl.enabled true
  set_prop "$props" server.ssl.key-alias tomcat
  set_prop "$props" server.ssl.key-store "$store"
  set_prop "$props" server.ssl.key-store-password "$LK_KEYSTORE_PASS"
  set_prop "$props" server.ssl.key-store-type PKCS12
  set_prop "$props" context.httpPort "$LK_HTTP_PORT"
  log "HTTPS enabled: server.port=$LK_HTTPS_PORT  HTTP also on $LK_HTTP_PORT"
}

stop_existing_labkey() {
  local pids
  pids="$(pgrep -f "${LK_DIR}/build/deploy/embedded|embedded-.*\\.jar|labkeyServer.jar" || true)"
  if [[ -n "$pids" ]]; then
    log "Stopping previous LabKey process(es): $pids"
    kill $pids 2>/dev/null || true
    sleep 2
    kill -9 $pids 2>/dev/null || true
  fi
}

iptables_has_dport() {
  local port="$1"
  iptables -C INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1
}

persist_ip4save() {
  local port="$1"
  local save="/etc/systemd/scripts/ip4save"
  [[ -f "$save" ]] || return 0
  if grep -Eq -- "--dport ${port}( |$)" "$save"; then
    log "ip4save already has tcp dport $port"
    return 0
  fi
  cp -a "$save" "${save}.bak.labkey"
  if grep -Eq -- '--dport 22' "$save"; then
    sed -i "/--dport 22/a -A INPUT -p tcp -m tcp --dport ${port} -j ACCEPT" "$save"
  else
    # Insert before COMMIT if present
    if grep -q '^COMMIT' "$save"; then
      sed -i "/^COMMIT/i -A INPUT -p tcp -m tcp --dport ${port} -j ACCEPT" "$save"
    else
      printf -- '-A INPUT -p tcp -m tcp --dport %s -j ACCEPT\n' "$port" >>"$save"
    fi
  fi
  log "Persisted tcp/$port in $save"
}

open_tcp_port() {
  local port="$1"
  log "Checking firewall for tcp/$port (Photon INPUT is often DROP except 22)"
  if command -v iptables >/dev/null 2>&1; then
    if iptables_has_dport "$port"; then
      log "iptables already accepts tcp/$port"
    else
      if [[ "$(id -u)" -eq 0 ]]; then
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
      else
        sudo iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
      fi
      log "Inserted iptables INPUT accept for tcp/$port"
      persist_ip4save "$port"
    fi
  elif command -v nft >/dev/null 2>&1; then
    nft add rule inet filter input tcp dport "$port" accept 2>/dev/null \
      || log "Could not add nft rule for tcp/$port"
  else
    log "No iptables/nft found; skipping host firewall change for $port"
  fi
}

open_labkey_firewall() {
  if command -v iptables >/dev/null 2>&1; then
    log "iptables INPUT before change:"
    iptables -nvL INPUT 2>/dev/null | sed 's/^/[labkey]   /' || true
  fi
  open_tcp_port "$LK_HTTP_PORT"
  if [[ "$LK_HTTPS" -eq 1 ]]; then
    open_tcp_port "$LK_HTTPS_PORT"
  fi
  if command -v iptables >/dev/null 2>&1; then
    log "iptables INPUT after change:"
    iptables -nvL INPUT 2>/dev/null | sed 's/^/[labkey]   /' || true
  fi
}

write_scicore_logo() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  # Compact header mark (burgundy hex + wordmark). SVG is accepted as a header image.
  cat >"$dest" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="280" height="36" viewBox="0 0 280 36">
  <rect width="280" height="36" fill="none"/>
  <g transform="translate(2,4)">
    <polygon fill="#A51E37" points="14,0 24,6 24,10 14,16 4,10 4,6"/>
    <polygon fill="#C41E3A" points="14,8 24,14 24,18 14,24 4,18 4,14"/>
  </g>
  <text x="34" y="24" font-family="Helvetica, Arial, sans-serif" font-size="18" font-weight="700" fill="#222">sciCORE</text>
  <line x1="138" y1="8" x2="138" y2="28" stroke="#222" stroke-width="1"/>
  <text x="146" y="23" font-family="Helvetica, Arial, sans-serif" font-size="11" fill="#444">University of Basel</text>
</svg>
SVG
}

write_brand_assets() {
  local embed="$1"
  local webapp="${LK_DIR}/build/deploy/labkeyWebapp"
  local mod="${LK_DIR}/build/deploy/modules/scicoreBrand"
  write_scicore_logo "${embed}/scicore-logo.svg"
  write_scicore_logo "${webapp}/_images/scicore-logo.svg"
  write_scicore_logo "${mod}/web/scicoreBrand/logo.svg"
  mkdir -p "${mod}/web/scicoreBrand"
  printf 'Name: scicoreBrand\nLabel: sciCORE branding\nLicense: Apache 2.0\n' >"${mod}/module.properties"
  cat >"${mod}/web/scicoreBrand/brand.css" <<'CSS'
/* Site-wide sciCORE header tint */
.lk-header-bar, .labkey-page-header, header.lk-header-ct {
  border-bottom: 3px solid #A51E37 !important;
}
CSS
  log "Wrote sciCORE logo and brand module under $mod"
}

apply_branding_db() {
  local psql_bin
  psql_bin="$(find_pg_bin psql || true)"
  [[ -n "$psql_bin" ]] || { log "psql not found; skip DB branding"; return 0; }

  local sql
  sql="$(mktemp)"
  cat >"$sql" <<EOF
DO \$\$
DECLARE
  setid integer;
BEGIN
  SELECT s.set INTO setid
  FROM prop.propertysets s
  WHERE s.category IN ('LookAndFeel', 'LookAndFeelProperties', 'LookAndFeelSettings')
  ORDER BY s.set
  LIMIT 1;

  IF setid IS NULL THEN
    RAISE NOTICE 'No LookAndFeel property set yet; startup properties will apply it';
    RETURN;
  END IF;

  PERFORM 1 FROM prop.properties WHERE "set" = setid AND name = 'systemShortName';
  IF FOUND THEN
    UPDATE prop.properties SET value = '${LK_SITE_SHORT_NAME}' WHERE "set" = setid AND name = 'systemShortName';
  ELSE
    INSERT INTO prop.properties ("set", name, value) VALUES (setid, 'systemShortName', '${LK_SITE_SHORT_NAME}');
  END IF;

  PERFORM 1 FROM prop.properties WHERE "set" = setid AND name = 'systemDescription';
  IF FOUND THEN
    UPDATE prop.properties SET value = '${LK_SITE_DESCRIPTION}' WHERE "set" = setid AND name = 'systemDescription';
  ELSE
    INSERT INTO prop.properties ("set", name, value) VALUES (setid, 'systemDescription', '${LK_SITE_DESCRIPTION}');
  END IF;

  PERFORM 1 FROM prop.properties WHERE "set" = setid AND name = 'companyName';
  IF FOUND THEN
    UPDATE prop.properties SET value = '${LK_SITE_ORG}' WHERE "set" = setid AND name = 'companyName';
  ELSE
    INSERT INTO prop.properties ("set", name, value) VALUES (setid, 'companyName', '${LK_SITE_ORG}');
  END IF;

  PERFORM 1 FROM prop.properties WHERE "set" = setid AND name = 'themeName';
  IF FOUND THEN
    UPDATE prop.properties SET value = '${LK_SITE_THEME}' WHERE "set" = setid AND name = 'themeName';
  ELSE
    INSERT INTO prop.properties ("set", name, value) VALUES (setid, 'themeName', '${LK_SITE_THEME}');
  END IF;

  PERFORM 1 FROM prop.properties WHERE "set" = setid AND name = 'systemEmailAddress';
  IF FOUND THEN
    UPDATE prop.properties SET value = '${LK_SITE_EMAIL}' WHERE "set" = setid AND name = 'systemEmailAddress';
  ELSE
    INSERT INTO prop.properties ("set", name, value) VALUES (setid, 'systemEmailAddress', '${LK_SITE_EMAIL}');
  END IF;

  PERFORM 1 FROM prop.properties WHERE "set" = setid AND name = 'reportAProblemPath';
  IF FOUND THEN
    UPDATE prop.properties SET value = 'https://scicore.unibas.ch/' WHERE "set" = setid AND name = 'reportAProblemPath';
  ELSE
    INSERT INTO prop.properties ("set", name, value) VALUES (setid, 'reportAProblemPath', 'https://scicore.unibas.ch/');
  END IF;
END
\$\$;
SELECT s.category, p.name, p.value
FROM prop.propertysets s
JOIN prop.properties p ON p.set = s.set
WHERE s.category ILIKE '%LookAndFeel%'
ORDER BY p.name;
EOF

  log "Applying Look and Feel in database ${LK_PG_DATABASE}"
  if [[ "$(id -u)" -eq 0 ]]; then
    su -s /bin/bash postgres -c "$psql_bin -d ${LK_PG_DATABASE} -v ON_ERROR_STOP=1 -f $sql" \
      | sed 's/^/[labkey]   /' || log "DB branding update failed (ok if first boot has no property set yet)"
  else
    sudo -u postgres "$psql_bin" -d "${LK_PG_DATABASE}" -v ON_ERROR_STOP=1 -f "$sql" \
      | sed 's/^/[labkey]   /' || log "DB branding update failed (ok if first boot has no property set yet)"
  fi
  rm -f "$sql"
}

configure_look_and_feel() {
  local embed="$1" host_ip="$2"
  local scheme="http" port="$LK_HTTP_PORT"
  if [[ "$LK_HTTPS" -eq 1 ]]; then
    scheme="https"
    port="$LK_HTTPS_PORT"
  fi

  write_startup_props() {
    local props="$1"
    mkdir -p "$(dirname "$props")"
    cat >"$props" <<EOF
LookAndFeelSettings.systemShortName;startup=${LK_SITE_SHORT_NAME}
LookAndFeelSettings.systemDescription;startup=${LK_SITE_DESCRIPTION}
LookAndFeelSettings.companyName;startup=${LK_SITE_ORG}
LookAndFeelSettings.systemEmailAddress;startup=${LK_SITE_EMAIL}
LookAndFeelSettings.themeName;startup=${LK_SITE_THEME}
LookAndFeelSettings.reportAProblemPath;startup=https://scicore.unibas.ch/
LookAndFeelSettings.logoHref;startup=${scheme}://${host_ip}:${port}/home/project-begin.view
SiteSettings.baseServerURL;startup=${scheme}://${host_ip}:${port}
SiteSettings.sslRequired;startup=$([ "$LK_HTTPS" -eq 1 ] && echo true || echo false)
EOF
  }

  # LabKey reads <LABKEY_HOME>/startup. Source builds use the embedded dir.
  write_startup_props "${embed}/startup/00_scicore.properties"
  write_startup_props "${LK_DIR}/build/deploy/startup/00_scicore.properties"
  write_brand_assets "$embed"
  apply_branding_db
  log "Look and Feel: ${LK_SITE_SHORT_NAME} / ${LK_SITE_ORG}"
}

start_labkey() {
  local embed="${LK_DIR}/build/deploy/embedded"
  local props="$embed/config/application.properties"
  local jar java_bin port
  [[ -d "$embed" ]] || die "Staged tree missing: $embed (build first)"
  [[ -f "$props" ]] || die "Missing $props — run pickPg / deployApp first"
  stop_existing_labkey
  ensure_listen_all
  configure_https
  open_labkey_firewall
  port="$(labkey_http_port)"
  jar="$(find_labkey_jar || true)"
  java_bin="${JAVA_HOME}/bin/java"
  is_jdk25 "$java_bin" || die "Need JDK 25 to start LabKey (have $java_bin)"

  if [[ -z "$jar" ]]; then
    log "No executable jar in $embed (source deployApp uses embedded.jar, not labkeyServer.jar)"
    log "Contents of $embed:"
    ls -la "$embed" 2>/dev/null | sed 's/^/[labkey]   /' || true
    log "Falling back to Gradle startTomcat"
    cd "$LK_DIR"
    run_gradle startTomcat
    return 0
  fi

  log "Config: $props"
  grep -E 'jdbcUser|jdbcPassword|jdbcURL|encryptionKey|server.port|server.ssl|context.httpPort|server.address' "$props" \
    | sed 's/password=.*/password=***/' \
    | sed 's/^/[labkey]   /' || true

  mkdir -p "$embed/logs"
  cd "$embed"

  # BusyBox hostname has no -I; with pipefail that used to abort the script.
  local host_ip=""
  host_ip="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4; exit}' | cut -d/ -f1)" || true
  [[ -n "$host_ip" ]] || host_ip="$(hostname 2>/dev/null)" || true
  [[ -n "$host_ip" ]] || host_ip="127.0.0.1"

  configure_look_and_feel "$embed" "$host_ip"

  local -a cmd=(
    "$java_bin"
    -Xms1G -Xmx2G
    --add-opens=java.base/java.io=ALL-UNNAMED
    --add-opens=java.base/java.lang=ALL-UNNAMED
    --add-opens=java.base/java.nio=ALL-UNNAMED
    --add-opens=java.base/java.util=ALL-UNNAMED
    -Ddevmode=true
    -Dfile.encoding=UTF-8
    "-Dlabkey.prop.LookAndFeelSettings.systemShortName;startup=${LK_SITE_SHORT_NAME}"
    "-Dlabkey.prop.LookAndFeelSettings.systemDescription;startup=${LK_SITE_DESCRIPTION}"
    "-Dlabkey.prop.LookAndFeelSettings.companyName;startup=${LK_SITE_ORG}"
    "-Dlabkey.prop.LookAndFeelSettings.systemEmailAddress;startup=${LK_SITE_EMAIL}"
    "-Dlabkey.prop.LookAndFeelSettings.themeName;startup=${LK_SITE_THEME}"
    -jar "$jar"
  )

  log "Starting LabKey from $embed"
  log "Jar: $jar"
  if [[ "$LK_HTTPS" -eq 1 ]]; then
    log "HTTPS: https://${host_ip}:${LK_HTTPS_PORT}/  (self-signed; browser warning is expected)"
    log "HTTP:  http://${host_ip}:${LK_HTTP_PORT}/"
  else
    log "HTTP only: http://${host_ip}:${port}/"
  fi
  log "First visit creates the site-admin account."

  if [[ "$LK_DAEMON" -eq 1 ]]; then
    nohup "${cmd[@]}" >>"$embed/logs/console.log" 2>&1 &
    log "LabKey pid $!  logs: $embed/logs/console.log"
  else
    exec "${cmd[@]}"
  fi
}

if [[ "$LK_SKIP_BUILD" -eq 0 ]]; then
  configure_pg_properties

  cd "$LK_DIR"

  log "Selecting PostgreSQL config (gradlew pickPg)"
  run_gradle pickPg

  if [[ "$LK_PROD" -eq 1 ]]; then
    log "Production-mode compile and stage (gradlew deployApp -PdeployMode=prod)"
    run_gradle deployApp -PdeployMode=prod
  else
    log "Development compile and stage (gradlew deployApp)"
    run_gradle deployApp
  fi

  cat <<EOF

[labkey] Build complete.

  Sources:   $LK_DIR
  Branch:    $LK_BRANCH
  Staged:    $LK_DIR/build/deploy
  Config:    $LK_DIR/build/deploy/embedded/config/application.properties

EOF
fi

if [[ "$LK_START" -eq 1 ]]; then
  start_postgres
  provision_database
  start_labkey
fi
