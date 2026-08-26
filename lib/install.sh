#!/usr/bin/env bash

_nex_install_desktop() {
    local pkg="$1"
    local desktop_name desktop_exec desktop_categories desktop_comment desktop_icon desktop_terminal

    desktop_name=$(db_get_field "$pkg" "desktop_name")
    desktop_exec=$(db_get_field "$pkg" "desktop_exec")
    desktop_categories=$(db_get_field "$pkg" "desktop_categories")
    desktop_comment=$(db_get_field "$pkg" "desktop_comment")
    desktop_icon=$(db_get_field "$pkg" "desktop_icon")
    desktop_terminal=$(db_get_field "$pkg" "desktop_terminal")

    [[ -z "$desktop_name" || -z "$desktop_exec" ]] && return 0

    local desktop_file="/usr/share/applications/${pkg}.desktop"

    nex_msg info "Creating desktop entry..."
    nex_sudo tee "$desktop_file" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${desktop_name}
Comment=${desktop_comment:-${desktop_name}}
Icon=${desktop_icon:-${pkg}}
Exec=${desktop_exec}
Categories=${desktop_categories:-Utility;}
Terminal=${desktop_terminal:-false}
EOF
}

_nex_remove_desktop() {
    local pkg="$1"
    local desktop_file="/usr/share/applications/${pkg}.desktop"

    if [[ -f "$desktop_file" ]]; then
        nex_sudo rm -f "$desktop_file"
    fi
}

_nex_try_pacman() {
    local pkg="$1"
    if pacman -Si "$pkg" &>/dev/null; then
        return 0
    fi
    return 1
}

_nex_try_aur() {
    local pkg="$1"
    local aur_url="https://aur.archlinux.org/rpc.php"
    local response
    response=$(curl -sL "${aur_url}?type=info&arg[]=${pkg}" 2>/dev/null)
    if echo "$response" | grep -q '"resultcount":1'; then
        return 0
    fi
    return 1
}

_nex_install_from_aur() {
    local pkg="$1"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    nex_msg info "Building $pkg from AUR..."

    if ! git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$tmp_dir/$pkg" 2>/dev/null; then
        rm -rf "$tmp_dir"
        nex_die "Failed to clone AUR repository for '$pkg'."
    fi

    cd "$tmp_dir/$pkg" || nex_die "Cannot enter build directory."

    if [[ ! -f PKGBUILD ]]; then
        rm -rf "$tmp_dir"
        nex_die "No PKGBUILD found for '$pkg' in AUR."
    fi

    makepkg -sf --noconfirm || { rm -rf "$tmp_dir"; nex_die "Failed to build '$pkg' from AUR."; }

    local pkgfile
    pkgfile=$(ls -1 *.pkg.tar.zst 2>/dev/null | head -1)
    if [[ -z "$pkgfile" ]]; then
        rm -rf "$tmp_dir"
        nex_die "Build produced no package file."
    fi

    nex_sudo pacman -U --noconfirm "$pkgfile" || { rm -rf "$tmp_dir"; nex_die "Failed to install '$pkg'."; }

    rm -rf "$tmp_dir"
    return 0
}

nex_install() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex install <package>"

    db_check

    if pacman -Q "$pkg" &>/dev/null; then
        nex_msg warn "'$pkg' is already installed. Use 'nex reinstall $pkg' to reinstall."
        return 0
    fi

    # Source 1: packages.db (GitHub custom packages)
    if db_package_exists "$pkg"; then
        nex_msg info "Found in nex database."

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

        _nex_install_desktop "$pkg"
        db_mark_managed "$pkg"
        nex_msg success "$pkg installed successfully."
        return 0
    fi

    # Source 2: Official Arch repositories
    if _nex_try_pacman "$pkg"; then
        nex_msg info "Found in official Arch repositories."
        nex_sudo pacman -S --noconfirm --needed "$pkg" || nex_die "Failed to install '$pkg' from Arch repos."
        db_mark_managed "$pkg"
        nex_msg success "$pkg installed successfully."
        return 0
    fi

    # Source 3: AUR
    if _nex_try_aur "$pkg"; then
        nex_msg info "Found in AUR."
        _nex_install_from_aur "$pkg"
        db_mark_managed "$pkg"
        nex_msg success "$pkg installed successfully."
        return 0
    fi

    nex_die "Package '$pkg' not found in any source (nex DB, Arch repos, AUR)."
}

nex_remove() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex remove <package>"

    if ! pacman -Q "$pkg" &>/dev/null; then
        nex_die "Package '$pkg' is not installed."
    fi

    nex_msg info "Removing $pkg..."
    nex_sudo pacman -R --noconfirm "$pkg" || nex_die "Failed to remove '$pkg'."

    _nex_remove_desktop "$pkg"
    db_unmark_managed "$pkg"
    nex_msg success "$pkg removed successfully."
}

nex_purge() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex purge <package>"

    if ! pacman -Q "$pkg" &>/dev/null; then
        nex_die "Package '$pkg' is not installed."
    fi

    nex_msg info "Purging $pkg (including config files)..."
    nex_sudo pacman -Rns --noconfirm "$pkg" || nex_die "Failed to purge '$pkg'."

    _nex_remove_desktop "$pkg"
    db_unmark_managed "$pkg"
    nex_msg success "$pkg purged successfully."
}

nex_reinstall() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex reinstall <package>"

    if pacman -Q "$pkg" &>/dev/null; then
        nex_msg info "Removing $pkg first..."
        nex_sudo pacman -Rns --noconfirm "$pkg" || nex_die "Failed to remove '$pkg'."
        _nex_remove_desktop "$pkg"
        db_unmark_managed "$pkg"
    fi

    nex_install "$pkg"
}

nex_autoremove() {
    nex_msg info "Finding unused dependencies..."
    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null || true)

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
