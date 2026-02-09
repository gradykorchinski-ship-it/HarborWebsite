#!/usr/bin/env bash
#
#   Harbor Installer
#   https://github.com/gradykorchinski-ship-it/Harbor
#
#   Usage:
#     curl -sSL https://harbor.fluxlinux.xyz/install.sh | bash
#     wget -qO- https://harbor.fluxlinux.xyz/install.sh | bash
#
#   Options (env vars):
#     HARBOR_INSTALL_DIR      Custom install directory (default: ~/.harbor/bin)
#     HARBOR_VERSION          Specific version to install (default: latest)
#     HARBOR_NO_MODIFY_PATH   Set to 1 to skip PATH modification
#
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

VERSION="${HARBOR_VERSION:-latest}"
INSTALL_DIR="${HARBOR_INSTALL_DIR:-$HOME/.harbor/bin}"
GITHUB_REPO="gradykorchinski-ship-it/Harbor"
BINARY_NAME="harbor"
NO_MODIFY_PATH="${HARBOR_NO_MODIFY_PATH:-0}"

# ─── Colors ──────────────────────────────────────────────────────────────────

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

info()    { echo -e "${CYAN}  info${RESET}  $*"; }
success() { echo -e "${GREEN}  done${RESET}  $*"; }
warn()    { echo -e "${YELLOW}  warn${RESET}  $*"; }
error()   { echo -e "${RED} error${RESET}  $*"; exit 1; }

# ─── Banner ──────────────────────────────────────────────────────────────────

banner() {
    echo ""
    echo -e "${BOLD}${CYAN}"
    cat << 'EOF'
    ╦ ╦┌─┐┬─┐┌┐ ┌─┐┬─┐
    ╠═╣├─┤├┬┘├┴┐│ │├┬┘
    ╩ ╩┴ ┴┴└─└─┘└─┘┴└─
EOF
    echo -e "${RESET}"
    echo -e "  ${DIM}Python-like language → Node.js${RESET}"
    echo ""
}

# ─── Helpers ────────────────────────────────────────────────────────────────

has_cmd() { command -v "$1" &>/dev/null; }

download() {
    if has_cmd curl; then
        curl -fsSL "$1" -o "$2"
    else
        wget -qO "$2" "$1"
    fi
}

download_text() {
    if has_cmd curl; then
        curl -fsSL "$1"
    else
        wget -qO- "$1"
    fi
}

# ─── Platform Detection ──────────────────────────────────────────────────────

detect_platform() {
    case "$(uname -s)" in
        Linux*)  PLATFORM="linux" ;;
        Darwin*) PLATFORM="macos" ;;
        *) error "Unsupported OS" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) error "Unsupported architecture" ;;
    esac

    TARGET="${ARCH}-${PLATFORM}"
    info "Detected platform: ${BOLD}${PLATFORM} ${ARCH}${RESET}"
}

# ─── Version Resolution ──────────────────────────────────────────────────────

resolve_version() {
    if [ "$VERSION" = "latest" ]; then
        info "Fetching latest version..."
        VERSION=$(
            download_text "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" |
            grep -o '"tag_name":\s*"[^"]*"' |
            sed 's/.*"v\?\([^"]*\)".*/\1/' || true
        )

        if [ -z "$VERSION" ]; then
            VERSION="2.0.0"
            warn "Could not fetch latest version, defaulting to v${VERSION}"
        fi
    fi

    VERSION="${VERSION#v}"
    info "Installing Harbor ${BOLD}v${VERSION}${RESET}"
}

# ─── Install: Prebuilt ───────────────────────────────────────────────────────

try_prebuilt() {
    local url="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/harbor-v${VERSION}-${TARGET}"
    local tmp
    tmp=$(mktemp)

    info "Trying pre-built binary..."
    if download "$url" "$tmp" && file "$tmp" | grep -qi executable; then
        mkdir -p "$INSTALL_DIR"
        mv "$tmp" "$INSTALL_DIR/$BINARY_NAME"
        chmod +x "$INSTALL_DIR/$BINARY_NAME"
        success "Downloaded pre-built binary"
        return 0
    fi

    rm -f "$tmp"
    return 1
}

# ─── Install: Build From Source (TARBALL ONLY) ───────────────────────────────

build_from_source() {
    info "Building from source..."

    if ! has_cmd cargo; then
        warn "Rust not found — installing"
        download_text https://sh.rustup.rs | sh -s -- -y --quiet
        export PATH="$HOME/.cargo/bin:$PATH"
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)

    local tarball="https://github.com/${GITHUB_REPO}/archive/refs/tags/v${VERSION}.tar.gz"
    info "Downloading source tarball..."
    download "$tarball" "$tmp_dir/src.tar.gz"

    tar xzf "$tmp_dir/src.tar.gz" -C "$tmp_dir" --strip-components=1

    info "Compiling..."
    (cd "$tmp_dir" && cargo build --release)

    mkdir -p "$INSTALL_DIR"
    cp "$tmp_dir/target/release/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"

    rm -rf "$tmp_dir"
    success "Built from source"
}

# ─── PATH Setup ──────────────────────────────────────────────────────────────

setup_path() {
    [ "$NO_MODIFY_PATH" = "1" ] && return
    grep -q "$INSTALL_DIR" "$HOME/.bashrc" 2>/dev/null && return
    echo -e "\n# Harbor\nexport PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    banner
    detect_platform
    resolve_version

    if ! try_prebuilt; then
        build_from_source
    fi

    setup_path
    success "Installation complete"
}

main "$@"
