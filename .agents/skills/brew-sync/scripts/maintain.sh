#!/usr/bin/env bash
#
# maintain.sh — routine Homebrew maintenance that needs no human input.
# Runs update, upgrade, autoremove, cleanup, then prints `brew doctor`.
#
# Does NOT uninstall anything or touch the Brewfile — those decisions are
# interactive and handled by the skill, not here.

set -euo pipefail

echo "==> brew update";     brew update
echo "==> brew upgrade";    brew upgrade
echo "==> brew autoremove"; brew autoremove
echo "==> brew cleanup";    brew cleanup
echo "==> brew doctor";     brew doctor || true   # doctor exits non-zero on warnings
