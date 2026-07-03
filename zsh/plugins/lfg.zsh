# lfg: jump into a worktree and start an agent.
#
# Usage: lfg [entrypoint] [branch_name]
#
# - entrypoint: the command to run once inside the worktree (default: claude).
#     lfg               -> claude in a picked branch
#     lfg codex         -> codex in a picked branch
#     lfg claude feat/x -> claude in worktree for branch feat/x
# - Outside a git repo: pick one from ~/Source via fzf (type to filter).
# - With no branch: pick an existing worktree branch, or type a new name to
#   create one.
# - Creates/switches the worktree (under ~/Source/.agents/worktrees, via the
#   worktree helper) and launches the entrypoint there.

function _lfg_pick_repo() {
  local repo

  repo="$(find "$HOME/Source" -mindepth 1 -maxdepth 1 -type d \
      -exec test -e '{}/.git' ';' -print 2>/dev/null \
    | sort \
    | fzf --prompt='repo> ' --height=40% --reverse \
        --delimiter=/ --with-nth=-1)" || return 1

  [ -n "$repo" ] || return 1
  echo "$repo"
}

function _lfg_pick_branch() {
  local out code branch

  out="$(git worktree list --porcelain \
    | awk '/^branch / { sub("refs/heads/", "", $2); print $2 }' \
    | fzf --print-query --prompt='branch> ' --height=40% --reverse)"
  code=$?

  # 0 = picked existing, 1 = no match (create new); anything else = aborted.
  [ "$code" -eq 0 ] || [ "$code" -eq 1 ] || return 1

  branch="$(printf '%s\n' "$out" | tail -n1)"
  [ -n "$branch" ] || return 1
  echo "$branch"
}

# True when the current directory is a linked worktree (not the main checkout).
function _lfg_in_worktree() {
  local git_dir common_dir

  git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1

  [ "$git_dir" != "$common_dir" ]
}

function lfg() {
  local entrypoint branch repo

  entrypoint="${1:-claude}"
  branch="$2"

  if ! command -v "$entrypoint" >/dev/null 2>&1; then
    echo "lfg: entrypoint not found on PATH: $entrypoint" >&2
    return 1
  fi

  # Already in a worktree with no branch requested: just launch here.
  if [ -z "$branch" ] && _lfg_in_worktree; then
    "$entrypoint"
    return
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo="$(_lfg_pick_repo)" || return 1
    cd "$repo" || return 1
  fi

  if [ -z "$branch" ]; then
    branch="$(_lfg_pick_branch)" || return 1
  fi

  _worktree_add "$branch" || return 1

  "$entrypoint"
}

function _lfg_complete() {
  case "$CURRENT" in
    2) _values 'entrypoint' 'claude' 'codex' ;;
    3) _worktree_branches ;;
  esac
}

compdef _lfg_complete lfg
