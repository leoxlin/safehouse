local current_dir='${PWD/#$HOME/~}'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[white]%} > %{$fg[cyan]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}x"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}o"
local git_info='$(git_prompt_info)'

# Add color to prompt
function ccc() {
  local field=$1
  local color=$2
  echo "%{$fg[$2]%}$1%{$reset_color%}"
}

function get_kube_info() {
  if [ -f "$HOME/.kube/config" ]; then
    echo "$(grep -m 1 'current-context:' ~/.kube/config | cut -d ' ' -f 2)"
  else
    echo "kube"
  fi
}

function get_docker_machine_info() {
  if [[ "$(which docker-machine)" != "" ]] &&
     [[ "$(docker-machine active 2> /dev/null)" != "" ]]; then
    echo "dm:$(docker-machine active)"
  else
    echo "dm:none"
  fi
}

function get_pyenv_info() {
  echo "py:system"
}

function get_host_info() {
  local machine_name=$(hostname)
  if [[ "$machine_name" =~ "articulate" ]]; then
    echo $(ccc "n:work" magenta)
  else
    echo $(ccc "n:home" red)
  fi
}

function get_git_info() {
  if [[ -d $(pwd)/.git ]]; then
    local email=$(git config --get user.email)
    if [[ "$email" =~ "me@leoxlin.com" ]]; then
      echo "g:personal"
    elif [[ "$email" =~ "llin@articulate.com" ]]; then
      echo "g:work"
    else
      echo "g:unknown"
    fi
  else
    echo "g:norepo"
  fi
}

function get_zart_context() {
  if [ -f $HOME/.config/zart/context ]; then
    account=$(cat $HOME/.config/zart/context | awk '{ print $1 }' | sed 's/platform-sandbox/sandbox/')
    region=$(cat $HOME/.config/zart/context | awk '{ print $2 }')
    color=$(echo $account | grep 'prod' && echo "red" || echo "blue")
    region_suffix=$([[ $region == "us-east-1" ]] && echo "us" || echo "eu")
    echo $(ccc "zart:$account-$region_suffix" "$color")
  else
    echo $(ccc "zart:none" white)
  fi
}

local pp_tm=$(ccc %T cyan)
local pp_gt=$(ccc \> white)
local pp_dir=$(ccc %c yellow)
local pp_host=$(get_host_info)
local pp_dm='$(ccc $(get_git_info) yellow)'
local pp_py='$(ccc $(get_pyenv_info) green)'
local pp_zart='$(ccc $(get_zart_context) blue)'

setopt PROMPT_SUBST
# Construct the whole prompt line before hand so it doesnt get cut off
# on Ctrl-C
PROMPT="${op_login}\
${pp_tm} \
[ ${pp_host} ${pp_dm} ${pp_py} ${pp_zart} ] \
${pp_gt} ${pp_dir} ${git_info}
%{$terminfo[bold]$fg[yellow]%}λ %{$reset_color%}"

