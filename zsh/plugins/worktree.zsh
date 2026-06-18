: ${MAIN_SOURCE_DIR:="$HOME/Source"}

# Worktree helper conventions:
#
# - MAIN_SOURCE_DIR: base directory containing source repositories.
#   Defaults to ~/Source. Set before sourcing this file to override.
#
# - Branch-related commands (add, cd, remove/rm) accept a single argument:
#     - [repo]@[branch]   operate on the named repo under MAIN_SOURCE_DIR
#     - [branch]          operate on the current git repo/worktree
#   When outside any git repo, the [repo]@[branch] form is required.
#
# - Repo-wide commands (list, ls, prune) accept an optional repo name:
#     - no argument       operate on all repos under MAIN_SOURCE_DIR
#     - [repo]            operate only on the named repo
#
# - Worktrees are created under $HOME/Worktrees/<id>/<repo> and reused by branch.
#
# - If mise is installed, entering a worktree auto-trusts its mise config when
#   it is not already trusted. This prevents mise's chpwd hook from erroring.

function _worktree_usage() {
  echo "usage: worktree add [repo@]<branch_name>"
  echo "       worktree cd [repo@]<branch_name>"
  echo "       worktree list [repo]"
  echo "       worktree ls [repo]"
  echo "       worktree prune [repo]"
  echo "       worktree remove|rm [repo@]<branch_name>"
}

function _worktree_require_git_repo() {
  local repo_path="$1"

  if [ -n "$repo_path" ]; then
    if [ ! -d "$repo_path/.git" ] && [ ! -f "$repo_path/.git" ]; then
      echo "fatal: '$repo_path' is not a git repository" >&2
      return 1
    fi
    return 0
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo 'fatal: not a git repository (or any parent up to mount point /)' >&2
    return 1
  fi
}

function _worktree_resolve_repo() {
  local repo="$1"
  local source_dir="${MAIN_SOURCE_DIR%/}"

  if [ -n "$repo" ]; then
    local repo_path="$source_dir/$repo"
    if [ ! -d "$repo_path" ]; then
      echo "fatal: repo '$repo' not found in $source_dir" >&2
      return 1
    fi
    echo "$repo_path"
  else
    git rev-parse --show-toplevel
  fi
}

function _worktree_parse_target() {
  local target="$1"
  local repo branch

  if [[ "$target" == *@* ]]; then
    repo="${target%@*}"
    branch="${target#*@}"
    if [ -z "$repo" ]; then
      echo "fatal: repo name is required before '@'" >&2
      return 1
    fi
  else
    branch="$target"
  fi

  if [ -z "$branch" ]; then
    echo "fatal: branch name is required" >&2
    return 1
  fi

  printf '%s\n' "$repo" "$branch"
}

function _worktree_all_repos() {
  local source_dir="${MAIN_SOURCE_DIR%/}"
  local d

  if [ -d "$source_dir" ]; then
    for d in "$source_dir"/*(/N); do
      if [ -d "$d/.git" ] || [ -f "$d/.git" ]; then
        basename "$d"
      fi
    done
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
  local repo_path="$1"
  local branch="$2"
  local remote_branch output

  if [ -z "$branch" ] || [ "$branch" = "(detached)" ]; then
    return 1
  fi

  if [ -n "$repo_path" ]; then
    output="$(git -C "$repo_path" for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null)"
  else
    output="$(git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null)"
  fi

  for remote_branch in ${(f)"$output"}; do
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

function _worktree_mise_trust_if_untrusted() {
  local worktree_path="$1"

  command -v mise >/dev/null 2>&1 || return 0

  if mise trust --show -C "$worktree_path" 2>/dev/null | grep -q ': untrusted'; then
    mise trust -y -q -C "$worktree_path"
  fi
}

function _worktree_cd() {
  local target repo branch worktree_path repo_path

  target="$1"
  if [ -z "$target" ]; then
    echo "You must provide a target for worktree" >&2
    _worktree_usage >&2
    return 1
  fi

  {
    read -r repo
    read -r branch
  } < <(_worktree_parse_target "$target") || return 1

  repo_path="$(_worktree_resolve_repo "$repo")" || return 1
  _worktree_require_git_repo "$repo_path" || return 1

  worktree_path="$(git -C "$repo_path" worktree-child "$branch")" || return 1
  if [ -z "$worktree_path" ]; then
    echo "fatal: no worktree found for branch '$branch'" >&2
    return 1
  fi

  _worktree_mise_trust_if_untrusted "$worktree_path"
  cd "$worktree_path" || return 1
}

function _worktree_list_repo() {
  local repo_path="$1"
  local repo_name="$2"
  local current_root worktree_path branch_ref branch_name marker line

  _worktree_require_git_repo "$repo_path" || return 1

  current_root="$(git rev-parse --show-toplevel 2>/dev/null)" || current_root=""
  worktree_path=""
  branch_ref=""

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      if [ -n "$worktree_path" ]; then
        branch_name="$(_worktree_branch_name "$branch_ref")"
        if [ -n "$repo_name" ]; then
          printf "%s\t%s\t%s\n" "$repo_name" "$branch_name" "$worktree_path"
        else
          if [ "$worktree_path" = "$current_root" ]; then
            marker="*"
          else
            marker=" "
          fi
          printf "%s %s\t%s\n" "$marker" "$branch_name" "$worktree_path"
        fi
      fi

      worktree_path=""
      branch_ref=""
    elif [[ "$line" == worktree\ * ]]; then
      worktree_path="${line#worktree }"
    elif [[ "$line" == branch\ * ]]; then
      branch_ref="${line#branch }"
    fi
  done < <(git -C "$repo_path" worktree list --porcelain)

  if [ -n "$worktree_path" ]; then
    branch_name="$(_worktree_branch_name "$branch_ref")"
    if [ -n "$repo_name" ]; then
      printf "%s\t%s\t%s\n" "$repo_name" "$branch_name" "$worktree_path"
    else
      if [ "$worktree_path" = "$current_root" ]; then
        marker="*"
      else
        marker=" "
      fi
      printf "%s %s\t%s\n" "$marker" "$branch_name" "$worktree_path"
    fi
  fi
}

function _worktree_list() {
  local repo

  repo="$1"

  if [ -n "$repo" ]; then
    _worktree_list_repo "$(_worktree_resolve_repo "$repo")" || return 1
    return 0
  fi

  if command -v column >/dev/null 2>&1; then
    {
      for repo in $(_worktree_all_repos); do
        local repo_path="$(_worktree_resolve_repo "$repo")" || continue
        _worktree_list_repo "$repo_path" "$repo" || true
      done
    } | column -t -s $'\t'
  else
    for repo in $(_worktree_all_repos); do
      local repo_path="$(_worktree_resolve_repo "$repo")" || continue
      _worktree_list_repo "$repo_path" "$repo" || true
    done
  fi
}

function _worktree_add() {
  local target repo branch worktree_path default_ref repo_path

  target="$1"
  if [ -z "$target" ]; then
    echo "You must provide a target for worktree" >&2
    _worktree_usage >&2
    return 1
  fi

  {
    read -r repo
    read -r branch
  } < <(_worktree_parse_target "$target") || return 1

  repo_path="$(_worktree_resolve_repo "$repo")" || return 1
  _worktree_require_git_repo "$repo_path" || return 1

  worktree_path="$(git -C "$repo_path" worktree-child "$branch")" || return 1
  if [ -n "$worktree_path" ]; then
    _worktree_mise_trust_if_untrusted "$worktree_path"
    cd "$worktree_path" || return 1
    return 0
  fi

  cd "$repo_path" || return 1
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

  _worktree_mise_trust_if_untrusted "$worktree_path"
  cd "$worktree_path" || return 1
}

function _worktree_remove() {
  local target repo branch parent worktree_path repo_path

  target="$1"
  if [ -z "$target" ]; then
    echo "You must provide a target for worktree" >&2
    _worktree_usage >&2
    return 1
  fi

  {
    read -r repo
    read -r branch
  } < <(_worktree_parse_target "$target") || return 1

  repo_path="$(_worktree_resolve_repo "$repo")" || return 1
  _worktree_require_git_repo "$repo_path" || return 1

  parent="$(git -C "$repo_path" worktree-parent)" || return 1
  worktree_path="$(git -C "$repo_path" worktree-child "$branch")" || return 1
  if [ -z "$worktree_path" ]; then
    echo "fatal: no worktree found for branch '$branch'" >&2
    return 1
  fi

  git -C "$parent" worktree remove "$worktree_path" || return 1
  git -C "$parent" worktree prune
}

function _worktree_prune_repo() {
  local repo_path parent worktree_path branch_ref branch_name line removed failed

  repo_path="$1"
  _worktree_require_git_repo "$repo_path" || return 1

  parent="$(git -C "$repo_path" worktree-parent)" || return 1

  worktree_path=""
  branch_ref=""
  removed=0
  failed=0

  while IFS= read -r line; do
    if [ -z "$line" ]; then
      if [ -n "$worktree_path" ] && [ "$worktree_path" != "$parent" ]; then
        branch_name="$(_worktree_branch_name "$branch_ref")"
        if _worktree_is_older_than_days "$worktree_path" 7 && ! _worktree_branch_has_remote "$parent" "$branch_name"; then
          printf "Removing %s\t%s\n" "$branch_name" "$worktree_path"
          if git -C "$parent" worktree remove "$worktree_path"; then
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
  done < <(git -C "$parent" worktree list --porcelain)

  if [ -n "$worktree_path" ] && [ "$worktree_path" != "$parent" ]; then
    branch_name="$(_worktree_branch_name "$branch_ref")"
    if _worktree_is_older_than_days "$worktree_path" 7 && ! _worktree_branch_has_remote "$parent" "$branch_name"; then
      printf "Removing %s\t%s\n" "$branch_name" "$worktree_path"
      if git -C "$parent" worktree remove "$worktree_path"; then
        removed=1
      else
        failed=1
      fi
    fi
  fi

  git -C "$parent" worktree prune || return 1
  if [ "$removed" -eq 0 ] && [ "$failed" -eq 0 ]; then
    echo "No stale worktrees found."
  fi

  return "$failed"
}

function _worktree_prune() {
  local repo failed

  repo="$1"
  failed=0

  if [ -n "$repo" ]; then
    _worktree_prune_repo "$(_worktree_resolve_repo "$repo")" || return 1
    return 0
  fi

  for repo in $(_worktree_all_repos); do
    local repo_path="$(_worktree_resolve_repo "$repo")" || continue
    _worktree_prune_repo "$repo_path" || failed=1
  done

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
    list|ls)
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

alias wt='worktree'

function _worktree_repos() {
  local source_dir="${MAIN_SOURCE_DIR%/}"
  local repos=()
  local d

  if [ -d "$source_dir" ]; then
    for d in "$source_dir"/*(/N); do
      if [ -d "$d/.git" ] || [ -f "$d/.git" ]; then
        repos+=("$(basename "$d")")
      fi
    done
  fi

  _values 'repo' "${repos[@]}"
}

function _worktree_branches() {
  local repo_path="$1"
  local git_dir=""

  if [ -n "$repo_path" ] && { [ -d "$repo_path/.git" ] || [ -f "$repo_path/.git" ]; }; then
    git_dir="$repo_path"
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_dir="$(git rev-parse --show-toplevel)"
  fi

  if [ -n "$git_dir" ]; then
    _values 'branch' $(git -C "$git_dir" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
  fi
}

function _worktree_complete_branch_arg() {
  local current_word="$words[CURRENT]"
  local repo repo_path

  if [[ "$current_word" == *@* ]]; then
    compset -P '*@'
    repo="${current_word%@*}"
    repo_path="${MAIN_SOURCE_DIR%/}/$repo"
    if [ -d "$repo_path" ]; then
      _worktree_branches "$repo_path"
    fi
    return
  fi

  _alternative \
    'branches:branch:_worktree_branches' \
    'repos:repo:_worktree_repos_with_at'
}

function _worktree_repos_with_at() {
  local source_dir="${MAIN_SOURCE_DIR%/}"
  local repos=()
  local d

  if [ -d "$source_dir" ]; then
    for d in "$source_dir"/*(/N); do
      if [ -d "$d/.git" ] || [ -f "$d/.git" ]; then
        repos+=("$(basename "$d")@")
      fi
    done
  fi

  compadd -S '' -a repos
}

function _worktree_complete() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments -C \
    '1: :->command' \
    '2: :->arg1'

  case "$state" in
    command)
      _values 'worktree command' \
        'add[create or switch to a worktree]' \
        'cd[change to a worktree]' \
        'list[list worktrees]' \
        'ls[list worktrees]' \
        'prune[remove stale worktrees]' \
        'remove[remove a worktree]' \
        'rm[remove a worktree]'
      ;;
    arg1)
      case "$line[1]" in
        add|cd|remove|rm)
          _worktree_complete_branch_arg
          ;;
        list|ls|prune)
          _worktree_repos
          ;;
      esac
      ;;
  esac
}

compdef _worktree_complete worktree wt
