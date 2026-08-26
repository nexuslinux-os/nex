#!/usr/bin/env bash

_nex_config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_nex_default_conf="${_nex_config_dir}/../config/nex.conf"

_nex_config_file=""
if [[ -f "/etc/nex/nex.conf" ]]; then
    _nex_config_file="/etc/nex/nex.conf"
elif [[ -f "${HOME}/.config/nex/nex.conf" ]]; then
    _nex_config_file="${HOME}/.config/nex/nex.conf"
fi

nex_config_load() {
    if [[ -f "$_nex_default_conf" ]]; then
        # shellcheck source=/dev/null
        source "$_nex_default_conf"
    fi

    if [[ -n "$_nex_config_file" && -f "$_nex_config_file" ]]; then
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
