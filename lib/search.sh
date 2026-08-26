#!/usr/bin/env bash

nex_search() {
    local query="$1"
    [[ -z "$query" ]] && nex_die "Usage: nex search <query>"

    db_check

    local results
    results=$(db_search "$query")

    if [[ -z "$results" ]]; then
        nex_msg warn "No packages found matching '$query'."
        return 1
    fi

    nex_msg info "Packages matching '$query':"
    echo
    while IFS= read -r pkg; do
        local desc version installed
        desc=$(db_get_field "$pkg" "desc")
        version=$(db_get_field "$pkg" "version")
        installed=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}' || true)

        if [[ -n "$installed" ]]; then
            echo -e "  ${GREEN}✓${RESET} ${BOLD}$pkg${RESET} ${CYAN}$version${RESET}"
        else
            echo -e "    ${BOLD}$pkg${RESET} ${CYAN}$version${RESET}"
        fi
        [[ -n "$desc" ]] && echo -e "    ${DIM}$desc${RESET}"
    done <<< "$results"
}

nex_show() {
    local pkg="$1"
    [[ -z "$pkg" ]] && nex_die "Usage: nex show <package>"

    db_check
    db_show "$pkg"
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
            nex_msg info "Total: $count packages"
            ;;
        *)
            nex_die "Usage: nex list {installed|updates|allv}"
            ;;
    esac
}
