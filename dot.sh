#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly YAML_FILE="${SCRIPT_DIR}/dot.yml"
readonly HOME_DIR="${HOME}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

DRY_RUN=true

if [[ "${1:-}" == "apply" ]]; then
    DRY_RUN=false
fi

# Function to check if symlink is already correct
is_correct_symlink() {
    local dest="$1"
    local expected_source="$2"

    if [[ -L "$dest" ]]; then
        local current_target
        current_target="$(readlink "$dest")"
        if [[ "$current_target" == "$expected_source" ]]; then
            return 0
        fi
    fi
    return 1
}

# Function to get status of destination
get_dest_status() {
    local dest="$1"

    if [[ ! -e "$dest" ]] && [[ ! -L "$dest" ]]; then
        echo "new"
    elif [[ -L "$dest" ]]; then
        echo "symlink"
    elif [[ -d "$dest" ]]; then
        echo "directory"
    elif [[ -f "$dest" ]]; then
        echo "file"
    else
        echo "exists"
    fi
}

# Function to create symlink
create_symlink() {
    local source="$1"
    local dest="$2"
    local dry_run="$3"

    # Check if source exists
    if [[ ! -e "$source" ]]; then
        echo -e "${RED}[!]${NC} Source does not exist: $source"
        return 1
    fi

    # Check if already correctly symlinked
    if is_correct_symlink "$dest" "$source"; then
        echo -e "${BLUE}[=]${NC} Already linked: $dest -> $source"
        return 0
    fi

    local status
    status=$(get_dest_status "$dest")

    if [[ "$dry_run" == "true" ]]; then
        if [[ "$status" == "new" ]]; then
            echo -e "${GREEN}[+]${NC} Would create: $dest -> $source"
        else
            echo -e "${YELLOW}[~]${NC} Would replace ($status): $dest -> $source"
        fi
    else
        # Create parent directory if it doesn't exist
        local dest_dir
        dest_dir="$(dirname "$dest")"
        if [[ ! -d "$dest_dir" ]]; then
            mkdir -p "$dest_dir"
        fi

        # Remove existing file/symlink/directory
        if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
            rm -rf "$dest"
        fi

        # Create symlink
        ln -s "$source" "$dest"

        if [[ "$status" == "new" ]]; then
            echo -e "${GREEN}[+]${NC} Created: $dest -> $source"
        else
            echo -e "${YELLOW}[~]${NC} Replaced ($status): $dest -> $source"
        fi
    fi
}

echo "Dotfiles symlink manager"
echo "========================"
echo ""

if [[ "${DRY_RUN}" == "true" ]]; then
    echo "Mode: DRY RUN (use 'apply' argument to actually create symlinks)"
else
    echo "Mode: APPLY (creating symlinks)"
fi
echo ""

# Get all config types (top-level keys)
config_types=$(yq eval 'keys | .[]' "${YAML_FILE}")

while IFS= read -r config_type; do
    # Check if the value is a string (direct mapping)
    if yq eval ".${config_type} | type" "${YAML_FILE}" | grep -q "!!str"; then
        # Direct mapping: config_type -> destination
        dest_path=$(yq eval ".${config_type}" "${YAML_FILE}")
        source_path="${SCRIPT_DIR}/${config_type}"
        dest_full="${HOME_DIR}/${dest_path}"

        create_symlink "${source_path}" "${dest_full}" "${DRY_RUN}"
    else
        # Nested mapping: iterate through keys
        items=$(yq eval ".${config_type} | keys | .[]" "${YAML_FILE}")

        while IFS= read -r item; do
            dest_path=$(yq eval ".${config_type}.${item}" "${YAML_FILE}")
            source_path="${SCRIPT_DIR}/${config_type}/${item}"
            dest_full="${HOME_DIR}/${dest_path}"

            create_symlink "${source_path}" "${dest_full}" "${DRY_RUN}"
        done <<< "${items}"
    fi
done <<< "${config_types}"

echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
    echo "Dry run complete. Run with 'apply' to make changes."
else
    echo "Symlinks created successfully!"
fi
