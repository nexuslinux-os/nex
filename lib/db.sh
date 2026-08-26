#!/usr/bin/env bash

db_check() {
    [[ -f "$NEX_DB_FILE" ]] || nex_die "Package database not found. Run 'nex update' first."
}

db_get_field() {
    local pkg="$1" field="$2"
    awk -v pkg="$pkg" -v field="$field" '
        /^name=/ { current = substr($0, 6) }
        current == pkg && $0 ~ "^" field "=" { print substr($0, length(field)+2); exit }
    ' "$NEX_DB_FILE"
}

db_package_exists() {
    grep -q "^name=$1$" "$NEX_DB_FILE" 2>/dev/null
}

db_search() {
    local query="$1"
    grep -i "$query" "$NEX_DB_FILE" 2>/dev/null | grep "^name=" | cut -d= -f2 | sort -u
}

db_list_all() {
    grep "^name=" "$NEX_DB_FILE" 2>/dev/null | cut -d= -f2 | sort
}

db_list_installed() {
    if [[ -f "$NEX_MANAGED_LIST" ]]; then
        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            local ver
            ver=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
            if [[ -n "$ver" ]]; then
                echo -e "${BOLD}$pkg${RESET} $ver"
            fi
        done < "$NEX_MANAGED_LIST"
    fi
}

db_list_updates() {
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
            echo -e "${BOLD}$pkg${RESET} ${YELLOW}$installed${RESET} -> ${GREEN}$new_ver${RESET}"
        fi
    done < "$NEX_MANAGED_LIST"
}

db_show() {
    local pkg="$1"
    db_package_exists "$pkg" || nex_die "Package '$pkg' not found in database."

    local desc version release arch url license size depends provides conflicts repo asset
    desc=$(db_get_field "$pkg" "desc")
    version=$(db_get_field "$pkg" "version")
    release=$(db_get_field "$pkg" "release")
    arch=$(db_get_field "$pkg" "arch")
    url=$(db_get_field "$pkg" "url")
    license=$(db_get_field "$pkg" "license")
    size=$(db_get_field "$pkg" "size")
    depends=$(db_get_field "$pkg" "depends")
    provides=$(db_get_field "$pkg" "provides")
    conflicts=$(db_get_field "$pkg" "conflicts")
    repo=$(db_get_field "$pkg" "repo")
    asset=$(db_get_field "$pkg" "asset")

    local installed
    installed=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
    [[ -z "$installed" ]] && installed="Not installed"

    echo -e "${BOLD}${CYAN}$pkg${RESET}"
    echo -e "  Version    : ${GREEN}${version}${RESET}"
    [[ -n "$release" ]] && echo -e "  Release    : $release"
    echo -e "  Arch       : $arch"
    [[ -n "$desc" ]]    && echo -e "  Description: $desc"
    [[ -n "$url" ]]     && echo -e "  URL        : $url"
    [[ -n "$license" ]] && echo -e "  License    : $license"
    [[ -n "$size" ]]    && echo -e "  Size       : $((size / 1024 / 1024)) MB"
    [[ -n "$depends" ]] && echo -e "  Depends    : ${depends//|/, }"
    [[ -n "$provides" ]] && echo -e "  Provides   : ${provides//|/, }"
    [[ -n "$conflicts" ]] && echo -e "  Conflicts  : ${conflicts//|/, }"
    [[ -n "$repo" ]]    && echo -e "  Source     : https://github.com/$repo"
    echo -e "  Installed  : $installed"
}

db_is_managed() {
    grep -q "^${1}$" "$NEX_MANAGED_LIST" 2>/dev/null
}

db_mark_managed() {
    if ! db_is_managed "$1"; then
        nex_sudo tee -a "$NEX_MANAGED_LIST" >/dev/null <<< "$1"
    fi
}

db_unmark_managed() {
    if [[ -f "$NEX_MANAGED_LIST" ]]; then
        nex_sudo sed -i "/^${1}$/d" "$NEX_MANAGED_LIST"
    fi
}
