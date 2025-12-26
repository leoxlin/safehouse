# Editor
$env.EDITOR = 'vim'
$env.config.buffer_editor = 'vim'

# PATH modifications
def add_paths [] {
  let paths = [
    '/opt/homebrew/opt/coreutils/libexec/gnubin'
    '/opt/homebrew/opt/binutils/bin'
    '/opt/homebrew/opt/bzip2/bin'
    '/opt/homebrew/opt/gnu-sed/libexec/gnubin'
    '/opt/homebrew/bin'
    '/home/linuxbrew/.linuxbrew/bin'
    '/usr/local/opt/go/libexec/bin'
    ($env.HOME | path join 'Tools')
    ($env.HOME | path join '.opencode' 'bin')
    ($env.HOME | path join '.local' 'bin')
    ($env.HOME | path join '.go' 'gopath' 'bin')
    $env.PATH
  ] | flatten

  $paths | where {|path| ($path | path exists)} | uniq
}

$env.path = (add_paths)

# Go configuration
$env.GOPATH = ($env.HOME | path join '.go' 'gopath')
$env.GO111MODULE = 'on'

# Pyenv configuration
$env.PYENV_ROOT = ($env.HOME | path join '.pyenv')
if ($env.PYENV_ROOT | path join 'bin' | path exists) {
  $env.PATH = ($env.PATH | prepend ($env.PYENV_ROOT | path join 'bin'))
}

$env.config.show_banner = false
