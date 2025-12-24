#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd `dirname ${0}`; pwd)"
CONFIG_FILE="${SCRIPT_DIR}/dot.yml"
DRY_RUN=true

# Check if apply argument is provided
if [[ "$1" == "apply" ]]; then
    DRY_RUN=false
    echo "=== APPLY MODE ==="
    echo
else
    echo "=== DRY RUN MODE ==="
    echo "Run with 'apply' argument to actually create symlinks"
    echo
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed"
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file $CONFIG_FILE not found"
    exit 1
fi

# Get all config types (top-level keys)
config_types=$(yq eval 'keys | .[]' "$CONFIG_FILE")

# Process each config type
while IFS= read -r config_type; do
    echo "Processing [$config_type]..."

    # Get all source files for this config type
    sources=$(yq eval ".${config_type} | keys | .[]" "$CONFIG_FILE")

    while IFS= read -r source; do
        # Get destination from YAML
        dest=$(yq eval ".${config_type}.\"${source}\"" "$CONFIG_FILE")

        # Build full paths
        source_path="${SCRIPT_DIR}/${config_type}/${source}"
        dest_path="${HOME}/${dest}"

        # Check if source exists
        if [[ ! -e "$source_path" ]]; then
            echo "  ⚠ SKIP: Source does not exist: $source_path"
            continue
        fi

        # Check if destination already exists and is correctly symlinked
        if [[ -L "$dest_path" ]]; then
            current_link=$(readlink "$dest_path")
            if [[ "$current_link" == "$source_path" ]]; then
                echo "  ✓ SKIP: Already correctly linked: $dest_path -> $source_path"
                continue
            else
                echo "  ⚠ REPLACE: $dest_path (currently links to $current_link)"
                action="replace symlink"
            fi
        elif [[ -e "$dest_path" ]]; then
            if [[ -d "$dest_path" ]]; then
                echo "  ⚠ REPLACE: $dest_path (directory exists)"
            else
                echo "  ⚠ REPLACE: $dest_path (file exists)"
            fi
            action="replace existing"
        else
            echo "  → CREATE: $dest_path -> $source_path"
            action="create new"
        fi

        # Apply changes if not in dry-run mode
        if [[ "$DRY_RUN" == false ]]; then
            # Create parent directory if it doesn't exist
            dest_dir=$(dirname "$dest_path")
            mkdir -p "$dest_dir"

            # Remove existing file/link if present
            if [[ -e "$dest_path" ]] || [[ -L "$dest_path" ]]; then
                rm -rf "$dest_path"
            fi

            # Create symlink
            ln -s "$source_path" "$dest_path"
            echo "    ✓ Done: $action"
        fi

    done <<< "$sources"

    echo
done <<< "$config_types"

if [[ "$DRY_RUN" == true ]]; then
    echo "=== DRY RUN COMPLETE ==="
    echo "No changes were made. Run with 'apply' to create symlinks."
else
    echo "=== APPLY COMPLETE ==="
    echo "All symlinks have been created."
fi
