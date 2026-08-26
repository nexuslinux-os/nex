#!/usr/bin/env bash

_nex_completions() {
    local cur prev commands db_file
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="install remove purge reinstall autoremove update upgrade search show list clean autoclear source build editsource"

    db_file="/var/lib/nex/packages.db"

    _nex_get_packages() {
        if [[ -f "$db_file" ]]; then
            grep "^name=" "$db_file" 2>/dev/null | cut -d= -f2 | sort
        fi
    }

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    case "$prev" in
        install|remove|purge|reinstall|show|source|build)
            local packages
            packages=$(_nex_get_packages)
            COMPREPLY=( $(compgen -W "$packages" -- "$cur") )
            return 0
            ;;
        list)
            COMPREPLY=( $(compgen -W "installed updates allv" -- "$cur") )
            return 0
            ;;
    esac

    return 0
}

complete -F _nex_completions nex
