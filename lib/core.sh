#!/usr/bin/env bash

NEX_VERSION="1.0.0"

# Colors
if [[ -t 1 ]] && [[ "${NEX_COLOR:-auto}" != "never" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' RESET=''
fi

nex_msg() {
    local type="$1" msg="$2"
    case "$type" in
        info)    echo -e "${BLUE}::${RESET} $msg" ;;
        success) echo -e "${GREEN}::${RESET} $msg" ;;
        warn)    echo -e "${YELLOW}warning:${RESET} $msg" ;;
        error)   echo -e "${RED}error:${RESET} $msg" ;;
        ask)     echo -ne "${CYAN}?${RESET} $msg " ;;
    esac
}

nex_die() {
    nex_msg error "$1"
    exit "${2:-1}"
}

nex_prompt() {
    local msg="$1"
    nex_msg ask "$msg"
    read -r answer
    [[ "$answer" =~ ^[YyEe]$ ]]
}

nex_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif command -v sudo &>/dev/null; then
        sudo "$@"
    else
        nex_die "Root privileges required. Run as root or install sudo."
    fi
}

nex_root_check() {
    if [[ $EUID -ne 0 ]]; then
        nex_die "This operation requires root privileges."
    fi
}

nex_depends_on() {
    command -v "$1" &>/dev/null || nex_die "'$1' is required but not installed."
}

nex_version_cmp() {
    local v1="$1" v2="$2"
    if [[ "$v1" == "$v2" ]]; then
        echo "0"
    elif printf '%s\n%s' "$v2" "$v1" | sort -V | head -1 | grep -q "^${v2}$"; then
        echo "1"
    else
        echo "-1"
    fi
}

_nex_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/nex.conf
source "${_nex_source_dir}/../config/nex.conf"
