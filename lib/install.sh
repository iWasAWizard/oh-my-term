# shellcheck shell=bash
#
# Helpers shared by setup.sh and scripts/vendor.sh. Sourced, never run directly.
# Keep this file compatible with bash 3.2 (the bash that ships with macOS).

log() {
    printf '==> %s\n' "$*"
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

timestamp() {
    date +%Y%m%d%H%M%S
}

# link_file SRC DST
# Makes DST a symlink to SRC. Anything already at DST is moved aside first.
link_file() {
    local src="$1"
    local dst="$2"
    local bak

    [ -e "$src" ] || die "missing source file: ${src}"
    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        log "${dst} already linked"
        return 0
    fi
    if [ -e "$dst" ] && [ "$src" -ef "$dst" ]; then
        log "${dst} already is the repo file"
        return 0
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        bak="${dst}.bak.$(timestamp)"
        mv -- "$dst" "$bak"
        log "Moved ${dst} to ${bak}"
    fi
    ln -s -- "$src" "$dst"
    log "Linked ${dst} -> ${src}"
}

# seed_file SRC DST
# Copies SRC to DST only when DST does not exist. Used for files that a tool
# rewrites itself, where a symlink into the repo would let the tool edit the repo.
seed_file() {
    local src="$1"
    local dst="$2"

    [ -e "$src" ] || die "missing source file: ${src}"
    if [ -e "$dst" ]; then
        log "${dst} already exists, leaving it alone"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp -- "$src" "$dst"
    log "Created ${dst}"
}

# copy_dir_if_missing SRC DST
copy_dir_if_missing() {
    local src="$1"
    local dst="$2"

    if [ -e "$dst" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp -R -- "$src" "$dst"
    log "Copied ${src} to ${dst}"
}

# clone_or_update URL DIR
# Fresh shallow clone, or a fast-forward pull when DIR is already a checkout.
clone_or_update() {
    local url="$1"
    local dir="$2"

    if [ -d "${dir}/.git" ]; then
        git -C "$dir" pull --ff-only --quiet || warn "could not fast-forward ${dir}, leaving it as is"
    elif [ -e "$dir" ]; then
        log "${dir} exists and is not a git checkout, leaving it alone"
    else
        mkdir -p "$(dirname "$dir")"
        git clone --quiet --depth 1 "$url" "$dir" || return 1
    fi
}

# platform: macos, unraid or linux
detect_platform() {
    if [ -n "${OMT_PLATFORM:-}" ]; then
        printf '%s\n' "$OMT_PLATFORM"
    elif [ -f /etc/unraid-version ]; then
        printf 'unraid\n'
    else
        case "$(uname -s)" in
            Darwin) printf 'macos\n' ;;
            Linux) printf 'linux\n' ;;
            *) die "unsupported OS: $(uname -s)" ;;
        esac
    fi
}

# starship release target for this machine, for example aarch64-apple-darwin
starship_target() {
    local os arch

    case "$(uname -s)" in
        Darwin) os="apple-darwin" ;;
        Linux) os="unknown-linux-musl" ;;
        *) return 1 ;;
    esac
    case "$(uname -m)" in
        x86_64 | amd64) arch="x86_64" ;;
        arm64 | aarch64) arch="aarch64" ;;
        *) return 1 ;;
    esac
    printf '%s-%s\n' "$arch" "$os"
}

# sha256_of FILE
sha256_of() {
    if have sha256sum; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        shasum -a 256 "$1" | cut -d ' ' -f 1
    fi
}

# verify_sha256 FILE EXPECTED_FILE
# EXPECTED_FILE is a .sha256 file whose first field is the hash.
verify_sha256() {
    local file="$1"
    local expected_file="$2"
    local want got

    want="$(cut -d ' ' -f 1 "$expected_file" | head -n 1)"
    got="$(sha256_of "$file")"
    [ -n "$want" ] && [ "$want" = "$got" ]
}
