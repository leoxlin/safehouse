# Executables and symbolic links as red
LS_COLORS=$LS_COLORS:'ex=0;31:'
LS_COLORS=$LS_COLORS:'ln=0;31:'
export LS_COLORS

# Allow large history size and saved history
SAVEHIST=50000000000000
HISTSIZE=10000000000000
HISTFILE=~/.zsh_history

# Modern history options
setopt EXTENDED_HISTORY          # Write timestamp to history
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicates first
setopt HIST_FIND_NO_DUPS         # Don't display duplicates during search
setopt HIST_IGNORE_DUPS          # Don't record duplicate consecutive commands
setopt HIST_IGNORE_SPACE         # Don't record commands starting with space
setopt HIST_VERIFY               # Show command with history expansion before running
setopt SHARE_HISTORY             # Share history between sessions

# Modification bindings
bindkey -e
bindkey '^R' history-incremental-pattern-search-backward
bindkey '^Xa' beginning-of-line
