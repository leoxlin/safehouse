#!/usr/bin/env bash
# Notify the tmux window running this Claude Code session when it needs
# attention. Registered for the Notification and Stop hook events in
# settings.json; branches on hook_event_name read from the hook JSON on stdin.
#
# In tmux: writes a bell to the session's pane (monitor-bell flags the window
# in the status bar, so you can see which window needs you even from another
# window), flashes a message on the status line, and sends a desktop
# notification.
# Outside tmux: falls back to a notify-send desktop notification.
#
# Note: the desktop notification is only emitted when the current tmux window
# is not active. tmux's #{window_active} tracks focus *within* tmux; it cannot
# tell whether the terminal emulator window itself is minimized or hidden, but
# it is the only reliable cross-platform signal we have. To avoid spam, all
# Claude Code sessions share a single notification ID, so new notifications
# replace the previous one instead of stacking.
set -u

# Stable notification ID shared across all Claude Code sessions.
NOTIFY_ID=$(printf '%s' 'Claude Code' | cksum | cut -d' ' -f1)

json=$(cat)
event=$(printf '%s' "$json" | jq -r '.hook_event_name // empty' 2>/dev/null)

# Extract the session summary from hook JSON
extract_summary() {
  printf '%s' "$json" | jq -r '.summary // .session_summary // empty' 2>/dev/null
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

# Build the notification body from the session summary
build_notify_body() {
  local summary
  summary=$(extract_summary)

  [ -n "$summary" ] && printf '📝 %s' "$summary"
}

# Check if we're in an active (visible/focused) tmux window
tmux_window_active() {
  [ -z "${TMUX:-}" ] && return 1
  command -v tmux >/dev/null 2>&1 || return 1

  local window_active
  window_active=$(tmux display-message -p '#{window_active}' 2>/dev/null)

  [ "$window_active" = "1" ]
}

# Send desktop notification via notify-send, replacing any existing
# Claude Code notification so they never stack.
send_desktop_notify() {
  command -v notify-send >/dev/null 2>&1 || return 0

  local body
  body=$(build_notify_body)

  if [ -n "$body" ]; then
    notify-send --urgency="$urgency" --app-name="Claude Code" --replace-id="$NOTIFY_ID" "$msg" "$body" 2>/dev/null
  else
    notify-send --urgency="$urgency" --app-name="Claude Code" --replace-id="$NOTIFY_ID" "$msg" 2>/dev/null
  fi
}

# Inside tmux: always bell + status message
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tty=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_tty}' 2>/dev/null)
  [ -n "$tty" ] && printf '\a' >"$tty" 2>/dev/null
  tmux display-message -t "${TMUX_PANE:-}" "$msg" 2>/dev/null

  # Also send desktop notification if tmux window is not active
  if ! tmux_window_active; then
    send_desktop_notify
  fi
else
  # Outside tmux: just desktop notification
  send_desktop_notify
fi

exit 0
