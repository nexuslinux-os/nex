#!/usr/bin/env bash

nex_search() {
    local query="$1"
    [[ -z "$query" ]] && nex_die "Usage: nex search <query>"

    db_check

    local found=0

    # Search nex database
    local results
    results=$(db_search "$query")
    if [[ -n "$results" ]]; then
        nex_msg info "Results from nex database:"
        echo
        while IFS= read -r pkg; do
            local desc version installed
            desc=$(db_get_field "$pkg" "desc")
            version=$(db_get_field "$pkg" "version")
            installed=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)

            if [[ -n "$installed" ]]; then
                echo -e "  ${GREEN}✓${RESET} ${BOLD}$pkg${RESET} ${CYAN}$version${RESET} ${DIM}[nex]${RESET}"
            else
                echo -e "    ${BOLD}$pkg${RESET} ${CYAN}$version${RESET} ${DIM}[nex]${RESET}"
            fi
            [[ -n "$desc" ]] && echo -e "    ${DIM}$desc${RESET}"
            ((found++)) || true
        done <<< "$results"
    fi

    # Search Arch repos
    local arch_results
    arch_results=$(pacman -Ss "$query" 2>/dev/null || true)
    if [[ -n "$arch_results" ]]; then
        nex_msg info "Results from Arch repositories:"
        echo
        echo "$arch_results" | while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([^/]+)/([^[:space:]]+)[[:space:]]+([0-9.]+) ]]; then
                local repo_name pkg_name version
                repo_name="${BASH_REMATCH[1]}"
                pkg_name="${BASH_REMATCH[2]}"
                version="${BASH_REMATCH[3]}"
                local installed
                installed=$(pacman -Q "$pkg_name" 2>/dev/null | awk '{print $2}' || true)

                if [[ -n "$installed" ]]; then
                    echo -e "  ${GREEN}✓${RESET} ${BOLD}$pkg_name${RESET} ${CYAN}$version${RESET} ${DIM}[$repo_name]${RESET}"
                else
                    echo -e "    ${BOLD}$pkg_name${RESET} ${CYAN}$version${RESET} ${DIM}[$repo_name]${RESET}"
                fi
                ((found++)) || true
            fi
        done
    fi

    if [[ $found -eq 0 ]]; then
        nex_msg warn "No packages found matching '$query'."
        return 1
    fi
}

nex_show() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex show <package>"

    db_check

    # Check nex database first
    if db_package_exists "$pkg"; then
        db_show "$pkg"
        return 0
    fi

    # Check Arch repos
    local arch_info
    arch_info=$(pacman -Si "$pkg" 2>/dev/null || true)
    if [[ -n "$arch_info" ]]; then
        echo -e "${BOLD}${CYAN}$pkg${RESET} ${DIM}[Arch Repository]${RESET}"
        echo "$arch_info" | while IFS='=' read -r key value; do
            case "$key" in
                Name)         echo -e "  Name        : ${BOLD}$value${RESET}" ;;
                Version)      echo -e "  Version     : ${GREEN}$value${RESET}" ;;
                Description)  echo -e "  Description : $value" ;;
                Architecture) echo -e "  Arch        : $value" ;;
                URL)          echo -e "  URL         : $value" ;;
                Licenses)     echo -e "  License     : $value" ;;
                Provides)     echo -e "  Provides    : $value" ;;
                Depends\ On)  echo -e "  Depends     : $value" ;;
            esac
        done
        local installed
        installed=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)
        echo -e "  Installed   : ${installed:-Not installed}"
        return 0
    fi

    nex_die "Package '$pkg' not found."
}

nex_list() {
    local subcmd="$1"
    db_check

    case "$subcmd" in
        installed)
            nex_msg info "Installed packages (managed by nex):"
            echo
            local output
            output=$(db_list_installed)
            if [[ -z "$output" ]]; then
                nex_msg warn "No nex-managed packages installed."
            else
                echo "$output"
            fi
            ;;
        updates)
            nex_msg info "Available updates:"
            echo
            local output
            output=$(db_list_updates)
            if [[ -z "$output" ]]; then
                nex_msg success "All packages are up to date."
            else
                echo "$output"
            fi
            ;;
        allv)
            nex_msg info "All available packages:"
            echo
            local count=0
            while IFS= read -r pkg; do
                local version installed
                version=$(db_get_field "$pkg" "version")
                installed=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)
                if [[ -n "$installed" ]]; then
                    echo -e "  ${GREEN}✓${RESET} ${BOLD}$pkg${RESET} ${CYAN}$version${RESET}"
                else
                    echo -e "    ${BOLD}$pkg${RESET} ${CYAN}$version${RESET}"
                fi
                ((count++)) || true
            done < <(db_list_all)
            echo
            nex_msg info "Total: $count packages (nex database)"
            ;;
        *)
            nex_die "Usage: nex list {installed|updates|allv}"
            ;;
    esac
}
