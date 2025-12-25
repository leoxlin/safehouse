#!/usr/bin/env bash

set -euo pipefail

readonly ZSH_DIR="${HOME}/.zsh"
readonly VIM_BUNDLE="${HOME}/.vim/bundle"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles..."

# Setup Vundle for Vim
mkdir -p "${VIM_BUNDLE}"
if [[ ! -e "${VIM_BUNDLE}/Vundle.vim" ]]; then
  echo "Installing Vundle..."
  git clone https://github.com/VundleVim/Vundle.vim.git "${VIM_BUNDLE}/Vundle.vim" || {
    echo "Failed to clone Vundle"
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
"${BREW_PATH}/mise" install || {
  echo "Failed to install mise tools"
  exit 1
}

echo "Setup complete!"
