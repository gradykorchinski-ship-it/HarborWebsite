#!/usr/bin/env bash
#
#   Harbor Installer
#   https://harbor.fluxlinux.xyz
#
#   Usage:
#     curl -sSL https://harbor.fluxlinux.xyz/install.sh | bash
#
set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────

VERSION="${HARBOR_VERSION:-2.0.0}"
INSTALL_DIR="${HARBOR_INSTALL_DIR:-$HOME/.harbor/bin}"
BINARY_NAME="harbor"
TARBALL_URL="https://harbor.fluxlinux.xyz/harbor-${VERSION}.tar.gz"
NO_MODIFY_PATH="${HARBOR_NO_MODIFY_PATH:-0}"

# ─── Colors ────────────────────────────────────────────────────────────────

BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

if [ ! -t 1 ]; then
    BOLD="" DIM="" CYAN="" GREEN="" YELLOW="" RED="" RESET=""
fi

info()  { echo -e "${CYAN}  info${RESET}  $*"; }
warn()  { echo -e "${YELLOW}  warn${RESET}  $*"; }
done_() { echo -e "${GREEN}  done${RESET}  $*"; }
fail()  { echo -e "${RED} error${RESET}  $*"; exit 1; }

# ─── Banner ────────────────────────────────────────────────────────────────

banner() {
    echo -e "${BOLD}${CYAN}
    ╦ ╦┌─┐┬─┐┌┐ ┌─┐┬─┐
    ╠═╣├─┤├┬┘├┴┐│ │├┬┘
    ╩ ╩┴ ┴┴└─└─┘└─┘┴└─
${RESET}
  ${DIM}Python-like language → Node.js${RESET}
"
}

# ─── Helpers ───────────────────────────────────────────────────────────────

has() { command -v "$1" >/dev/null 2>&1; }

get() {
    if has curl; then
        curl -fsSL "$1" -o "$2"
    else
        wget -qO "$2" "$1"
    fi
}

# ─── Platform Detection ─────────────────────────────────────────────────────

detect_platform() {
    case "$(uname -s)" in
        Linux*) PLATFORM=linux ;;
        Darwin*) PLATFORM=macos ;;
        *) fail "Unsupported OS" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) ARCH=x86_64 ;;
        aarch64|arm64) ARCH=aarch64 ;;
        *) fail "Unsupported architecture" ;;
    esac

    info "Detected platform: ${PLATFORM} ${ARCH}"
}

# ─── Install From TARBALL ───────────────────────────────────────────────────

install_from_tarball() {
    info "Installing Harbor v${VERSION} from tarball"

    if ! has cargo; then
        warn "Rust not found — installing"
        curl -fsSL https://sh.rustup.rs | sh -s -- -y --quiet
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    tmp="$(mktemp -d)"

    info "Downloading tarball..."
    get "$TARBALL_URL" "$tmp/harbor.tar.gz" || fail "Failed to download tarball"

    info "Extracting..."
    tar xzf "$tmp/harbor.tar.gz" -C "$tmp" --strip-components=1

    info "Building..."
    (cd "$tmp" && cargo build --release)

    mkdir -p "$INSTALL_DIR"
    cp "$tmp/target/release/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"

    rm -rf "$tmp"
    done_ "Harbor installed to ${INSTALL_DIR}/${BINARY_NAME}"
}

# ─── PATH Setup ─────────────────────────────────────────────────────────────

setup_path() {
    [ "$NO_MODIFY_PATH" = "1" ] && return
    grep -q "$INSTALL_DIR" "$HOME/.bashrc" 2>/dev/null && return
    echo -e "\n# Harbor\nexport PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
    info "Added Harbor to PATH"
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
    banner
    detect_platform
    install_from_tarball
    setup_path
    done_ "Installation complete"
}

main "$@"
