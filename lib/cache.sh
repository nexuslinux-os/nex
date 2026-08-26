#!/usr/bin/env bash

nex_clean() {
    local cache_dir="$NEX_CACHE_DIR/packages"

    if [[ ! -d "$cache_dir" ]] || [[ -z "$(ls -A "$cache_dir" 2>/dev/null)" ]]; then
        nex_msg success "Cache is already clean."
        return 0
    fi

    local size
    size=$(du -sh "$cache_dir" 2>/dev/null | awk '{print $1}')

    nex_msg info "Cleaning package cache ($size)..."
    nex_sudo rm -rf "$cache_dir"/*
    nex_sudo mkdir -p "$cache_dir"

    nex_msg success "Cache cleaned."
}

nex_autoclear() {
    local cache_dir="$NEX_CACHE_DIR/packages"
    local keep="${NEX_KEEP_VERSIONS:-3}"

    if [[ ! -d "$cache_dir" ]] || [[ -z "$(ls -A "$cache_dir" 2>/dev/null)" ]]; then
        nex_msg success "Cache is already clean."
        return 0
    fi

    nex_msg info "Clearing old cache versions (keeping last $keep per package)..."

    local removed=0
    declare -A pkg_files

    for file in "$cache_dir"/*.pkg.tar.zst; do
        [[ -f "$file" ]] || continue
        local basename
        basename=$(basename "$file")
        local pkg_name
        pkg_name=$(echo "$basename" | sed -E 's/-[0-9]+.*$//')
        pkg_files["$pkg_name"]+="$file"$'\n'
    done

    for pkg_name in "${!pkg_files[@]}"; do
        local files
        files=$(echo "${pkg_files[$pkg_name]}" | grep -v '^$' | sort -V)
        local count
        count=$(echo "$files" | wc -l)

        if (( count > keep )); then
            local to_remove
            to_remove=$(echo "$files" | head -n "$((count - keep))")
            while IFS= read -r f; do
                [[ -f "$f" ]] && { nex_sudo rm -f "$f"; ((removed++)); }
            done <<< "$to_remove"
        fi
    done

    nex_msg success "Removed $removed old cache files."
}
