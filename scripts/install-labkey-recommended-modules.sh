#!/usr/bin/env bash
# install-labkey-recommended-modules.sh
#
# Clone extra Community-usable LabKey modules into an existing enlistment
# and rebuild so they are staged. Does NOT install Premium modules
# (Sample Manager, LDAP, SAML, compliance, limsModules/inventory).
#
# Recommended set (active public repos, generally useful on a collab server):
#   targetedms          Panorama / Skyline targeted MS
#   LabDevKitModules    LDK + Laboratory (dependency of many research modules)
#   DiscvrLabKeyModules Bimber Lab / OHSU public research modules
#
# Usage:
#   ./install-labkey-recommended-modules.sh --dir /root/scicore --branch release26.7
#   ./install-labkey-recommended-modules.sh --dir /root/scicore --skip-build
#
set -euo pipefail

LK_DIR="${LK_DIR:-$HOME/src/labkeyEnlistment}"
LK_BRANCH="${LK_BRANCH:-develop}"
LK_SKIP_BUILD=0
REMOTE_BASE="https://github.com/LabKey"

# repo -> destination under $LK_DIR
# Destinations are under server/modules so default settings.gradle picks them up.
RECOMMENDED_REPOS=(
  "targetedms|server/modules/targetedms"
  "LabDevKitModules|server/modules/LabDevKitModules"
  "DiscvrLabKeyModules|server/modules/DiscvrLabKeyModules"
)

usage() {
  cat <<'EOF'
Clone highly recommended public LabKey modules and rebuild the enlistment.

Options:
  --dir DIR       Existing enlistment (default: $HOME/src/labkeyEnlistment)
  --branch NAME   Branch/tag to check out in each extra repo (default: develop)
  --skip-build    Clone only; do not run deployApp
  -h, --help      Show this help

These modules are Apache-licensed or otherwise published as public source.
They are not a substitute for LabKey Premium (Sample Manager, LDAP/SAML, ETLs
as a licensed product, inventory/limsModules).
EOF
}

log() { printf '[labkey-mods] %s\n' "$*"; }
die() { printf '[labkey-mods] ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)        LK_DIR="$2"; shift 2 ;;
    --branch)     LK_BRANCH="$2"; shift 2 ;;
    --skip-build) LK_SKIP_BUILD=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown option: $1" ;;
  esac
done

[[ -d "$LK_DIR" ]] || die "Enlistment not found: $LK_DIR"
[[ -f "$LK_DIR/gradlew" ]] || die "Not a LabKey enlistment (no gradlew): $LK_DIR"
command -v git >/dev/null 2>&1 || die "git is required"

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
    log "Updating $repo ($LK_BRANCH)"
    git -C "$dest" fetch --prune origin
    git -C "$dest" checkout "$LK_BRANCH"
    git -C "$dest" pull --ff-only origin "$LK_BRANCH" || \
      log "Fast-forward failed for $repo; left at $(git -C "$dest" rev-parse --short HEAD)"
  else
    log "Cloning $repo -> $dest"
    mkdir -p "$(dirname "$dest")"
    if ! git clone --branch "$LK_BRANCH" --single-branch "$(github_url "$repo")" "$dest"; then
      log "Branch $LK_BRANCH missing on $repo; cloning default branch"
      git clone "$(github_url "$repo")" "$dest"
    fi
  fi
}

for spec in "${RECOMMENDED_REPOS[@]}"; do
  repo="${spec%%|*}"
  rel="${spec#*|}"
  clone_or_update "$LK_DIR/$rel" "$repo"
done

log "Modules now under $LK_DIR/server/modules:"
ls -1 "$LK_DIR/server/modules" | sed 's/^/[labkey-mods]   /'

if [[ "$LK_SKIP_BUILD" -eq 1 ]]; then
  log "Skip-build. Next: rebuild with build-labkey-community.sh --dir $LK_DIR --skip-clone"
  exit 0
fi

builder="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/build-labkey-community.sh"
if [[ -x "$builder" ]]; then
  log "Rebuilding via $builder --skip-clone"
  exec "$builder" --dir "$LK_DIR" --branch "$LK_BRANCH" --skip-clone --no-start
fi

die "build-labkey-community.sh not found next to this script. Run it with --skip-clone after the clones."
