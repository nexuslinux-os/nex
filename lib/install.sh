#!/usr/bin/env bash

nex_install() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex install <package>"

    db_check
    db_package_exists "$pkg" || nex_die "Package '$pkg' not found in database."

    if pacman -Q "$pkg" &>/dev/null; then
        nex_msg warn "'$pkg' is already installed. Use 'nex reinstall $pkg' to reinstall."
        return 0
    fi

    local depends
    depends=$(db_get_field "$pkg" "depends")
    if [[ -n "$depends" ]]; then
        local missing=()
        IFS='|' read -ra deps <<< "$depends"
        for dep in "${deps[@]}"; do
            dep=$(echo "$dep" | xargs)
            if ! pacman -Q "$dep" &>/dev/null; then
                missing+=("$dep")
            fi
        done
        if [[ ${#missing[@]} -gt 0 ]]; then
            nex_msg info "Installing dependencies: ${missing[*]}"
            nex_sudo pacman -S --noconfirm --needed "${missing[@]}" || nex_die "Failed to install dependencies."
        fi
    fi

    local repo asset checksum
    repo=$(db_get_field "$pkg" "repo")
    asset=$(db_get_field "$pkg" "asset")
    checksum=$(db_get_field "$pkg" "checksum")

    [[ -z "$repo" || -z "$asset" ]] && nex_die "Package source information incomplete."

    local download_url="https://github.com/${repo}/releases/download/${asset}"
    local cache_dir="$NEX_CACHE_DIR/packages"

    github_download "$download_url" "$cache_dir"

    if [[ -n "$checksum" ]]; then
        local file_hash
        file_hash=$(sha256sum "$cache_dir/$asset" | awk '{print $1}')
        if [[ "$file_hash" != "$checksum" ]]; then
            rm -f "$cache_dir/$asset"
            nex_die "Checksum mismatch for '$pkg'. File removed."
        fi
    fi

    nex_msg info "Installing $pkg..."
    nex_sudo pacman -U --noconfirm "$cache_dir/$asset" || nex_die "Failed to install '$pkg'."

    db_mark_managed "$pkg"
    nex_msg success "$pkg installed successfully."
}

nex_remove() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex remove <package>"

    if ! pacman -Q "$pkg" &>/dev/null; then
        nex_die "Package '$pkg' is not installed."
    fi

    if ! db_is_managed "$pkg"; then
        nex_msg warn "'$pkg' was not installed by nex. Use pacman directly."
        return 1
    fi

    nex_msg info "Removing $pkg..."
    nex_sudo pacman -R --noconfirm "$pkg" || nex_die "Failed to remove '$pkg'."

    db_unmark_managed "$pkg"
    nex_msg success "$pkg removed successfully."
}

nex_purge() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex purge <package>"

    if ! pacman -Q "$pkg" &>/dev/null; then
        nex_die "Package '$pkg' is not installed."
    fi

    if ! db_is_managed "$pkg"; then
        nex_msg warn "'$pkg' was not installed by nex. Use pacman directly."
        return 1
    fi

    nex_msg info "Purging $pkg (including config files)..."
    nex_sudo pacman -Rns --noconfirm "$pkg" || nex_die "Failed to purge '$pkg'."

    db_unmark_managed "$pkg"
    nex_msg success "$pkg purged successfully."
}

nex_reinstall() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex reinstall <package>"

    if pacman -Q "$pkg" &>/dev/null; then
        nex_msg info "Removing $pkg first..."
        nex_sudo pacman -Rns --noconfirm "$pkg" || nex_die "Failed to remove '$pkg'."
    fi

    nex_install "$pkg"
}

nex_autoremove() {
    nex_msg info "Finding unused dependencies..."
    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null)

    if [[ -z "$orphans" ]]; then
        nex_msg success "No unused dependencies found."
        return 0
    fi

    nex_msg warn "The following packages will be removed:"
    echo "$orphans"

    if nex_prompt "Proceed? [y/N]"; then
        nex_sudo pacman -Rs --noconfirm $orphans || nex_die "Failed to remove orphan packages."
        nex_msg success "Unused dependencies removed."
    else
        nex_msg info "Aborted."
    fi
}
