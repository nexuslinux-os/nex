# nex - Nexus Linux Package Manager

Fast, transparent package manager for Nexus Linux.

## Features

- GitHub-based package database
- Fast text-based package database (grep/awk)
- Bash and Fish shell completions
- Parallel downloads
- Cache management

## Installation

### From AUR (recommended)
```bash
yay -S nex
```

### Manual
```bash
git clone https://github.com/nexuslinux-os/nex.git
cd nex
sudo make install
```

## Usage

```bash
nex update                 # Update package database
nex install <package>      # Install a package
nex remove <package>       # Remove a package
nex purge <package>        # Remove with config files
nex reinstall <package>    # Reinstall a package
nex autoremove             # Remove unused dependencies

nex search <query>         # Search packages
nex show <package>         # Show package info
nex list installed         # List installed packages
nex list updates           # List available updates
nex list allv              # List all packages

nex clean                  # Clear cache
nex autoclear              # Remove old cache versions

nex source <package>       # Get package source
nex build <package>        # Build from source
```

## Package Database

Packages are stored in `packages.db` with format:

```
name=firefox
desc=Standalone web browser from Mozilla
version=131.0
release=1
arch=x86_64
url=https://www.mozilla.org/firefox/
license=MPL-2.0
size=89000000
depends=gtk3|libxt|nss|dbus-glib
repo=nexuslinux-os/firefox-bin
asset=firefox-131.0-1-x86_64.pkg.tar.zst
checksum=
```

## Contributing

1. Fork the repository
2. Add your package to `packages.db`
3. Submit a pull request

## License

GPL-3.0
