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

# ---------------------------------------------------------------------------
# programs: what the configs need, and what you get without it. Used by the
# missing-programs report at the end of setup.sh and by setup.sh doctor.
# ---------------------------------------------------------------------------

# program_min NAME: the oldest major.minor the config supports, or nothing
program_min() {
    case "$1" in
        bash) printf '3.2\n' ;;
        zsh) printf '5.0\n' ;;
        tmux) printf '3.0\n' ;;
        nvim) printf '0.9\n' ;;
    esac
}

# program_alt NAME: where setup.sh puts the program when it is not on PATH
program_alt() {
    case "$1" in
        starship | autopep8) printf '%s/.local/bin/%s\n' "$HOME" "$1" ;;
        fzf) printf '%s/.fzf/bin/fzf\n' "$HOME" ;;
        omp) printf '%s/.bun/bin/omp\n' "$HOME" ;;
    esac
}

# program_fallback NAME: what you get without the program
program_fallback() {
    case "$1" in
        bash) printf 'the installer and the bash config need it\n' ;;
        zsh) printf 'the zsh config is skipped, bash is used\n' ;;
        tmux) printf 'screen is used instead\n' ;;
        nvim) printf 'vim is used instead, without plugins\n' ;;
        vim) printf 'no editor config applies\n' ;;
        screen) printf 'no terminal multiplexer config applies\n' ;;
        git) printf 'nothing can be cloned or updated\n' ;;
        gdb) printf 'the gdbinit is linked but there is no gdb to read it\n' ;;
        ssh) printf 'the ssh config is linked but there is no ssh to read it\n' ;;
        starship) printf 'bash and zsh use their plain prompts\n' ;;
        fzf) printf 'fuzzy history and file search are skipped\n' ;;
        omp) printf 'oh-my-pi is not available (see the pi component)\n' ;;
        autopep8) printf 'Python fixing in Neovim is skipped\n' ;;
        *) printf 'the config for it has nothing to run\n' ;;
    esac
}

# program_version NAME: prints major.minor, or nothing if it cannot be read
program_version() {
    local out=""

    case "$1" in
        bash) out="$(bash -c 'printf "%s.%s" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"' 2>/dev/null)" || true ;;
        zsh) out="$(zsh --version 2>&1 | head -n 1)" || true ;;
        tmux) out="$(tmux -V 2>&1 | head -n 1)" || true ;;
        nvim) out="$(nvim --version 2>&1 | head -n 1)" || true ;;
        vim) out="$(vim --version 2>&1 | head -n 1)" || true ;;
        screen) out="$(screen --version 2>&1 | head -n 1)" || true ;;
        git) out="$(git --version 2>&1 | head -n 1)" || true ;;
    esac
    printf '%s\n' "$out" | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1
}

# version_ge HAVE WANT: both are major.minor
version_ge() {
    local have_major="${1%%.*}"
    local have_minor="${1#*.}"
    local want_major="${2%%.*}"
    local want_minor="${2#*.}"

    [ "$have_major" -gt "$want_major" ] && return 0
    [ "$have_major" -eq "$want_major" ] && [ "$have_minor" -ge "$want_minor" ]
}

# program_usable NAME: installed (on PATH or at its program_alt) and at least
# program_min. A version that cannot be read counts as usable.
program_usable() {
    local name="$1"
    local min alt ver

    if ! have "$name"; then
        alt="$(program_alt "$name")"
        [ -n "$alt" ] && [ -x "$alt" ]
        return
    fi
    min="$(program_min "$name")"
    [ -z "$min" ] && return 0
    ver="$(program_version "$name")"
    [ -z "$ver" ] || version_ge "$ver" "$min"
}

# install_hint NAME: a command that installs the program on this machine, or nothing
install_hint() {
    local name="$1"
    local pkg="$1"
    local sudo=""

    case "$name" in
        omp) printf 'bun install -g @oh-my-pi/pi-coding-agent\n'; return 0 ;;
        nvim) pkg="neovim" ;;
    esac
    [ "$(id -u)" = "0" ] || sudo="sudo "
    if have brew; then
        printf 'brew install %s\n' "$pkg"
    elif have apt-get; then
        printf '%sapt install %s\n' "$sudo" "$pkg"
    elif have apk; then
        printf 'apk add %s\n' "$pkg"
    elif have dnf; then
        printf '%sdnf install %s\n' "$sudo" "$pkg"
    elif have pacman; then
        printf '%spacman -S %s\n' "$sudo" "$pkg"
    fi
}
