#!/usr/bin/env bash

_nex_curl() {
    curl -sL --connect-timeout 10 --max-time 30 "$@"
}

github_latest_release() {
    local repo="$1"
    _nex_curl "${NEX_GITHUB_API}/repos/${repo}/releases/latest" | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

github_release_assets() {
    local repo="$1" tag="$2"
    _nex_curl "${NEX_GITHUB_API}/repos/${repo}/releases/tags/${tag}" | grep '"browser_download_url"' | sed -E 's/.*"browser_download_url": *"([^"]+)".*/\1/'
}

github_download() {
    local url="$1" dest="$2"
    local filename
    filename=$(basename "$url")

    if [[ -f "$dest/$filename" ]]; then
        nex_msg info "Already cached: $filename"
        return 0
    fi

    nex_msg info "Downloading $filename..."
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$dest/$filename" "$url"
    elif command -v curl &>/dev/null; then
        curl -# -L -o "$dest/$filename" "$url"
    else
        nex_die "Neither wget nor curl found."
    fi
}

github_download_db() {
    local tag="$1"
    local repo="${NEX_DB_REPO}"
    local url="https://github.com/${repo}/releases/download/${tag}/packages.db"
    local tmp_file
    tmp_file=$(mktemp)

    nex_msg info "Downloading package database..."
    if ! wget -q -O "$tmp_file" "$url" 2>/dev/null && ! _nex_curl -o "$tmp_file" "$url" 2>/dev/null; then
        rm -f "$tmp_file"
        nex_die "Failed to download package database."
    fi

    nex_sudo cp "$tmp_file" "$NEX_DB_FILE"
    rm -f "$tmp_file"
}
