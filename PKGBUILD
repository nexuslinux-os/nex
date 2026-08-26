# Maintainer: Nexus Linux <nexus.dev.tr@gmail.com>

pkgname=nex
pkgver=1.0.0
pkgrel=1
pkgdesc="Nexus Linux Package Manager"
arch=('x86_64')
url="https://github.com/nexuslinux-os/nex"
license=('GPL3')
depends=('bash' 'curl' 'wget' 'pacman' 'git')
source=("$url/archive/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$srcdir/nex-$pkgver"

    install -Dm755 nex "$pkgdir/usr/bin/nex"
    install -Dm644 config/nex.conf "$pkgdir/etc/nex/nex.conf"

    for f in lib/*.sh; do
        install -Dm644 "$f" "$pkgdir/usr/share/nex/lib/$(basename "$f")"
    done

    install -Dm644 completions/nex.bash "$pkgdir/usr/share/bash-completion/completions/nex"
    install -Dm644 completions/nex.fish "$pkgdir/usr/share/fish/vendor_completions.d/nex.fish"
}
