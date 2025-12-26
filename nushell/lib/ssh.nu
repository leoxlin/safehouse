# Reload SSH agent
def reload_ssh_agent [] {
  pkill ssh-agent
  let agent_output = (ssh-agent -s | lines)
  for line in $agent_output {
    if ($line | str contains 'SSH_AUTH_SOCK') {
      let parts = ($line | parse "SSH_AUTH_SOCK={value};")
      if ($parts | is-not-empty) {
          $env.SSH_AUTH_SOCK = ($parts | first | get value)
      }
    } else if ($line | str contains 'SSH_AGENT_PID') {
      let parts = ($line | parse "SSH_AGENT_PID={value};")
      if ($parts | is-not-empty) {
          $env.SSH_AGENT_PID = ($parts | first | get value)
      }
    }
  }
  ssh-add -K ~/.ssh/id_ed25519
}

# SSH Agent / Keychain
if (which keychain | is-not-empty) {
  keychain -q --quiet --eval ($env.HOME | path join '.ssh' 'id_ed25519')
    | lines
    | each { |line|
      let parts = ($line | parse -r '(?P<key>[^=]+)=(?P<value>.+); export \k<key>;')
      if ($parts | is-not-empty) {
          let key = ($parts | first | get key)
          let value = ($parts | first | get value | str trim --char '"')
          load-env {$key: $value}
      }
    }
}
