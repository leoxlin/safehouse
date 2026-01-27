function _set_terminal_title() {
  print -Pn "\e]0;Ghostty\a"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _set_terminal_title
