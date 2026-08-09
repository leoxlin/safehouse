#!/usr/bin/env bash
#
# audit.sh — read-only comparison of a Brewfile against the machine's actual
# Homebrew state. Mutates nothing; safe to run unattended.
#
# Usage: audit.sh [path/to/Brewfile]
#   Defaults to ./Brewfile, then ~/Source/safehouse/Brewfile.

set -euo pipefail

BREWFILE="${1:-}"
if [[ -z "${BREWFILE}" ]]; then
  if [[ -f Brewfile ]]; then
    BREWFILE="Brewfile"
  elif [[ -f "${HOME}/Source/safehouse/Brewfile" ]]; then
    BREWFILE="${HOME}/Source/safehouse/Brewfile"
  fi
fi
[[ -f "${BREWFILE}" ]] || { echo "Brewfile not found; pass its path as the first arg." >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# --- parse the Brewfile -----------------------------------------------------
grep -oE "brew '[^']+'" "${BREWFILE}" | sed "s/brew '//;s/'//" | sort -u > "${tmp}/bf_brews" || true
grep -oE "cask '[^']+'" "${BREWFILE}" | sed "s/cask '//;s/'//" | sort -u > "${tmp}/bf_casks" || true

# Taps the Brewfile depends on: explicit `tap '...'` lines, plus the org/name
# implied by any fully-qualified `brew 'org/name/formula'` entry.
{
  grep -oE "tap '[^']+'" "${BREWFILE}" | sed "s/tap '//;s/'//" || true
  awk -F"'" '/brew |cask /{print $2}' "${BREWFILE}" | awk -F/ 'NF>=3{print $1"/"$2}'
} | sort -u > "${tmp}/bf_taps"

# --- current Homebrew state -------------------------------------------------
brew leaves --installed-on-request 2>/dev/null | sort -u > "${tmp}/leaves"
brew list --cask 2>/dev/null | sort -u > "${tmp}/casks"
brew tap 2>/dev/null | sort -u > "${tmp}/taps"

# Known alias: the `git-delta` formula installs as `delta`. If the Brewfile
# tracks it as `delta`, treat the installed `git-delta` leaf as covered.
if grep -qx 'delta' "${tmp}/bf_brews" && grep -qx 'git-delta' "${tmp}/leaves"; then
  grep -vx 'git-delta' "${tmp}/leaves" > "${tmp}/leaves.x" && mv "${tmp}/leaves.x" "${tmp}/leaves"
  echo delta >> "${tmp}/leaves"
  sort -u "${tmp}/leaves" -o "${tmp}/leaves"
fi

# Report installed packages belonging to a tap. NOTE: `brew list --full-name`
# is unreliable for tap-prefixed packages, so walk the tap's .rb files instead.
list_tap_installed() {
  local tap="$1" org name dir found=0 b
  org="${tap%%/*}"; name="${tap#*/}"
  dir="$(brew --repository)/Library/Taps/${org}/homebrew-${name}"
  [[ -d "${dir}" ]] || { echo "  (tap directory missing)"; return; }
  while IFS= read -r f; do
    b="$(basename "${f}" .rb)"
    if brew list --versions "${b}" >/dev/null 2>&1; then
      echo "  installed: ${b}"
      found=1
    fi
  done < <(find "${dir}" -name '*.rb' 2>/dev/null)
  [[ "${found}" -eq 0 ]] && echo "  (nothing installed — safe to untap)"
  return 0
}

echo "Brewfile: ${BREWFILE}"
echo

echo "== Explicitly installed but MISSING from Brewfile (not dependencies) =="
comm -23 "${tmp}/leaves" "${tmp}/bf_brews" | sed 's/^/  + /' || true
echo

echo "== Casks installed but missing from Brewfile =="
comm -23 "${tmp}/casks" "${tmp}/bf_casks" | sed 's/^/  + /' || true
echo

echo "== Taps present but NOT referenced by Brewfile =="
while IFS= read -r t; do
  [[ -z "${t}" ]] && continue
  echo "  ${t}"
  list_tap_installed "${t}"
done < <(comm -23 "${tmp}/taps" "${tmp}/bf_taps")
echo

echo "== Deprecated / disabled installed formulae =="
if command -v jq >/dev/null 2>&1; then
  brew info --json=v2 --installed 2>/dev/null | jq -r '
    .formulae[]
    | select(.deprecated or .disabled)
    | "  \(.name) — \(if .disabled then "DISABLED" else "deprecated" end)\(if .deprecation_reason then " (" + (.deprecation_reason|tostring) + ")" else "" end)"
  ' || echo "  (none)"
else
  brew doctor 2>&1 | sed -n '/deprecated or disabled/,/^$/p' || true
fi
echo

echo "== Outdated packages =="
brew outdated 2>/dev/null | sed 's/^/  /' || true
echo

echo "== brew bundle check (are Brewfile deps satisfied?) =="
brew bundle check --file="${BREWFILE}" 2>&1 | sed 's/^/  /' || true
