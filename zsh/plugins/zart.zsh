export ZART_DIR="${HOME}/.config/zart"
export ZART_ACCOUNTS="${ZART_DIR}/account_ids.json"
export ZART_MAPPING="${ZART_DIR}/name_mapping"

zart_setup() {
  reset=${1:-yes}
  mkdir -p "$ZART_DIR"

  if [[ $reset == "yes" ]]; then
    rm $ZART_ACCOUNTS
    rm $ZART_MAPPING
  fi

  if [[ ! -f $ZART_ACCOUNTS ]]; then
    if ! curl -fsSL -o $ZART_ACCOUNTS \
      "https://articulate-public-infra.s3.amazonaws.com/account_ids.json"
    then
      echo "Error: failed to download account_ids.json" >&2
      return 1
    fi
  fi

  if [[ ! -f $ZART_MAPPING ]]; then
    local account product environment valid_names
    typeset -U valid_names
    for account in $(jq -r 'to_entries[] | .value | to_entries[] | .key' $ZART_ACCOUNTS); do
      valid_names=()
      product="${account%%-*}"
      environment="${account#*-}"
      for i in "2" "3" "${#product}"; do
        valid_names+=( "${${product}[1,i]}-${environment}" "${${product}[1,i]}-${environment[1]}" )
        valid_names+=( "${${product}[1,i]}${environment}" "${${product}[1,i]}${environment[1]}" )
      done
      for name in $valid_names; do
        sep=$(awk '/-/{ print "-"}' <<< "$name")
        valid_names+=( "${name}${sep}eu" "${name}${sep}us")
      done
      for name in $valid_names; do
        region=$([[ "$name" == *eu ]] && echo "eu-central-1" || echo "us-east-1")
        printf '%s %s %s\n' "$name" "$account" "$region" >> $ZART_MAPPING
      done
    done
  fi
}

zart_get_mapping() {
  local key="$1"
  local allow_context="${2:-yes}"
  local info account region context

  # Exact match on first column
  info=$(awk -v key="$key" '$1 == key { print; exit }' $ZART_MAPPING 2>/dev/null)

  if [[ -z "$info" ]]; then
    if [[ "$allow_context" = "yes" && -f "${ZART_DIR}/context" ]]; then
      # Fallback to context
      read -r account region < "${ZART_DIR}/context"
      printf '%s\n' "0" "$account" "$region" "no"
      return 0
    else
      echo "Cannot find deploy environment: $key" >&2
      printf '%s\n' "1" "" "" "no"
      return 1
    fi
  fi

  account=$(printf '%s\n' "$info" | awk '{print $2}')
  region=$(printf '%s\n' "$info" | awk '{print $3}')
  printf '%s\n' "0" "$account" "$region" "yes"
}

zart_set_context() {
  local key="$1"
  local mapping code account region

  # Read the 4 lines from zart_get_mapping as an array
  mapping=("${(@f)$(zart_get_mapping "$key" no)}")
  code=${mapping[1]}
  account=${mapping[2]}
  region=${mapping[3]}

  if [[ "$code" = "0" ]]; then
    printf '%s %s\n' "$account" "$region" > "${ZART_DIR}/context"
  fi
}

zart() {
  case "$1" in
    set-context|context|set)
      zart_set_context "$2"
      return $?
      ;;
    remove-context|rm)
      rm -f "${ZART_DIR}/context"
      return 0
      ;;
  esac

  local key="$1"
  local mapping code account region should_shift
  mapping=("${(@f)$(zart_get_mapping "$key")}")
  code=${mapping[1]}
  account=${mapping[2]}
  region=${mapping[3]}
  should_shift=${mapping[4]}

  if [[ "$code" != "0" ]]; then
    return 1
  fi

  if [[ "$should_shift" = "yes" ]]; then
    shift || true
  fi

  # Shorten argument aliases
  typeset -A as
  as[k]="kubectl"
  as[9]="k9s"
  as[k9]="k9s"
  as[kg]="kubectl get"
  as[kgp]="kubectl get pod"
  as[kgss]="kubectl get statefulset"
  as[ke]="kubectl exec -it"
  as[-np]="-n platform"
  as[---]="-- --"

  local fullargs=() arg aliasarg actual
  for arg in "$@"; do
    aliasarg="${as[$arg]:-$arg}"
    for actual in ${(z)aliasarg}; do
      fullargs+=("$actual")
    done
  done

  # Use "$CMD" only if set, otherwise default to empty
  if [[ -n "$CMD" ]]; then
    art --on "$account" --region "$region" "$CMD" "${fullargs[@]}"
  else
    art --on "$account" --region "$region" "${fullargs[@]}"
  fi
}

alias z='zart'
alias kubectl='zart kubectl'

zart_setup 'no'
