# Zoxide integration for Nushell
# This file is sourced in config.nu

# Initialize zoxide
def --env __zoxide_z [...rest:string] {
  let arg0 = ($rest | append '~').0
  let path = if (($rest | length) <= 1) and ($arg0 == '-' or ($arg0 | path expand | path type) == dir) {
    $arg0
  } else {
    (zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n")
  }
  cd $path
}

def --env __zoxide_zi [...rest:string] {
  cd $"(zoxide query -i -- ...$rest | str trim -r -c "\n")"
}

# Aliases
alias z = __zoxide_z
alias zi = __zoxide_zi
alias cd = __zoxide_z
alias cdi = __zoxide_zi

# Hook to add directories to zoxide
$env.config = ($env.config | upsert hooks {
  pre_prompt: ($env.config.hooks.pre_prompt? | default [] | append {||
    if (which zoxide | is-not-empty) {
      zoxide add -- $env.PWD
    }
  })
})
