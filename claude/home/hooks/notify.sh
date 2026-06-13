#!/usr/bin/env bash
# Notify the tmux window running this Claude Code session when it needs
# attention. Registered for the Notification and Stop hook events in
# settings.json; branches on hook_event_name read from the hook JSON on stdin.
#
# In tmux: writes a bell to the session's pane (monitor-bell flags the window
# in the status bar, so you can see which window needs you even from another
# window) and flashes a message on the status line.
# Outside tmux: falls back to a notify-send desktop notification.
# If tmux window is not active: also sends notify-send with repo/branch context.
set -u

json=$(cat)
event=$(printf '%s' "$json" | jq -r '.hook_event_name // empty' 2>/dev/null)

# Extract context from hook JSON
extract_context() {
  local repo branch path summary
  repo=$(printf '%s' "$json" | jq -r '.repository_name // .project_name // empty' 2>/dev/null)
  branch=$(printf '%s' "$json" | jq -r '.git_branch // empty' 2>/dev/null)
  path=$(printf '%s' "$json" | jq -r '.current_path // .project_path // empty' 2>/dev/null)
  summary=$(printf '%s' "$json" | jq -r '.summary // .session_summary // empty' 2>/dev/null)

  # Fallback: detect from environment
  if [ -z "$repo" ] && [ -d ".git" ]; then
    repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" || echo "")
  fi
  if [ -z "$branch" ]; then
    branch=$(git branch --show-current 2>/dev/null || echo "")
  fi
  if [ -z "$path" ]; then
    path=$(pwd)
  fi

  printf '%s|%s|%s|%s' "$repo" "$branch" "$path" "$summary"
}

case "$event" in
  Stop)
    msg="✅ Claude: Response complete"
    urgency="normal"
    ;;
  *)
    detail=$(printf '%s' "$json" | jq -r '.message // empty' 2>/dev/null)
    msg="🔔 Claude: ${detail:-Input needed}"
    urgency="critical"
    ;;
esac

# Build context-rich notification body
build_notify_body() {
  local ctx repo branch path summary
  ctx=$(extract_context)
  repo=$(echo "$ctx" | cut -d'|' -f1)
  branch=$(echo "$ctx" | cut -d'|' -f2)
  path=$(echo "$ctx" | cut -d'|' -f3)
  summary=$(echo "$ctx" | cut -d'|' -f4)

  local body=""
  [ -n "$repo" ] && body="📁 $repo"
  [ -n "$branch" ] && body="${body}${body:+, }⎇ $branch"
  [ -n "$path" ] && body="${body}\n📂 $path"
  [ -n "$summary" ] && body="${body}\n📝 $summary"

  printf '%s' "$body"
}

# Check if we're in an active (visible/focused) tmux window
tmux_window_active() {
  [ -z "${TMUX:-}" ] && return 1
  command -v tmux >/dev/null 2>&1 || return 1

  local window_active
  window_active=$(tmux display-message -p '#{window_active}' 2>/dev/null)

  [ "$window_active" = "1" ]
}

# Send desktop notification via notify-send
send_desktop_notify() {
  command -v notify-send >/dev/null 2>&1 || return 0

  local body
  body=$(build_notify_body)

  if [ -n "$body" ]; then
    notify-send --urgency="$urgency" --app-name="Claude Code" "$msg" "$body" 2>/dev/null
  else
    notify-send --urgency="$urgency" --app-name="Claude Code" "$msg" 2>/dev/null
  fi
}

# Inside tmux: always bell + status message
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tty=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_tty}' 2>/dev/null)
  [ -n "$tty" ] && printf '\a' >"$tty" 2>/dev/null
  tmux display-message -t "${TMUX_PANE:-}" "$msg" 2>/dev/null

  # Also send desktop notification if window is not active
  if ! tmux_window_active; then
    send_desktop_notify
  fi
else
  # Outside tmux: just desktop notification
  send_desktop_notify
fi

exit 0
