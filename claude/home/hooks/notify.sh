#!/usr/bin/env bash
# Notify the tmux window running this Claude Code session when it needs
# attention. Registered for the Notification and Stop hook events in
# settings.json; branches on hook_event_name read from the hook JSON on stdin.
#
# In tmux: writes a bell to the session's pane (monitor-bell flags the window
# in the status bar, so you can see which window needs you even from another
# window) and flashes a message on the status line.
# Outside tmux: falls back to a notify-send desktop notification.
set -u

json=$(cat)
event=$(printf '%s' "$json" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$event" in
  Stop)
    msg="✅ Claude: Response complete"
    ;;
  *)
    detail=$(printf '%s' "$json" | jq -r '.message // empty' 2>/dev/null)
    msg="🔔 Claude: ${detail:-Input needed}"
    ;;
esac

if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  tty=$(tmux display-message -p -t "${TMUX_PANE:-}" '#{pane_tty}' 2>/dev/null)
  [ -n "$tty" ] && printf '\a' >"$tty" 2>/dev/null
  tmux display-message -t "${TMUX_PANE:-}" "$msg" 2>/dev/null
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code" "$msg" 2>/dev/null
fi

exit 0
