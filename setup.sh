#!/usr/bin/env bash

set -euo pipefail

readonly ZSH_DIR="${HOME}/.zsh"
readonly VIM_BUNDLE="${HOME}/.vim/bundle"
readonly TMUX_PLUGINS="${HOME}/.tmux/plugins"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles..."

# Prompt for workstation type
while true; do
  read -rp "Workstation type [work/home]: " wstype
  case "${wstype}" in
    work|home)
      echo "${wstype}" > "${HOME}/.wstype"
      echo "Workstation type set to: ${wstype}"
      break
      ;;
    *)
      echo "Invalid choice. Please enter 'work' or 'home'."
      ;;
  esac
done

# Setup Vundle for Vim
mkdir -p "${VIM_BUNDLE}"
if [[ ! -e "${VIM_BUNDLE}/Vundle.vim" ]]; then
  echo "Installing Vundle..."
  git clone https://github.com/VundleVim/Vundle.vim.git "${VIM_BUNDLE}/Vundle.vim" || {
    echo "Failed to clone Vundle"
    exit 1
  }
fi

# Setup TPM for tmux
mkdir -p "${TMUX_PLUGINS}"
if [[ ! -e "${TMUX_PLUGINS}/tpm" ]]; then
  echo "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "${TMUX_PLUGINS}/tpm" || {
    echo "Failed to clone TPM"
    exit 1
  }
fi

# Install Homebrew if needed
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    echo "Failed to install Homebrew"
    exit 1
  }
fi

# Determine Homebrew path
if [[ "$(uname)" == "Darwin" ]]; then
  readonly BREW_PATH="/opt/homebrew/bin"
else
  readonly BREW_PATH="/home/linuxbrew/.linuxbrew/bin"
fi

# Install packages from Brewfile
echo "Installing Homebrew packages..."
"${BREW_PATH}/brew" bundle --file="${SCRIPT_DIR}/Brewfile" || {
  echo "Failed to install Homebrew packages"
  exit 1
}

# Setup mise
echo "Setting up mise..."
"${BREW_PATH}/mise" trust "${SCRIPT_DIR}/mise/config.toml" || {
  echo "Failed to trust mise config"
  exit 1
}
"${BREW_PATH}/mise" plugins install ruby https://github.com/asdf-vm/asdf-ruby
"${BREW_PATH}/mise" install || {
  echo "Failed to install mise tools"
  exit 1
}

sudo ln -s $(pwd)/shell-entrypoint /usr/local/bin/shell-entrypoint

echo "Setup complete!"
