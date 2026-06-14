function git_worktree_add() {
  if [ -z "$1" ]; then
    echo "You must provide a branch name for worktree"
  elif [ -d "$(pwd)/.git" ]; then
    git worktree add -b "$1" "$HOME/Worktrees/$(openssl rand -hex 4 | cut -c1-7)/$(git name)" "$(git default)"
  elif [ -f "$(pwd)/.git" ]; then
    cd "$(git parent)" && \
    git worktree add -b "$1" "$HOME/Worktrees/$(openssl rand -hex 4 | cut -c1-7)/$(git name)" "$(git default)"
  else
    echo 'fatal: not a git repository (or any parent up to mount point /)'
  fi
}
