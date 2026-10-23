#!/usr/bin/env bash
# AsusRGB: community installer for Pop!_OS / Ubuntu 24.04.
# Installs upstream asusctl and ROG Control Center.
set -Eeuo pipefail

UPSTREAM_URL="https://github.com/OpenGamingCollective/asusctl.git"
UPSTREAM_COMMIT="15664e8e9177d54de57e9321f6baf972b9113712"

if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: bash install.sh"
    echo "Target: Pop!_OS / Ubuntu 24.04, amd64, Wayland."
    echo "Builds and installs ASUS Control Center from pinned upstream source."
    exit 0
fi

[[ $# -eq 0 ]] || {
    echo "Unknown option. Use --help."
    exit 2
}

[[ $EUID -ne 0 ]] || {
    echo "Run as your normal user, without sudo."
    exit 1
}

source /etc/os-release

if [[ "${VERSION_ID:-}" != "24.04" ||
      ! "${ID:-}" =~ ^(pop|ubuntu)$ ]]; then
    echo "This installer supports Pop!_OS / Ubuntu 24.04."
    exit 1
fi

[[ "$(dpkg --print-architecture)" == "amd64" ]] || {
    echo "This installer supports amd64 systems only."
    exit 1
}

[[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || {
    echo "Run this from a terminal in your Wayland desktop session."
    exit 1
}

STATE_DIR="$HOME/.local/state/asusrgb"
mkdir -p "$STATE_DIR"

LOG="$STATE_DIR/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

trap 'rc=$?; printf "\nFAILED at line %s (exit %s).\nLog: %s\n" \
    "$LINENO" "$rc" "$LOG"; exit "$rc"' ERR

exec 9>"$STATE_DIR/install.lock"
flock -n 9 || {
    echo "Another AsusRGB installer is already running."
    exit 1
}

# Avoid overwriting files owned by installed Debian packages.
for binary in /usr/bin/asusctl /usr/bin/asusd /usr/bin/rog-control-center; do
    if dpkg-query -S "$binary" >/dev/null 2>&1; then
        echo "A Debian package owns $binary."
        echo "Manage that installation through APT before using this installer."
        exit 1
    fi
done

echo "=== AsusRGB installation ==="
echo "Compilation can take several minutes and several GB of disk space."
echo "Existing manually installed ASUS tools may be replaced."
echo "Log: $LOG"

sudo -v

echo "=== Installing build dependencies ==="
sudo apt-get update
sudo apt-get install -y \
    git build-essential cmake pkg-config curl ca-certificates \
    libclang-dev libudev-dev libfontconfig1-dev libxkbcommon-dev \
    libssl-dev libasound2-dev libfreetype6-dev libexpat1-dev \
    libxcb-composite0-dev libx11-dev libseat-dev libinput-dev \
    libgbm-dev libwayland-dev libgtk-3-dev libsystemd-dev \
    libpcre2-dev libzstd-dev gettext

echo "=== Preparing Rust ==="
if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
fi

if ! command -v rustup >/dev/null 2>&1; then
    RUST_INSTALLER="$(mktemp)"
    curl --proto '=https' --tlsv1.2 -fsSL \
        https://sh.rustup.rs -o "$RUST_INSTALLER"

    sh "$RUST_INSTALLER" -y \
        --profile minimal \
        --default-toolchain stable

    rm -f "$RUST_INSTALLER"
    source "$HOME/.cargo/env"
fi

rustup toolchain install stable --profile minimal

echo "=== Downloading pinned ASUS source ==="
mkdir -p "$HOME/src"
BUILD_DIR="$(mktemp -d "$HOME/src/asusrgb-XXXXXXXX")"

git -C "$BUILD_DIR" init
git -C "$BUILD_DIR" remote add origin "$UPSTREAM_URL"
git -C "$BUILD_DIR" fetch --depth 1 origin "$UPSTREAM_COMMIT"
git -C "$BUILD_DIR" checkout --detach FETCH_HEAD

[[ "$(git -C "$BUILD_DIR" rev-parse HEAD)" == "$UPSTREAM_COMMIT" ]] || {
    echo "Downloaded source does not match the expected commit."
    exit 1
}

cd "$BUILD_DIR"
rustup override set stable

echo "=== Building ASUS Control Center ==="
# Limit compilation concurrency to reduce memory pressure.
export CARGO_BUILD_JOBS=4
make

echo "=== Installing ASUS Control Center ==="
sudo env "PATH=$PATH" make install
printf '%s\n' "$BUILD_DIR" > "$STATE_DIR/source-directory"

sudo systemctl daemon-reload
sudo udevadm control --reload-rules

echo "=== Starting ASUS service ==="
# Upstream udev rules handle hardware-based activation at boot.
if ! sudo systemctl restart asusd.service; then
    sudo journalctl -u asusd.service -n 60 --no-pager
    echo "ASUS service failed to start. See the log above."
    exit 1
fi

if ! systemctl is-active --quiet asusd.service; then
    sudo journalctl -u asusd.service -n 60 --no-pager
    echo "ASUS service is not active."
    exit 1
fi

echo "=== Creating AsusRGB launcher ==="
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/AsusRGB" <<'LAUNCHER'
#!/usr/bin/env bash
exec /usr/bin/rog-control-center "$@"
LAUNCHER

chmod 755 "$HOME/.local/bin/AsusRGB"

printf '\nInstallation complete.\n'
printf 'Launch from your app menu: ROG Control Center\n'
printf 'Or run: %s/.local/bin/AsusRGB\n' "$HOME"
printf 'Source directory: %s\n' "$BUILD_DIR"
printf 'Installation log: %s\n' "$LOG"
printf 'GUI log: %s/gui.log\n' "$STATE_DIR"

echo
echo "This is a source installation; APT will not update it."
echo "System76 power management remains enabled."
echo "Use lighting controls first; ASUS power-profile controls may conflict."

nohup "$HOME/.local/bin/AsusRGB" \
    > "$STATE_DIR/gui.log" 2>&1 < /dev/null 9>&- &
