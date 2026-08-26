# nex Package Database

Nexus Linux Package Manager (nex) package database.

## Format

```
name=<package>
desc=<description>
version=<version>
release=<release>
arch=<architecture>
url=<homepage>
license=<license>
size=<size in bytes>
depends=<dep1|dep2|dep3>
provides=<provides1|provides2>
conflicts=<conflict1|conflict2>
repo=<github-owner/repo>
asset=<filename.pkg.tar.zst>
checksum=<sha256>
```

## Usage

```bash
# Update database
nex update

# Search packages
nex search <query>

# Install
nex install <package>
```

## Adding Packages

1. Create a GitHub repo for the package binary
2. Upload `.pkg.tar.zst` file as a release asset
3. Add package entry to `packages.db`
4. Commit and push
