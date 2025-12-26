# Configure nushell behavior
$env.config = {
    show_banner: false

    # History configuration (ported from zsh)
    history: {
        max_size: 10000000
        sync_on_enter: true
        file_format: "sqlite"
        isolation: false
    }

    # Completions
    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
    }

    # Keybindings - emacs mode (like zsh bindkey -e)
    edit_mode: emacs

    ls: {
        use_ls_colors: true
        clickable_links: true
    }

    rm: {
        always_trash: false
    }

    table: {
        mode: rounded
        index_mode: auto
        show_empty: true
    }
}

def pbcopy [] {
  let input = $in
  if (which xsel | is-not-empty) {
    $input | xsel --clipboard --input
  } else if (which pbcopy | is-not-empty) {
    $input | ^pbcopy
  } else {
    error make {msg: "Neither pbcopy nor xsel found"}
  }
}

if ((which zeditor | is-not-empty) and (which zed | is-empty)) {
  which zeditor | select path | each { |v| ln -s $"($v.path)" ~/.local/bin/zed }
}

if ((which nvim | is-not-empty) and not ('~/.local/bin/vim' | path exists)) {
  which nvim | select path | each { |v| ln -s $"($v.path)" ~/.local/bin/vim }
}

source ~/.config/nushell/lib/alias.nu
source ~/.config/nushell/lib/ssh.nu

# ============================================================================
# Tools integration - Setup various tools and integrations
# ============================================================================

source ~/.config/nushell/plugins/mise.nu
source ~/.config/nushell/plugins/zoxide.nu
source ~/.config/nushell/plugins/starship.nu
