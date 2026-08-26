#!/usr/bin/env bash

# System config or local config
if [[ -f "/etc/nex/nex.conf" ]]; then
    _nex_config_file="/etc/nex/nex.conf"
elif [[ -f "${HOME}/.config/nex/nex.conf" ]]; then
    _nex_config_file="${HOME}/.config/nex/nex.conf"
else
    _nex_config_file="/etc/nex/nex.conf"
fi

nex_config_load() {
    # Load defaults first
    local default_conf
    default_conf="$(dirname "${BASH_SOURCE[0]}")/../config/nex.conf"
    if [[ -f "$default_conf" ]]; then
        # shellcheck source=/dev/null
        source "$default_conf"
    fi

    # Override with system/local config
    if [[ -f "$_nex_config_file" ]]; then
        # shellcheck source=/dev/null
        source "$_nex_config_file"
    fi

    NEX_DB_FILE="${NEX_DB_DIR}/packages.db"
    NEX_MANAGED_LIST="${NEX_DB_DIR}/nex-managed.list"
}

nex_config_init() {
    if [[ -f "$_nex_config_file" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$_nex_config_file")" 2>/dev/null || true

    local src
    src="$(dirname "${BASH_SOURCE[0]}")/../config/nex.conf"
    if [[ -f "$src" ]]; then
        cp "$src" "$_nex_config_file" 2>/dev/null || true
    fi
}

nex_dirs_init() {
    mkdir -p "$NEX_CACHE_DIR"/{packages,sources} 2>/dev/null || true
    mkdir -p "$NEX_DB_DIR" 2>/dev/null || true
    [[ -f "$NEX_MANAGED_LIST" ]] || touch "$NEX_MANAGED_LIST" 2>/dev/null || true
}
