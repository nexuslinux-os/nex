# nex completions for fish shell

function __nex_packages
    set -l db_file /var/lib/nex/packages.db
    if test -f "$db_file"
        grep "^name=" "$db_file" 2>/dev/null | cut -d= -f2 | sort
    end
end

function __nex_list_subcmds
    echo installed
    echo updates
    echo allv
end

function __nex_commands
    echo install
    echo remove
    echo purge
    echo reinstall
    echo autoremove
    echo update
    echo upgrade
    echo search
    echo show
    echo list
    echo clean
    echo autoclear
    echo source
    echo build
    echo editsource
end

# Disable default file completions by returning empty for most subcommands
complete -c nex -f

# Main commands
complete -c nex -n "__fish_use_subcommand" -a "(__nex_commands)" -d "Command"

# Commands that take package names
complete -c nex -n "__fish_seen_subcommand_from install remove purge reinstall show source build" -a "(__nex_packages)" -d "Package"

# nex list subcommands
complete -c nex -n "__fish_seen_subcommand_from list" -a "(__nex_list_subcmds)" -d "List type"

# nex search takes a query (allow free text)
complete -c nex -n "__fish_seen_subcommand_from search" -r

# Help and version flags
complete -c nex -s h -l help -d "Show help"
complete -c nex -s v -l version -d "Show version"
