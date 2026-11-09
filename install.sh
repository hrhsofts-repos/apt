#!/bin/sh
# Install HRHsofts apps (HRHsuite) on Ubuntu 26.04 or later from the signed HRHsuite APT repository.
#
#   wget -qO- https://hrhsofts-repos.github.io/apt/install.sh | sudo sh                   every app
#   wget -qO- https://hrhsofts-repos.github.io/apt/install.sh | sudo sh -s -- pdfviewer   chosen apps
#   wget -qO- https://hrhsofts-repos.github.io/apt/install.sh | sudo sh -s -- all         apps and the HRHsofts desktop
#
# Names: apps, desktop, all, or any of the APPS and DESKTOP below (with or without "hrhsofts-").
# It first installs hrhsofts-updater, which adds the repository and its signing key; from then on
# the apps update together with the rest of the system (Software Updater, "sudo apt upgrade").
set -eu
REPO=https://hrhsuiteupdates.blob.core.windows.net/apt
APPS="calculator cipherpost cleaner downloader imageviewer mediaplayer pdfviewer recorder screencapture whatsapp"
DESKTOP="files share cloud topbar windows-on-top desktop-menu desktop-defaults branding"

if [ "$(id -u)" != 0 ]; then
    echo "Run it with sudo:  wget -qO- https://hrhsofts-repos.github.io/apt/install.sh | sudo sh" >&2
    exit 1
fi
command -v apt-get >/dev/null 2>&1 || { echo "HRHsuite needs Ubuntu (apt-get was not found)." >&2; exit 1; }
[ "$(dpkg --print-architecture)" = amd64 ] || { echo "HRHsuite is built for 64-bit PCs (amd64)." >&2; exit 1; }

[ $# -gt 0 ] || set -- apps
packages=""
for name in "$@"; do
    case $name in
        apps) list=$APPS ;;
        desktop) list=$DESKTOP ;;
        all) list="$APPS $DESKTOP" ;;
        *) list=${name#hrhsofts-} ;;
    esac
    for item in $list; do
        case " $APPS $DESKTOP updater fast-boot " in
            *" $item "*) packages="$packages hrhsofts-$item" ;;
            *) echo "Unknown HRHsuite component: $item" >&2
               echo "Choose from: apps desktop all $APPS $DESKTOP fast-boot" >&2
               exit 2 ;;
        esac
    done
done

fetch() {  # URL FILE
    if command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"; else curl -fsSL -o "$2" "$1"; fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
chmod 755 "$tmp"  # apt reads the package as the unprivileged _apt user

echo "Adding the HRHsuite repository..."
fetch "$REPO/catalog.json" "$tmp/catalog.json"
updater=$(python3 - "$tmp/catalog.json" <<'PY'
import json, sys
entry = json.load(open(sys.argv[1]))["packages"]["hrhsofts-updater"]
if not entry["deb"].startswith("https://hrhsuiteupdates.blob.core.windows.net/apt/pool/"):
    raise SystemExit("unexpected package location")
print(entry["deb"], entry["sha256"])
PY
)
set -- $updater
fetch "$1" "$tmp/hrhsofts-updater.deb"
echo "$2  $tmp/hrhsofts-updater.deb" | sha256sum -c --quiet -
chmod 644 "$tmp/hrhsofts-updater.deb"
apt-get install -y "$tmp/hrhsofts-updater.deb"

echo "Installing:$packages"
apt-get update
# shellcheck disable=SC2086
apt-get install -y $packages
echo
echo "Done. The apps are in the app grid; updates arrive through Software Updater."
