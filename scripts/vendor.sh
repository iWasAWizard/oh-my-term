#!/usr/bin/env bash
#
# Fills vendor/ with everything setup.sh would download, for machines with no
# internet. Run this on a machine that has it, copy the whole repository over
# (for example with tar), and run ./setup.sh --offline there.
#
# What goes into vendor/ is pinned in vendor.lock: a commit SHA for every
# repository and a sha256 for every downloaded file. A plain run fetches exactly
# those and refuses anything that does not match, so two runs a month apart
# give the same bytes. Refreshing the pins is a separate, reviewable step.
#
#   ./scripts/vendor.sh              fetch what vendor.lock pins
#   ./scripts/vendor.sh --verify     check vendor/ against vendor.lock (offline)
#   ./scripts/vendor.sh --check-lock check vendor.lock itself (offline)
#   ./scripts/vendor.sh --update     look up the latest versions and rewrite
#                                    vendor.lock, then review: git diff vendor.lock
#
# vendor/ is ignored by git, so these downloads never end up in the repository.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install.sh
. "${repo_root}/lib/install.sh"

vendor="${repo_root}/vendor"
lock_file="${repo_root}/vendor.lock"
pins_file="${vendor}/.pins"
init_vim="${repo_root}/nvim/init.vim"
starship_targets="x86_64-unknown-linux-musl aarch64-unknown-linux-musl aarch64-apple-darwin x86_64-apple-darwin"
failures=0

usage() {
    sed -n '3,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# what the lock has to cover
# ---------------------------------------------------------------------------

# plug_specs: the owner/name of every Plug line in nvim/init.vim
plug_specs() {
    grep -oE "^[[:space:]]*Plug '[^']+'" "$init_vim" | sed -E "s/.*Plug '([^']+)'.*/\1/"
}

# plug_name SPEC: the directory name vim-plug gives the plugin
plug_name() {
    # The Nord plugin is installed under the name nord, see 'as' in init.vim
    if [ "$1" = "nordtheme/vim" ]; then
        printf 'nord\n'
    else
        printf '%s\n' "${1##*/}"
    fi
}

# wanted_repos: "DEST URL" for every repository setup.sh --offline installs from vendor/
wanted_repos() {
    local spec

    printf '%s\n' \
        "oh-my-zsh https://github.com/ohmyzsh/ohmyzsh.git" \
        "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git" \
        "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        "tmux-plugins/tmux-resurrect https://github.com/tmux-plugins/tmux-resurrect.git" \
        "tmux-plugins/tmux-continuum https://github.com/tmux-plugins/tmux-continuum.git"
    plug_specs | while read -r spec; do
        printf 'plugged/%s https://github.com/%s.git\n' "$(plug_name "$spec")" "$spec"
    done
}

# wanted_files: the DEST of every downloaded file
wanted_files() {
    local target

    printf 'vim-plug/plug.vim\n'
    for target in $starship_targets; do
        printf 'bin/starship-%s.tar.gz\n' "$target"
    done
}

# ---------------------------------------------------------------------------
# the lock file
# ---------------------------------------------------------------------------

lock_header() {
    cat <<'EOF'
# What scripts/vendor.sh puts in vendor/. One entry per line:
#
#   repo DEST GIT_URL COMMIT_SHA     a repository, checked out at that commit
#   file DEST URL SHA256             a file, which must hash to that value
#
# DEST is relative to vendor/. Do not edit by hand. Refresh with
# ./scripts/vendor.sh --update, then read the diff before committing it: every
# changed line is code that will run on your machines.
EOF
}

# lock_entries: the entries of vendor.lock without comments and blank lines
lock_entries() {
    grep -Ev '^[[:space:]]*(#|$)' "$lock_file" || true
}

# lock_has KIND DEST
lock_has() {
    awk -v k="$1" -v d="$2" '$1 == k && $2 == d { found = 1 } END { exit !found }' "$lock_file"
}

# is_hex VALUE LENGTH
is_hex() {
    printf '%s' "$1" | grep -Eq "^[0-9a-f]{$2}\$"
}

# update_lock: resolve the latest commits and releases and rewrite vendor.lock
update_lock() {
    local tmp work wanted dest url sha tag target tarball want got spec_url

    have git || die "git is required"
    have curl || die "curl is required"
    tmp="$(mktemp)"
    work="$(mktemp -d)"
    lock_header > "$tmp"
    printf '\n' >> "$tmp"

    log "Looking up the latest commit of each repository"
    wanted="$(wanted_repos)"
    while read -r dest url; do
        sha="$(git ls-remote "$url" HEAD </dev/null | cut -f 1)" || die "could not read ${url}"
        is_hex "$sha" 40 || die "no commit found for ${url} (got '${sha}')"
        printf 'repo %s %s %s\n' "$dest" "$url" "$sha" >> "$tmp"
    done <<EOF
${wanted}
EOF

    log "vim-plug"
    sha="$(git ls-remote https://github.com/junegunn/vim-plug.git HEAD </dev/null | cut -f 1)" || die "could not read vim-plug"
    is_hex "$sha" 40 || die "no commit found for vim-plug"
    spec_url="https://raw.githubusercontent.com/junegunn/vim-plug/${sha}/plug.vim"
    curl -fsSLo "${work}/plug.vim" "$spec_url" </dev/null || die "could not download ${spec_url}"
    printf 'file vim-plug/plug.vim %s %s\n' "$spec_url" "$(sha256_of "${work}/plug.vim")" >> "$tmp"

    log "starship"
    url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/starship/starship/releases/latest </dev/null)" \
        || die "could not look up the latest starship release"
    tag="${url##*/}"
    printf '%s' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || die "unexpected starship release tag '${tag}'"
    for target in $starship_targets; do
        tarball="starship-${target}.tar.gz"
        spec_url="https://github.com/starship/starship/releases/download/${tag}/${tarball}"
        curl -fsSLo "${work}/${tarball}" "$spec_url" </dev/null || die "could not download ${spec_url}"
        curl -fsSLo "${work}/${tarball}.sha256" "${spec_url}.sha256" </dev/null || die "could not download ${spec_url}.sha256"
        want="$(cut -d ' ' -f 1 "${work}/${tarball}.sha256" | head -n 1)"
        got="$(sha256_of "${work}/${tarball}")"
        [ "$want" = "$got" ] || die "${tarball} does not match the checksum published with it"
        printf 'file bin/%s %s %s\n' "$tarball" "$spec_url" "$got" >> "$tmp"
    done

    rm -rf "${work:?}"
    mv "$tmp" "$lock_file"
    log "Wrote ${lock_file}"
    log "Read what changed before you commit it: git diff vendor.lock"
}

# check_lock: vendor.lock is well formed and covers everything setup.sh installs
check_lock() {
    local problems=0
    local seen=" "
    local kind dest url pin extra want_dest entries files

    bad() {
        printf 'vendor.lock: %s\n' "$*" >&2
        problems=$((problems + 1))
    }

    [ -f "$lock_file" ] || die "vendor.lock is missing, create it with ./scripts/vendor.sh --update"
    entries="$(lock_entries)"
    while read -r kind dest url pin extra; do
        [ -n "$kind" ] || continue
        if [ -n "$extra" ] || [ -z "$pin" ]; then
            bad "${dest:-?}: expected four fields (kind, dest, url, pin)"
            continue
        fi
        case "$seen" in
            *" ${dest} "*) bad "${dest}: listed twice" ;;
        esac
        seen="${seen}${dest} "
        case "$url" in
            https://*) ;;
            *) bad "${dest}: the url must start with https://" ;;
        esac
        case "$kind" in
            repo) is_hex "$pin" 40 || bad "${dest}: the pin must be a 40 character commit SHA" ;;
            file) is_hex "$pin" 64 || bad "${dest}: the pin must be a 64 character sha256" ;;
            *) bad "${dest}: unknown kind '${kind}'" ;;
        esac
    done <<EOF
${entries}
EOF

    while read -r want_dest _; do
        lock_has repo "$want_dest" || bad "${want_dest}: missing, run ./scripts/vendor.sh --update"
    done <<EOF
$(wanted_repos)
EOF
    files="$(wanted_files)"
    for want_dest in $files; do
        lock_has file "$want_dest" || bad "${want_dest}: missing, run ./scripts/vendor.sh --update"
    done
    # Entries nobody installs, for example a plugin removed from nvim/init.vim
    while read -r kind dest _; do
        case "$kind" in
            repo) wanted_repos | awk -v d="$dest" '$1 == d { found = 1 } END { exit !found }' || bad "${dest}: not used by setup.sh any more" ;;
            file) wanted_files | awk -v d="$dest" '$1 == d { found = 1 } END { exit !found }' || bad "${dest}: not used by setup.sh any more" ;;
        esac
    done <<EOF
${entries}
EOF

    if [ "$problems" -ne 0 ]; then
        return 1
    fi
    log "vendor.lock is well formed and covers every repository and download"
}

# ---------------------------------------------------------------------------
# vendor/ and what is in it
# ---------------------------------------------------------------------------

# pin_of DEST: the pin recorded when DEST was fetched into vendor/
pin_of() {
    [ -f "$pins_file" ] || return 0
    awk -v d="$1" '$1 == d { print $2 }' "$pins_file"
}

# set_pin DEST PIN
set_pin() {
    local tmp

    tmp="$(mktemp)"
    {
        if [ -f "$pins_file" ]; then
            awk -v d="$1" '$1 != d' "$pins_file"
        fi
        printf '%s %s\n' "$1" "$2"
    } > "$tmp"
    mv "$tmp" "$pins_file"
}

# fetch_repo DEST URL SHA
# Fetches exactly that commit with the .git directory removed, so the copy is small and plain.
fetch_repo() {
    local dest="$1"
    local url="$2"
    local sha="$3"
    local target="${vendor}/${dest}"
    local tmp

    if [ -d "$target" ] && [ "$(pin_of "$dest")" = "$sha" ]; then
        log "vendor/${dest} is at the pinned commit"
        return 0
    fi
    tmp="$(mktemp -d)"
    if git -C "$tmp" init -q repo \
        && git -C "${tmp}/repo" remote add origin "$url" \
        && git -C "${tmp}/repo" fetch -q --depth 1 origin "$sha" </dev/null \
        && git -C "${tmp}/repo" checkout -q FETCH_HEAD \
        && [ "$(git -C "${tmp}/repo" rev-parse HEAD)" = "$sha" ]; then
        rm -rf "${tmp:?}/repo/.git"
        rm -rf "${target:?}"
        mkdir -p "$(dirname "$target")"
        mv "${tmp}/repo" "$target"
        set_pin "$dest" "$sha"
        log "Fetched ${dest} at ${sha}"
    else
        warn "could not fetch commit ${sha} of ${url}"
        failures=$((failures + 1))
    fi
    rm -rf "${tmp:?}"
}

# fetch_file DEST URL SHA256
fetch_file() {
    local dest="$1"
    local url="$2"
    local want="$3"
    local target="${vendor}/${dest}"
    local tmp

    if [ -f "$target" ] && [ "$(sha256_of "$target")" = "$want" ]; then
        log "vendor/${dest} matches its pinned hash"
    else
        tmp="$(mktemp)"
        if curl -fsSLo "$tmp" "$url" </dev/null && [ "$(sha256_of "$tmp")" = "$want" ]; then
            mkdir -p "$(dirname "$target")"
            mv "$tmp" "$target"
            log "Fetched ${dest}"
        else
            warn "could not fetch ${url}, or it does not hash to ${want}"
            rm -f "$tmp"
            failures=$((failures + 1))
            return 0
        fi
    fi
    # setup.sh checks starship against the .sha256 beside the tarball, so write the pinned hash there
    case "$dest" in
        *.tar.gz) printf '%s  %s\n' "$want" "$(basename "$dest")" > "${target}.sha256" ;;
    esac
}

# warn_unlocked: things in vendor/plugged that vendor.lock does not list
warn_unlocked() {
    local dir name

    [ -d "${vendor}/plugged" ] || return 0
    for dir in "${vendor}"/plugged/*; do
        [ -d "$dir" ] || continue
        name="$(basename "$dir")"
        if ! lock_has repo "plugged/${name}"; then
            warn "vendor/plugged/${name} is not in vendor.lock. Delete it, or setup.sh --offline will copy it."
        fi
    done
}

fetch_all() {
    local kind dest url pin extra entries

    have git || die "git is required"
    have curl || die "curl is required"
    mkdir -p "$vendor"
    entries="$(lock_entries)"
    while read -r kind dest url pin extra; do
        [ -n "$kind" ] || continue
        case "$kind" in
            repo) fetch_repo "$dest" "$url" "$pin" ;;
            file) fetch_file "$dest" "$url" "$pin" ;;
        esac
    done <<EOF
${entries}
EOF
    warn_unlocked
    if [ "$failures" -ne 0 ]; then
        die "${failures} item(s) could not be fetched or did not match vendor.lock"
    fi
    log "Done. vendor/ holds $(du -sh "$vendor" | cut -f 1), all matching vendor.lock. Copy the repository to the other machine and run ./setup.sh --offline"
}

# verify_vendor: vendor/ holds what vendor.lock pins. Files are re-hashed. For
# repositories this checks the pin recorded when they were fetched, since the
# copies carry no .git directory to check the content against.
verify_vendor() {
    local kind dest pin entries

    [ -d "$vendor" ] || die "vendor/ does not exist, run ./scripts/vendor.sh first"
    entries="$(lock_entries)"
    while read -r kind dest _ pin _; do
        [ -n "$kind" ] || continue
        case "$kind" in
            repo)
                if [ ! -d "${vendor}/${dest}" ]; then
                    warn "vendor/${dest} is missing"
                    failures=$((failures + 1))
                elif [ "$(pin_of "$dest")" != "$pin" ]; then
                    warn "vendor/${dest} was not fetched at the pinned commit ${pin}"
                    failures=$((failures + 1))
                fi
                ;;
            file)
                if [ ! -f "${vendor}/${dest}" ]; then
                    warn "vendor/${dest} is missing"
                    failures=$((failures + 1))
                elif [ "$(sha256_of "${vendor}/${dest}")" != "$pin" ]; then
                    warn "vendor/${dest} does not hash to ${pin}"
                    failures=$((failures + 1))
                fi
                ;;
        esac
    done <<EOF
${entries}
EOF
    if [ "$failures" -ne 0 ]; then
        die "vendor/ does not match vendor.lock (${failures} problem(s))"
    fi
    log "vendor/ matches vendor.lock"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

case "${1:-}" in
    "") check_lock; fetch_all ;;
    --verify) check_lock; verify_vendor ;;
    --check-lock) check_lock ;;
    --update) update_lock; check_lock ;;
    -h | --help) usage ;;
    *) die "unknown option: $1 (try --help)" ;;
esac
