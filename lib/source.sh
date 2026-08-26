#!/usr/bin/env bash

nex_source() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex source <package>"

    db_check
    db_package_exists "$pkg" || nex_die "Package '$pkg' not found in database."

    local repo
    repo=$(db_get_field "$pkg" "repo")
    [[ -z "$repo" ]] && nex_die "No source repository defined for '$pkg'."

    local src_dir="$NEX_CACHE_DIR/sources/$pkg"

    if [[ -d "$src_dir" ]]; then
        nex_msg info "Source already exists at $src_dir"
        return 0
    fi

    nex_msg info "Cloning source for $pkg..."
    nex_sudo mkdir -p "$NEX_CACHE_DIR/sources"
    git clone --depth 1 "https://github.com/${repo}.git" "$src_dir" || nex_die "Failed to clone source."

    nex_msg success "Source cloned to $src_dir"
}

nex_build() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex build <package>"

    local src_dir="$NEX_CACHE_DIR/sources/$pkg"

    if [[ ! -d "$src_dir" ]]; then
        nex_msg info "Source not found, fetching..."
        nex_source "$pkg"
    fi

    nex_msg info "Building $pkg..."
    cd "$src_dir" || nex_die "Cannot enter source directory."

    if [[ -f PKGBUILD ]]; then
        makepkg -sf || nex_die "Build failed for '$pkg'."
        local pkgfile
        pkgfile=$(ls -1 *.pkg.tar.zst 2>/dev/null | head -1)
        if [[ -n "$pkgfile" ]]; then
            nex_msg info "Installing built package..."
            nex_sudo pacman -U --noconfirm "$pkgfile" || nex_die "Failed to install built package."
            db_mark_managed "$pkg"
            nex_msg success "$pkg built and installed successfully."
        else
            nex_die "Build produced no package file."
        fi
    else
        nex_die "No PKGBUILD found in source directory."
    fi
}

nex_editsource() {
    local edit_cmd="${NEXEDITOR:-nano}"
    local src_dir="$NEX_CACHE_DIR/sources"

    if [[ ! -d "$src_dir" ]] || [[ -z "$(ls -A "$src_dir" 2>/dev/null)" ]]; then
        nex_msg info "No sources found. Use 'nex source <package>' first."
        return 1
    fi

    nex_msg info "Opening sources directory..."
    exec "$edit_cmd" "$src_dir"
}
