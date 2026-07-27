# AGENTS.md

Personal dotfiles repo for setting up new machines (macOS and Linux).

## Layout

- Each top-level directory holds one tool's config (e.g. `nvim/`, `zsh/`, `git/`, `k9s/`).
- `dot.yml` maps each source path to its symlink destination under `$HOME`.
  - Direct mapping: `tmux: .tmux.conf` links the whole directory/file.
  - Nested mapping: list individual files under a directory key; use a destination list to link one source more than once.
  - Workstation qualifiers `name[home]` / `name[work]` only link when they match `~/.wstype`.

## Scripts

- `dot.sh` parses `dot.yml` with `yq` and creates the symlinks.
  - Dry-run by default; `dot.sh apply` actually writes them.
  - Replaces existing files/dirs/symlinks at the destination.
- `setup.sh` bootstraps a fresh machine.
  - Prompts for workstation type, installs Vundle, TPM, Homebrew + `Brewfile`, and `mise` tools.

## Conventions

- Add a config by dropping files in a directory and adding a `dot.yml` entry — never hardcode paths.
- Manage packages with `brew` (`Brewfile`) and language runtimes with `mise` (`mise/config.toml`).
- Keep scripts POSIX/bash and platform-agnostic; both scripts branch on `uname` for macOS vs Linux.
