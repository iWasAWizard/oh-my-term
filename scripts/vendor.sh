#!/usr/bin/env bash
#
# Fills vendor/ with everything setup.sh would download, for machines with no
# internet. Run this on a machine that has it, copy the whole repository over
# (for example with tar), and run ./setup.sh --offline there.
#
# vendor/ is ignored by git, so these downloads never end up in the repository.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install.sh
. "${repo_root}/lib/install.sh"

vendor="${repo_root}/vendor"
mkdir -p "$vendor"

have git || die "git is required"
have curl || die "curl is required"

# fetch_repo URL DEST
# Shallow clone with the .git directory removed, so the copy is small and plain.
fetch_repo() {
    local url="$1"
    local dest="$2"
    local tmp

    if [ -d "$dest" ]; then
        log "vendor/$(basename "$dest") already present"
        return 0
    fi
    tmp="$(mktemp -d)"
    if git clone --quiet --depth 1 "$url" "${tmp}/repo"; then
        rm -rf "${tmp}/repo/.git"
        mkdir -p "$(dirname "$dest")"
        mv "${tmp}/repo" "$dest"
        log "Fetched ${url}"
    else
        warn "could not clone ${url}"
    fi
    rm -rf "$tmp"
}

log "Oh My Zsh and its plugins"
fetch_repo https://github.com/ohmyzsh/ohmyzsh.git "${vendor}/oh-my-zsh"
fetch_repo https://github.com/zsh-users/zsh-autosuggestions "${vendor}/zsh-autosuggestions"
fetch_repo https://github.com/zsh-users/zsh-syntax-highlighting "${vendor}/zsh-syntax-highlighting"

log "tmux plugins"
fetch_repo https://github.com/tmux-plugins/tmux-resurrect "${vendor}/tmux-plugins/tmux-resurrect"
fetch_repo https://github.com/tmux-plugins/tmux-continuum "${vendor}/tmux-plugins/tmux-continuum"

log "vim-plug and the Neovim plugins listed in nvim/init.vim"
mkdir -p "${vendor}/vim-plug"
if [ ! -f "${vendor}/vim-plug/plug.vim" ]; then
    curl -fsSLo "${vendor}/vim-plug/plug.vim" https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
        || warn "could not download vim-plug"
fi
grep -oE "^[[:space:]]*Plug '[^']+'" "${repo_root}/nvim/init.vim" | sed -E "s/.*Plug '([^']+)'.*/\1/" | while read -r spec; do
    name="${spec##*/}"
    # The Nord plugin is installed under the name nord, see 'as' in init.vim
    [ "$spec" = "nordtheme/vim" ] && name="nord"
    fetch_repo "https://github.com/${spec}.git" "${vendor}/plugged/${name}"
done

log "starship builds for the machines this might run on"
mkdir -p "${vendor}/bin"
for target in x86_64-unknown-linux-musl aarch64-unknown-linux-musl aarch64-apple-darwin x86_64-apple-darwin; do
    tarball="starship-${target}.tar.gz"
    base="https://github.com/starship/starship/releases/latest/download/${tarball}"
    if [ -f "${vendor}/bin/${tarball}" ]; then
        continue
    fi
    if curl -fsSLo "${vendor}/bin/${tarball}" "$base" && curl -fsSLo "${vendor}/bin/${tarball}.sha256" "${base}.sha256"; then
        if verify_sha256 "${vendor}/bin/${tarball}" "${vendor}/bin/${tarball}.sha256"; then
            log "Fetched ${tarball}"
        else
            warn "checksum mismatch for ${tarball}, removing it"
            rm -f "${vendor}/bin/${tarball}" "${vendor}/bin/${tarball}.sha256"
        fi
    else
        warn "could not download ${tarball}"
        rm -f "${vendor}/bin/${tarball}" "${vendor}/bin/${tarball}.sha256"
    fi
done

log "Done. vendor/ holds $(du -sh "$vendor" | cut -f 1). Copy the repository to the other machine and run ./setup.sh --offline"
