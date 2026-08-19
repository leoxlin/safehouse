# Mirror tmux automatic-rename: tab title shows the shell name at the
# prompt and the running command's name while a command executes.

function _title_precmd() {
  print -Pn "\e]0;${SHELL:t}\a"
}

function _title_preexec() {
  local cmd="${1%%[[:space:]]*}" # first word of the command line
  print -Pn "\e]0;${cmd:t}\a"    # basename, like tmux pane_current_command
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _title_precmd
add-zsh-hook preexec _title_preexec
