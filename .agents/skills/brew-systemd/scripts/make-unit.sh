#!/usr/bin/env bash
#
# make-unit.sh — turn a Homebrew-installed command into a systemd *user* unit.
#
# Generates (and by default installs + starts) a unit under
# ${XDG_CONFIG_HOME:-~/.config}/systemd/user/. Two shapes:
#   - long-running daemon  -> Type=simple service, Restart=on-failure
#   - scheduled job        -> Type=oneshot service + a .timer (--timer)
#
# The first token of COMMAND is resolved to an ABSOLUTE path (systemd has no
# brew on PATH), preferring the Homebrew prefix. The service's own PATH is set
# to include brew's bin so the command can find its sibling brew tools.
#
# Usage:
#   make-unit.sh --name NAME [opts] -- COMMAND [ARGS...]
#
# Options:
#   --name NAME           unit base name (required), e.g. "syncthing"
#   --description TEXT     Description= line (default: derived from NAME)
#   --timer SCHEDULE      make it a oneshot + timer; SCHEDULE is an OnCalendar
#                         value, e.g. "daily", "*-*-* 03:00:00", "hourly"
#   --persistent          (timer only) add Persistent=true to catch up missed runs
#   --working-dir DIR     WorkingDirectory= for the service
#   --env KEY=VAL         add an Environment= line (repeatable)
#   --restart POLICY      Restart= for daemons (default: on-failure)
#   --no-enable           write + daemon-reload only; do not enable/start
#   --dry-run             print the unit(s) to stdout; write nothing
#   -- COMMAND [ARGS...]  everything after -- is the command to run
#
# Examples:
#   make-unit.sh --name syncthing -- syncthing --no-browser
#   make-unit.sh --name backup --timer daily --persistent -- restic backup ~
#
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

# Linux only — systemd user units don't exist elsewhere.
[[ "$(uname -s)" == "Linux" ]] || die "this skill only works on Linux (systemd); host is $(uname -s)"

NAME=""
DESC=""
TIMER=""
PERSISTENT=0
WORKDIR=""
RESTART="on-failure"
ENABLE=1
DRYRUN=0
declare -a ENVS=()

# --- parse args -------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)        NAME="${2:-}"; shift 2 ;;
    --description) DESC="${2:-}"; shift 2 ;;
    --timer)       TIMER="${2:-}"; shift 2 ;;
    --persistent)  PERSISTENT=1; shift ;;
    --working-dir) WORKDIR="${2:-}"; shift 2 ;;
    --env)         ENVS+=("${2:-}"); shift 2 ;;
    --restart)     RESTART="${2:-}"; shift 2 ;;
    --no-enable)   ENABLE=0; shift ;;
    --dry-run)     DRYRUN=1; shift ;;
    --)            shift; break ;;
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *)             die "unknown option: $1 (did you forget -- before the command?)" ;;
  esac
done

[[ -n "${NAME}" ]] || die "--name is required"
[[ $# -gt 0 ]]     || die "no command given (put it after --)"
[[ "${NAME}" =~ ^[A-Za-z0-9._-]+$ ]] || die "--name must be a valid unit name (alnum . _ -)"

# --- resolve the command to an absolute path --------------------------------
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /home/linuxbrew/.linuxbrew)"
BREW_BIN="${BREW_PREFIX}/bin"
SEARCH_PATH="${BREW_BIN}:${BREW_PREFIX}/sbin:${PATH}"

cmd="$1"; shift
if [[ "${cmd}" == /* ]]; then
  EXEC="${cmd}"
else
  EXEC="$(PATH="${SEARCH_PATH}" command -v "${cmd}" || true)"
fi
[[ -n "${EXEC}" && -x "${EXEC}" ]] || die "could not resolve '${cmd}' to an executable (searched brew prefix + PATH)"

# Build a properly-quoted ExecStart from the resolved path + remaining args.
exec_start="${EXEC}"
for a in "$@"; do
  exec_start+=" $(printf '%q' "$a")"
done

[[ -n "${DESC}" ]] || DESC="${NAME} (brew) user service"

UNIT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"

# --- assemble the service unit ----------------------------------------------
build_service() {
  local svc_type after install
  if [[ -n "${TIMER}" ]]; then
    svc_type="oneshot"; install=""           # timer pulls it in; no [Install]
  else
    svc_type="simple";  install="WantedBy=default.target"
  fi

  printf '[Unit]\n'
  printf 'Description=%s\n' "${DESC}"
  printf 'After=network-online.target\n'
  printf 'Wants=network-online.target\n'
  printf '\n[Service]\n'
  printf 'Type=%s\n' "${svc_type}"
  printf 'ExecStart=%s\n' "${exec_start}"
  printf 'Environment=PATH=%s\n' "${BREW_BIN}:${BREW_PREFIX}/sbin:/usr/local/bin:/usr/bin:/bin"
  printf 'Environment=HOMEBREW_PREFIX=%s\n' "${BREW_PREFIX}"
  local e
  for e in "${ENVS[@]:-}"; do
    [[ -n "${e}" ]] && printf 'Environment=%s\n' "${e}"
  done
  [[ -n "${WORKDIR}" ]] && printf 'WorkingDirectory=%s\n' "${WORKDIR}"
  if [[ "${svc_type}" == simple ]]; then
    printf 'Restart=%s\n' "${RESTART}"
    printf 'RestartSec=5\n'
  fi
  if [[ -n "${install}" ]]; then
    printf '\n[Install]\n%s\n' "${install}"
  fi
}

# --- assemble the timer unit ------------------------------------------------
build_timer() {
  printf '[Unit]\n'
  printf 'Description=Timer for %s\n' "${DESC}"
  printf '\n[Timer]\n'
  printf 'OnCalendar=%s\n' "${TIMER}"
  [[ "${PERSISTENT}" -eq 1 ]] && printf 'Persistent=true\n'
  printf '\n[Install]\nWantedBy=timers.target\n'
}

SERVICE_FILE="${UNIT_DIR}/${NAME}.service"
TIMER_FILE="${UNIT_DIR}/${NAME}.timer"

if [[ "${DRYRUN}" -eq 1 ]]; then
  echo "# ${SERVICE_FILE}"
  build_service
  if [[ -n "${TIMER}" ]]; then
    echo; echo "# ${TIMER_FILE}"
    build_timer
  fi
  exit 0
fi

mkdir -p "${UNIT_DIR}"
build_service > "${SERVICE_FILE}"
echo "wrote ${SERVICE_FILE}"
if [[ -n "${TIMER}" ]]; then
  build_timer > "${TIMER_FILE}"
  echo "wrote ${TIMER_FILE}"
fi

systemctl --user daemon-reload

if [[ "${ENABLE}" -eq 1 ]]; then
  if [[ -n "${TIMER}" ]]; then
    systemctl --user enable --now "${NAME}.timer"
    echo "enabled + started ${NAME}.timer"
    systemctl --user list-timers --all "${NAME}.timer" --no-pager || true
  else
    systemctl --user enable --now "${NAME}.service"
    echo "enabled + started ${NAME}.service"
    systemctl --user --no-pager status "${NAME}.service" || true
  fi
else
  echo "wrote units and reloaded; not enabled (--no-enable)"
fi

# --- linger reminder --------------------------------------------------------
if [[ "$(loginctl show-user "${USER}" -p Linger --value 2>/dev/null)" != "yes" ]]; then
  echo
  echo "NOTE: lingering is OFF — user services stop when you log out."
  echo "      To keep them running headless, run:  sudo loginctl enable-linger ${USER}"
fi
