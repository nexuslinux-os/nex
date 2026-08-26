#!/usr/bin/env bash

nex_update() {
    nex_depends_on curl
    nex_depends_on wget

    nex_msg info "Checking for database updates..."

    local remote_tag
    remote_tag=$(github_latest_release "$NEX_DB_REPO")
    [[ -z "$remote_tag" ]] && nex_die "Failed to fetch latest release info."

    local local_tag=""
    if [[ -f "$NEX_DB_FILE" ]]; then
        local_tag=$(head -1 "$NEX_DB_FILE" | sed -n 's/^# version: //p')
    fi

    if [[ "$remote_tag" == "$local_tag" ]]; then
        nex_msg success "Database is up to date (${local_tag})."
        return 0
    fi

    nex_msg info "New version available: ${remote_tag} (local: ${local_tag:-none})"
    github_download_db "$remote_tag"
    nex_msg success "Database updated to ${remote_tag}."
}

nex_upgrade() {
    nex_update

    nex_msg info "Checking for package upgrades..."
    local upgrades=()
    local current_ver new_ver cmp

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        local installed
        installed=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
        [[ -z "$installed" ]] && continue
        new_ver=$(db_get_field "$pkg" "version")
        [[ -z "$new_ver" ]] && continue
        cmp=$(nex_version_cmp "$installed" "$new_ver")
        if [[ "$cmp" == "1" ]]; then
            upgrades+=("$pkg")
        fi
    done < "$NEX_MANAGED_LIST"

    if [[ ${#upgrades[@]} -eq 0 ]]; then
        nex_msg success "All packages are up to date."
        return 0
    fi

    nex_msg info "Upgradable packages:"
    for pkg in "${upgrades[@]}"; do
        local installed new
        installed=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
        new=$(db_get_field "$pkg" "version")
        echo -e "  ${BOLD}$pkg${RESET} ${YELLOW}$installed${RESET} -> ${GREEN}$new${RESET}"
    done

    echo
    if ! nex_prompt "Proceed with upgrade? [y/N]"; then
        nex_msg info "Aborted."
        return 0
    fi

    local failed=()
    local cache_dir="$NEX_CACHE_DIR/packages"

    for pkg in "${upgrades[@]}"; do
        local repo asset
        repo=$(db_get_field "$pkg" "repo")
        asset=$(db_get_field "$pkg" "asset")

        [[ -z "$repo" || -z "$asset" ]] && { failed+=("$pkg"); continue; }

        local download_url="https://github.com/${repo}/releases/download/${asset}"

        if ! github_download "$download_url" "$cache_dir"; then
            failed+=("$pkg")
            continue
        fi

        if ! nex_sudo pacman -U --noconfirm "$cache_dir/$asset"; then
            failed+=("$pkg")
        fi
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        nex_msg warn "Failed to upgrade: ${failed[*]}"
        return 1
    fi

    nex_msg success "All packages upgraded successfully."
}
