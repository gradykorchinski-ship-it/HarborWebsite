#!/usr/bin/env bash
#
#   Harbor Installer
#   https://github.com/gradykorchinski-ship-it/harbor
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
<<<<<<< HEAD
GITHUB_REPO="gradykorchinski-ship-it/Harbor"
=======
GITHUB_REPO="stormyy00/harbor"
>>>>>>> origin/main
BINARY_NAME="harbor"
NO_MODIFY_PATH="${HARBOR_NO_MODIFY_PATH:-0}"

# ─── Colors & Output ────────────────────────────────────────────────────────

BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Disable colors if not a terminal
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

# ─── Platform Detection ─────────────────────────────────────────────────────

detect_platform() {
    local os arch

    case "$(uname -s)" in
        Linux*)          os="linux" ;;
        Darwin*)         os="macos" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)               error "Unsupported operating system: $(uname -s)" ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)    arch="x86_64" ;;
        aarch64|arm64)   arch="aarch64" ;;
        armv7*)          arch="armv7" ;;
        *)               error "Unsupported architecture: $(uname -m)" ;;
    esac

    PLATFORM="${os}"
    ARCH="${arch}"
    TARGET="${arch}-${os}"

    info "Detected platform: ${BOLD}${os} ${arch}${RESET}"
}

# ─── Dependency Checks ──────────────────────────────────────────────────────

has_cmd() { command -v "$1" &>/dev/null; }

check_deps() {
    if ! has_cmd curl && ! has_cmd wget; then
        error "Either ${BOLD}curl${RESET} or ${BOLD}wget${RESET} is required"
    fi

    if ! has_cmd node; then
        warn "Node.js not found — you'll need it to run compiled Harbor files"
        warn "Install Node.js: ${DIM}https://nodejs.org${RESET}"
    else
        local node_ver
        node_ver=$(node --version 2>/dev/null || echo "unknown")
        info "Node.js ${node_ver} found"
    fi
}

# ─── Download Helpers ────────────────────────────────────────────────────────

download() {
    local url="$1" dest="$2"
    if has_cmd curl; then
        curl -fsSL "$url" -o "$dest"
    elif has_cmd wget; then
        wget -qO "$dest" "$url"
    fi
}

download_text() {
    local url="$1"
    if has_cmd curl; then
        curl -fsSL "$url"
    elif has_cmd wget; then
        wget -qO- "$url"
    fi
}

# ─── Resolve Version ────────────────────────────────────────────────────────

resolve_version() {
    if [ "$VERSION" = "latest" ]; then
        info "Fetching latest version..."
        local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
        local response
        response=$(download_text "$api_url" 2>/dev/null || echo "")

        if [ -n "$response" ]; then
            VERSION=$(echo "$response" | grep -o '"tag_name":\s*"[^"]*"' | head -1 | sed 's/.*"v\?\([^"]*\)".*/\1/' || echo "")
        fi

        if [ -z "$VERSION" ] || [ "$VERSION" = "latest" ]; then
            VERSION="2.0.0"
            warn "Could not fetch latest version, defaulting to v${VERSION}"
        fi
    fi

    VERSION="${VERSION#v}"
    info "Installing Harbor ${BOLD}v${VERSION}${RESET}"
}

# ─── Install: Pre-built Binary ──────────────────────────────────────────────

try_prebuilt() {
    local ext=""
    [ "$PLATFORM" = "windows" ] && ext=".exe"

    local asset_name="harbor-v${VERSION}-${TARGET}${ext}"
    local url="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${asset_name}"
    local tmp_file
    tmp_file=$(mktemp)

    info "Trying pre-built binary..."
    if download "$url" "$tmp_file" 2>/dev/null; then
        if file "$tmp_file" 2>/dev/null | grep -qiE "executable|ELF|Mach-O"; then
            mkdir -p "$INSTALL_DIR"
            mv "$tmp_file" "${INSTALL_DIR}/${BINARY_NAME}"
            chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
            success "Downloaded pre-built binary"
            return 0
        fi
    fi

    rm -f "$tmp_file"
    return 1
}

# ─── Install: Release Archive ───────────────────────────────────────────────

try_tar_release() {
    local ext="tar.gz"
    [ "$PLATFORM" = "windows" ] && ext="zip"

    local asset_name="harbor-v${VERSION}-${TARGET}.${ext}"
    local url="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${asset_name}"
    local tmp_file
    tmp_file=$(mktemp)

    info "Trying release archive..."
    if download "$url" "$tmp_file" 2>/dev/null; then
        local tmp_dir
        tmp_dir=$(mktemp -d)

        if [ "$ext" = "tar.gz" ]; then
            tar xzf "$tmp_file" -C "$tmp_dir" 2>/dev/null || { rm -rf "$tmp_file" "$tmp_dir"; return 1; }
        else
            unzip -qo "$tmp_file" -d "$tmp_dir" 2>/dev/null || { rm -rf "$tmp_file" "$tmp_dir"; return 1; }
        fi

        local found_bin
        found_bin=$(find "$tmp_dir" -name "${BINARY_NAME}" -type f 2>/dev/null | head -1)

        if [ -n "$found_bin" ]; then
            mkdir -p "$INSTALL_DIR"
            mv "$found_bin" "${INSTALL_DIR}/${BINARY_NAME}"
            chmod +x "${INSTALL_DIR}/${BINARY_NAME}"
            rm -rf "$tmp_file" "$tmp_dir"
            success "Extracted from release archive"
            return 0
        fi

        rm -rf "$tmp_file" "$tmp_dir"
    fi

    rm -f "$tmp_file"
    return 1
}

# ─── Install: Build from Source ──────────────────────────────────────────────

build_from_source() {
    info "Building from source..."

    if ! has_cmd cargo; then
        warn "Rust is not installed"
        info "Installing Rust via rustup..."

        download_text "https://sh.rustup.rs" | sh -s -- -y --quiet 2>/dev/null
        export PATH="$HOME/.cargo/bin:$PATH"

        if ! has_cmd cargo; then
            error "Failed to install Rust. Install manually: ${DIM}https://rustup.rs${RESET}"
        fi
        success "Rust installed"
    else
        local rust_ver
        rust_ver=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "unknown")
        info "Rust ${rust_ver} found"
    fi

    local build_dir
    build_dir=$(mktemp -d)

    info "Cloning Harbor repository..."
    if has_cmd git; then
        git clone --depth 1 --branch "v${VERSION}" "https://github.com/${GITHUB_REPO}.git" "$build_dir" 2>/dev/null \
            || git clone --depth 1 "https://github.com/${GITHUB_REPO}.git" "$build_dir" 2>/dev/null \
            || error "Failed to clone repository"
    else
        local tarball_url="https://github.com/${GITHUB_REPO}/archive/refs/tags/v${VERSION}.tar.gz"
        local fallback_url="https://github.com/${GITHUB_REPO}/archive/refs/heads/main.tar.gz"
        local tmp_tar
        tmp_tar=$(mktemp)

        download "$tarball_url" "$tmp_tar" 2>/dev/null || download "$fallback_url" "$tmp_tar" 2>/dev/null \
            || error "Failed to download source code"

        tar xzf "$tmp_tar" -C "$build_dir" --strip-components=1 2>/dev/null \
            || error "Failed to extract source code"
        rm -f "$tmp_tar"
    fi

    info "Compiling (this may take a moment)..."
    (cd "$build_dir" && cargo build --release --quiet 2>&1) \
        || error "Compilation failed"

    mkdir -p "$INSTALL_DIR"
    cp "${build_dir}/target/release/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    rm -rf "$build_dir"
    success "Built from source"
}

# ─── PATH Setup ──────────────────────────────────────────────────────────────

setup_path() {
    if [ "$NO_MODIFY_PATH" = "1" ]; then
        return
    fi

    if [[ ":$PATH:" == *":${INSTALL_DIR}:"* ]]; then
        return
    fi

    local shell_name
    shell_name=$(basename "${SHELL:-/bin/bash}")
    local export_line="export PATH=\"${INSTALL_DIR}:\$PATH\""
    local rc_file=""

    case "$shell_name" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                rc_file="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                rc_file="$HOME/.bash_profile"
            else
                rc_file="$HOME/.bashrc"
            fi
            ;;
        zsh)
            rc_file="$HOME/.zshrc"
            ;;
        fish)
            rc_file="$HOME/.config/fish/config.fish"
            export_line="set -gx PATH ${INSTALL_DIR} \$PATH"
            ;;
        *)
            rc_file="$HOME/.profile"
            ;;
    esac

    # Don't add duplicate entries
    if [ -f "$rc_file" ] && grep -qF "$INSTALL_DIR" "$rc_file" 2>/dev/null; then
        return
    fi

    echo "" >> "$rc_file"
    echo "# Harbor" >> "$rc_file"
    echo "$export_line" >> "$rc_file"
    info "Added Harbor to PATH in ${DIM}${rc_file}${RESET}"
}

# ─── Verify Installation ────────────────────────────────────────────────────

verify_install() {
    export PATH="${INSTALL_DIR}:$PATH"

    if "${INSTALL_DIR}/${BINARY_NAME}" --version &>/dev/null; then
        local ver
        ver=$("${INSTALL_DIR}/${BINARY_NAME}" --version 2>/dev/null)
        success "Installed ${BOLD}${ver}${RESET} → ${DIM}${INSTALL_DIR}/${BINARY_NAME}${RESET}"
    else
        warn "Binary installed but could not verify version"
    fi
}

# ─── Summary ─────────────────────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "${BOLD}  Installation complete!${RESET}"
    echo ""
    echo -e "  ${DIM}Get started:${RESET}"
    echo ""
    echo -e "    ${CYAN}# Create a file${RESET}"
    echo -e "    echo 'print f\"Hello from Harbor!\"' > hello.hb"
    echo ""
    echo -e "    ${CYAN}# Compile and run${RESET}"
    echo -e "    harbor hello.hb -o hello.js && node hello.js"
    echo ""
    echo -e "    ${CYAN}# Or run directly${RESET}"
    echo -e "    harbor hello.hb"
    echo ""

    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        echo -e "  ${YELLOW}Restart your terminal or run:${RESET}"
        echo -e "    export PATH=\"${INSTALL_DIR}:\$PATH\""
        echo ""
    fi

    echo -e "  ${DIM}Docs: https://github.com/${GITHUB_REPO}${RESET}"
    echo ""
}

# ─── Uninstall ───────────────────────────────────────────────────────────────

uninstall() {
    banner
    info "Uninstalling Harbor..."

    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        rm -f "${INSTALL_DIR}/${BINARY_NAME}"
        success "Removed ${INSTALL_DIR}/${BINARY_NAME}"
    else
        warn "Harbor binary not found in ${INSTALL_DIR}"
    fi

    # Clean up empty dirs
    if [ -d "$INSTALL_DIR" ] && [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
        rmdir "$INSTALL_DIR" 2>/dev/null
        rmdir "$(dirname "$INSTALL_DIR")" 2>/dev/null || true
    fi

    info "You may want to remove the PATH entry from your shell config"
    echo ""
    exit 0
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    for arg in "$@"; do
        case "$arg" in
            --uninstall|uninstall) uninstall ;;
            --help|-h)
                echo "Harbor Installer"
                echo ""
                echo "Usage:"
                echo "  curl -sSL https://harbor.fluxlinux.xyz/install.sh | bash"
                echo "  bash install.sh [--uninstall]"
                echo ""
                echo "Options (env vars):"
                echo "  HARBOR_INSTALL_DIR      Install directory (default: ~/.harbor/bin)"
                echo "  HARBOR_VERSION          Version to install (default: latest)"
                echo "  HARBOR_NO_MODIFY_PATH   Set to 1 to skip PATH modification"
                exit 0
                ;;
        esac
    done

    banner
    detect_platform
    check_deps
    resolve_version

    # Try install methods in order: pre-built → archive → build from source
    if try_prebuilt; then
        true
    elif try_tar_release; then
        true
    else
        info "No pre-built binary available, building from source..."
        build_from_source
    fi

    setup_path
    verify_install
    print_summary
}

main "$@"
