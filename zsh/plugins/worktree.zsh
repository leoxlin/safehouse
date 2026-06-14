function _worktree_usage() {
  echo "usage: worktree add <branch_name>"
  echo "       worktree cd <branch_name>"
  echo "       worktree list"
  echo "       worktree prune"
  echo "       worktree remove|rm <branch_name>"
}

function _worktree_require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo 'fatal: not a git repository (or any parent up to mount point /)' >&2
    return 1
  fi
}

function _worktree_default_ref() {
  local default_ref

  default_ref="$(git default 2>/dev/null)"
  if [ -n "$default_ref" ]; then
    echo "$default_ref"
  elif git show-ref --verify --quiet refs/heads/main; then
    echo "main"
  elif git show-ref --verify --quiet refs/remotes/origin/main; then
    echo "origin/main"
  elif git show-ref --verify --quiet refs/heads/master; then
    echo "master"
  elif git show-ref --verify --quiet refs/remotes/origin/master; then
    echo "origin/master"
  else
    echo "HEAD"
  fi
}

function _worktree_new_path() {
  local root repo id

  root="$(git worktree-parent)" || return 1
  repo="$(basename "$root")"
  id="$(openssl rand -hex 4 | cut -c1-7)" || return 1

  echo "$HOME/Worktrees/$id/$repo"
}

function _worktree_branch_name() {
  local ref

  ref="$1"
  if [ -z "$ref" ]; then
    echo "(detached)"
  elif [[ "$ref" == refs/heads/* ]]; then
    echo "${ref#refs/heads/}"
  else
    echo "$ref"
  fi
}

function _worktree_branch_has_remote() {
  local branch remote_branch

  branch="$1"
  if [ -z "$branch" ] || [ "$branch" = "(detached)" ]; then
    return 1
  fi

  for remote_branch in ${(f)"$(git for-each-ref --format='%(refname:short)' refs/remotes)"}; do
    if [ "${remote_branch#*/}" = "$branch" ]; then
      return 0
    fi
  done

  return 1
}

function _worktree_is_older_than_days() {
  local worktree_path days

  worktree_path="$1"
  days="$2"

  [ -d "$worktree_path" ] || return 1
  [ -n "$(find "$worktree_path" -prune -mtime +"$days" -print 2>/dev/null)" ]
}

function _worktree_cd() {
  local branch worktree_path

  branch="$1"
  if [ -z "$branch" ]; then
    echo "You must provide a branch name for worktree" >&2
    _worktree_usage >&2
    return 1
  fi

  _worktree_require_git_repo || return 1

  worktree_path="$(git worktree-child "$branch")" || return 1
  if [ -z "$worktree_path" ]; then
    echo "fatal: no worktree found for branch '$branch'" >&2
    return 1
  fi

  cd "$worktree_path" || return 1
}

function _worktree_list() {
  local current_root worktree_path branch_ref branch_name marker line

  _worktree_require_git_repo || return 1

  current_root="$(git rev-parse --show-toplevel)" || return 1
  worktree_path=""
  branch_ref=""

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      if [ -n "$worktree_path" ]; then
        branch_name="$(_worktree_branch_name "$branch_ref")"
        if [ "$worktree_path" = "$current_root" ]; then
          marker="*"
        else
          marker=" "
        fi
        printf "%s %s\t%s\n" "$marker" "$branch_name" "$worktree_path"
      fi

      worktree_path=""
      branch_ref=""
    elif [[ "$line" == worktree\ * ]]; then
      worktree_path="${line#worktree }"
    elif [[ "$line" == branch\ * ]]; then
      branch_ref="${line#branch }"
    fi
  done < <(git worktree list --porcelain)

  if [ -n "$worktree_path" ]; then
    branch_name="$(_worktree_branch_name "$branch_ref")"
    if [ "$worktree_path" = "$current_root" ]; then
      marker="*"
    else
      marker=" "
    fi
    printf "%s %s\t%s\n" "$marker" "$branch_name" "$worktree_path"
  fi
}

function _worktree_add() {
  local branch worktree_path default_ref

  branch="$1"
  if [ -z "$branch" ]; then
    echo "You must provide a branch name for worktree" >&2
    _worktree_usage >&2
    return 1
  fi

  _worktree_require_git_repo || return 1

  worktree_path="$(git worktree-child "$branch")" || return 1
  if [ -n "$worktree_path" ]; then
    cd "$worktree_path" || return 1
    return 0
  fi

  worktree_path="$(_worktree_new_path)" || return 1
  mkdir -p "$(dirname "$worktree_path")" || return 1

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$worktree_path" "$branch" || return 1
  else
    default_ref="$(_worktree_default_ref)" || return 1
    git worktree add -b "$branch" "$worktree_path" "$default_ref" || return 1
  fi

  worktree_path="$(git worktree-child "$branch")" || return 1
  if [ -z "$worktree_path" ]; then
    echo "fatal: could not find worktree for branch '$branch'" >&2
    return 1
  fi

  cd "$worktree_path" || return 1
}

function _worktree_remove() {
  local branch parent worktree_path

  branch="$1"
  if [ -z "$branch" ]; then
    echo "You must provide a branch name for worktree" >&2
    _worktree_usage >&2
    return 1
  fi

  _worktree_require_git_repo || return 1

  parent="$(git worktree-parent)" || return 1
  worktree_path="$(git worktree-child "$branch")" || return 1
  if [ -z "$worktree_path" ]; then
    echo "fatal: no worktree found for branch '$branch'" >&2
    return 1
  fi

  cd "$parent" || return 1
  git worktree remove "$worktree_path" || return 1
  git worktree prune
}

function _worktree_prune() {
  local parent worktree_path branch_ref branch_name line removed failed

  _worktree_require_git_repo || return 1

  parent="$(git worktree-parent)" || return 1
  cd "$parent" || return 1

  worktree_path=""
  branch_ref=""
  removed=0
  failed=0

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      if [ -n "$worktree_path" ] && [ "$worktree_path" != "$parent" ]; then
        branch_name="$(_worktree_branch_name "$branch_ref")"
        if _worktree_is_older_than_days "$worktree_path" 7 && ! _worktree_branch_has_remote "$branch_name"; then
          printf "Removing %s\t%s\n" "$branch_name" "$worktree_path"
          if git worktree remove "$worktree_path"; then
            removed=1
          else
            failed=1
          fi
        fi
      fi

      worktree_path=""
      branch_ref=""
    elif [[ "$line" == worktree\ * ]]; then
      worktree_path="${line#worktree }"
    elif [[ "$line" == branch\ * ]]; then
      branch_ref="${line#branch }"
    fi
  done < <(git worktree list --porcelain)

  if [ -n "$worktree_path" ] && [ "$worktree_path" != "$parent" ]; then
    branch_name="$(_worktree_branch_name "$branch_ref")"
    if _worktree_is_older_than_days "$worktree_path" 7 && ! _worktree_branch_has_remote "$branch_name"; then
      printf "Removing %s\t%s\n" "$branch_name" "$worktree_path"
      if git worktree remove "$worktree_path"; then
        removed=1
      else
        failed=1
      fi
    fi
  fi

  git worktree prune || return 1
  if [ "$removed" -eq 0 ] && [ "$failed" -eq 0 ]; then
    echo "No stale worktrees found."
  fi

  return "$failed"
}

function worktree() {
  local command

  if [ $# -gt 0 ]; then
    command="$1"
    shift
  else
    command=""
  fi

  case "$command" in
    add)
      _worktree_add "$@"
      ;;
    cd)
      _worktree_cd "$@"
      ;;
    list)
      _worktree_list "$@"
      ;;
    prune)
      _worktree_prune "$@"
      ;;
    remove|rm)
      _worktree_remove "$@"
      ;;
    help|-h|--help|"")
      _worktree_usage
      ;;
    *)
      echo "unknown worktree command: $command" >&2
      _worktree_usage >&2
      return 1
      ;;
  esac
}

function git_worktree_add() {
  worktree add "$@"
}
