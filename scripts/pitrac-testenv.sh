#!/bin/bash
# Manage an isolated Trixie environment for testing PiTrac installs.
# Uses systemd-nspawn — does not touch the host system or running services.
#
# Usage:
#   pitrac-testenv.sh create    - Create a fresh Trixie environment
#   pitrac-testenv.sh enter     - Shell into the environment
#   pitrac-testenv.sh snapshot  - Save current state as a restore point
#   pitrac-testenv.sh reset     - Restore to last snapshot
#   pitrac-testenv.sh destroy   - Delete everything
#   pitrac-testenv.sh status    - Show environment info

set -euo pipefail

MACHINE_DIR="/var/lib/machines"
ENV_NAME="pitrac-test"
ENV_PATH="$MACHINE_DIR/$ENV_NAME"
SNAP_PATH="$MACHINE_DIR/${ENV_NAME}-snapshot"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

die() { echo -e "${RED}Error:${NC} $*" >&2; exit 1; }
info() { echo -e "${GREEN}>>>${NC} $*"; }
warn() { echo -e "${YELLOW}>>>${NC} $*"; }

need_root() {
    [[ $EUID -eq 0 ]] || die "Run with sudo"
}

cmd_create() {
    need_root
    [[ -d "$ENV_PATH" ]] && die "Environment already exists. Run 'destroy' first or 'enter' to use it."

    info "Creating Trixie environment (~500MB download)..."
    debootstrap --include=systemd,dbus,apt-transport-https,ca-certificates,curl,gnupg,meson,ninja-build,cmake,build-essential,pkg-config,git,python3,python3-pip,python3-venv,sudo trixie "$ENV_PATH"

    # Set up locale
    echo "en_US.UTF-8 UTF-8" > "$ENV_PATH/etc/locale.gen"
    chroot "$ENV_PATH" locale-gen 2>/dev/null || true

    # Set hostname
    echo "pitrac-test" > "$ENV_PATH/etc/hostname"

    # Allow root login without password for convenience
    chroot "$ENV_PATH" passwd -d root

    # Add PiTrac APT repo
    info "Adding PiTrac APT repository..."
    mkdir -p "$ENV_PATH/usr/share/keyrings"
    curl -fsSL https://pitraclm.github.io/packages/pitrac-repo.asc \
        | gpg --dearmor -o "$ENV_PATH/usr/share/keyrings/pitrac-archive-keyring.gpg" 2>/dev/null || warn "Could not fetch GPG key"

    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/pitrac-archive-keyring.gpg] https://pitraclm.github.io/packages trixie main" \
        > "$ENV_PATH/etc/apt/sources.list.d/pitrac.list"

    info "Environment created at $ENV_PATH"
    info "Run 'sudo $0 snapshot' to save this clean state"
    info "Run 'sudo $0 enter' to get a shell"
}

cmd_enter() {
    need_root
    [[ -d "$ENV_PATH" ]] || die "No environment found. Run 'create' first."

    info "Entering test environment (type 'exit' to leave)..."
    info "Host services are NOT affected."
    systemd-nspawn \
        --directory="$ENV_PATH" \
        --bind=/dev/video0 \
        --bind=/dev/video1 \
        --bind=/dev/media0 \
        --bind=/dev/media1 \
        --bind=/dev/media2 \
        --bind=/dev/media3 \
        --bind=/dev/gpiochip0 \
        --bind=/dev/gpiochip4 \
        --bind-ro=/proc/device-tree \
        --bind-ro=/sys/firmware/devicetree \
        --network-veth \
        --capability=all \
        --machine="$ENV_NAME" \
        /bin/bash
}

cmd_snapshot() {
    need_root
    [[ -d "$ENV_PATH" ]] || die "No environment to snapshot."

    info "Saving snapshot..."
    rm -rf "$SNAP_PATH"
    cp -a "$ENV_PATH" "$SNAP_PATH"
    local size=$(du -sh "$SNAP_PATH" | cut -f1)
    info "Snapshot saved ($size)"
}

cmd_reset() {
    need_root
    [[ -d "$SNAP_PATH" ]] || die "No snapshot found. Run 'snapshot' first."

    info "Resetting to snapshot..."
    rm -rf "$ENV_PATH"
    cp -a "$SNAP_PATH" "$ENV_PATH"
    info "Reset complete"
}

cmd_destroy() {
    need_root
    warn "This deletes the test environment and snapshot."
    read -p "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0

    rm -rf "$ENV_PATH" "$SNAP_PATH"
    info "Destroyed"
}

cmd_status() {
    echo "Test environment: $ENV_PATH"
    if [[ -d "$ENV_PATH" ]]; then
        local size=$(du -sh "$ENV_PATH" | cut -f1)
        echo "  Status: exists ($size)"
    else
        echo "  Status: not created"
    fi

    echo "Snapshot: $SNAP_PATH"
    if [[ -d "$SNAP_PATH" ]]; then
        local size=$(du -sh "$SNAP_PATH" | cut -f1)
        echo "  Status: exists ($size)"
    else
        echo "  Status: none"
    fi

    echo ""
    echo "Workflow:"
    echo "  sudo $0 create     # one-time setup"
    echo "  sudo $0 snapshot   # save clean state"
    echo "  sudo $0 enter      # get a shell, install stuff, test"
    echo "  sudo $0 reset      # wipe and restore to snapshot"
}

case "${1:-}" in
    create)   cmd_create ;;
    enter)    cmd_enter ;;
    snapshot) cmd_snapshot ;;
    reset)    cmd_reset ;;
    destroy)  cmd_destroy ;;
    status)   cmd_status ;;
    *)
        echo "Usage: sudo $0 {create|enter|snapshot|reset|destroy|status}"
        exit 1
        ;;
esac
