#!/usr/bin/env bash
#
# oh-my-term installer. Links the configs in this repository into your home
# directory and installs the frameworks and plugins the "full" configs use.
#
#   ./setup.sh                  install every component
#   ./setup.sh bash vim screen  install only these
#   ./setup.sh --offline        link only, using vendor/ for anything that needs a download
#   ./setup.sh --list           show the components
#   ./setup.sh doctor [names]   check links, tool versions and the tier this machine runs
#
# Environment variables (each also has a flag where it makes sense):
#   OMT_OFFLINE=1      never touch the network, install from vendor/ when possible
#   OMT_NO_CHSH=1      do not change the login shell
#   OMT_SKIP_TOOLS=1   skip the tools component (starship, fzf, autopep8)
#   OMT_PLATFORM       force macos, linux or unraid
#   OMT_GO_FILE        Unraid boot script to edit (default /boot/config/go)
#   ZSH, ZSH_CUSTOM    Oh My Zsh location (default ~/.oh-my-zsh)
#
# For compatibility with macOS, this script is written for bash 3.2.
# Modern bash versionsi (4+) are forwards-compatible.

set -euo pipefail

OMT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install.sh
. "${OMT}/lib/install.sh"
# shellcheck source=lib/doctor.sh
. "${OMT}/lib/doctor.sh"

ALL_COMPONENTS="bash zsh vim nvim screen tmux git ssh gdb cli pi tools"

offline="${OMT_OFFLINE:-0}"
no_chsh="${OMT_NO_CHSH:-0}"
skip_tools="${OMT_SKIP_TOOLS:-0}"
go_file="${OMT_GO_FILE:-/boot/config/go}"
go_marker="# oh-my-term persistence"

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
omp_dir="${OMP_AGENT_DIR:-$HOME/.omp/agent}"

platform="$(detect_platform)"

usage() {
    sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

list_components() {
    cat <<'EOF'
bash    minimal bashrc, inputrc
zsh     full zshrc, Oh My Zsh and plugins
vim     minimal vimrc and colorscheme, no plugins
nvim    full Neovim config with plugins
screen  minimal screenrc
tmux    full tmux.conf and plugins
git     gitconfig and global ignore file
ssh     ssh config with sane defaults
gdb     gdbinit
cli     btop defaults (ripgrep, bat, less and fzf are set up by the shell)
pi      oh-my-pi (omp) install, AGENTS.md and skills
tools   starship, fzf, autopep8
EOF
}

# Where a download may come from: the local vendor/ directory first.
vendor_dir() {
    printf '%s/vendor/%s\n' "$OMT" "$1"
}

can_download() {
    [ "$offline" != "1" ]
}

# ---------------------------------------------------------------------------
# components
# ---------------------------------------------------------------------------

install_bash() {
    link_file "${OMT}/shell/bashrc" "${HOME}/.bashrc"
    link_file "${OMT}/shell/inputrc" "${HOME}/.inputrc"
    # Login shells read one of these instead of .bashrc. Only add the shim when
    # none of them exist, otherwise it would hide an existing .profile.
    if [ "${HOME}/.bash_profile" -ef "${OMT}/shell/bash_profile" ] \
        || { [ ! -e "${HOME}/.bash_profile" ] && [ ! -e "${HOME}/.bash_login" ] && [ ! -e "${HOME}/.profile" ]; }; then
        link_file "${OMT}/shell/bash_profile" "${HOME}/.bash_profile"
    else
        log "Leaving your existing login-shell file alone (it needs to source ~/.bashrc)"
    fi
}

install_oh_my_zsh() {
    if [ -f "${ZSH}/oh-my-zsh.sh" ]; then
        log "Oh My Zsh already installed at ${ZSH}"
        return 0
    fi
    if [ -e "$ZSH" ] && [ -n "$(ls -A "$ZSH" 2>/dev/null)" ]; then
        die "${ZSH} exists but is not an Oh My Zsh install (no oh-my-zsh.sh). Move it aside and run this again."
    fi
    if [ -d "$(vendor_dir oh-my-zsh)" ]; then
        log "Installing Oh My Zsh from vendor/"
        mkdir -p "$(dirname "$ZSH")"
        cp -R "$(vendor_dir oh-my-zsh)" "$ZSH"
    elif can_download && have git; then
        log "Cloning Oh My Zsh into ${ZSH}"
        clone_or_update "${OMT_OMZ_URL:-https://github.com/ohmyzsh/ohmyzsh.git}" "$ZSH" \
            || die "could not clone Oh My Zsh"
    else
        warn "Oh My Zsh is not installed and cannot be fetched. The zshrc still works without it."
        return 0
    fi
    [ -f "${ZSH}/oh-my-zsh.sh" ] || die "Oh My Zsh install is missing oh-my-zsh.sh"
}

install_zsh_plugin() {
    local name="$1"
    local url="$2"
    local dir="${ZSH_CUSTOM}/plugins/${name}"

    if [ ! -d "$ZSH" ]; then
        return 0
    fi
    if [ -d "$dir" ]; then
        if [ -d "${dir}/.git" ] && can_download; then
            log "Updating ${name}"
            git -C "$dir" pull --ff-only --quiet || warn "could not fast-forward ${name}, leaving it as is"
        fi
    elif [ -d "$(vendor_dir "$name")" ]; then
        log "Installing ${name} from vendor/"
        mkdir -p "${ZSH_CUSTOM}/plugins"
        cp -R "$(vendor_dir "$name")" "$dir"
    elif can_download && have git; then
        log "Installing ${name}"
        clone_or_update "$url" "$dir" || die "could not clone ${url}"
    else
        warn "${name} is not installed and cannot be fetched"
        return 0
    fi
    [ -f "${dir}/${name}.plugin.zsh" ] || [ -f "${dir}/${name}.zsh" ] \
        || die "${name} did not install correctly (no ${name}.plugin.zsh in ${dir})"
}

set_login_shell() {
    local zsh_path

    zsh_path="$(command -v zsh)"
    if [ "$no_chsh" = "1" ] || [ "${SHELL:-}" = "$zsh_path" ]; then
        return 0
    fi
    if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
        warn "${zsh_path} is not listed in /etc/shells, so the login shell was not changed."
        warn "Add it (as root: echo ${zsh_path} >> /etc/shells), then run: chsh -s ${zsh_path}"
        return 0
    fi
    log "Setting zsh as your login shell (you may be asked for your password)"
    chsh -s "$zsh_path" || warn "chsh failed. Set your login shell to zsh yourself: chsh -s ${zsh_path}"
}

install_zsh() {
    link_file "${OMT}/shell/zshrc" "${HOME}/.zshrc"
    if ! have zsh; then
        warn "zsh is not installed, so only the config was linked (try 'brew install zsh' or 'sudo apt install zsh')"
        return 0
    fi
    install_oh_my_zsh
    install_zsh_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
    install_zsh_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
    set_login_shell
}

install_vim() {
    link_file "${OMT}/vim/vimrc" "${HOME}/.vimrc"
    link_file "${OMT}/vim/colors/omt-nord.vim" "${HOME}/.vim/colors/omt-nord.vim"
}

nvim_missing_plugins() {
    local out="$1"

    nvim --headless -u "${config_home}/nvim/init.vim" \
        -c "call writefile(filter(keys(g:plugs), '!isdirectory(g:plugs[v:val].dir)'), '${out}')" \
        -c 'qa!' </dev/null >/dev/null 2>&1 || true
}

install_nvim() {
    local plug_dest="${data_home}/nvim/site/autoload/plug.vim"
    local plugged="${data_home}/nvim/plugged"
    local missing_file entry

    link_file "${OMT}/nvim/init.vim" "${config_home}/nvim/init.vim"
    link_file "${OMT}/vim/colors/omt-nord.vim" "${config_home}/nvim/colors/omt-nord.vim"

    if [ ! -f "$plug_dest" ]; then
        mkdir -p "$(dirname "$plug_dest")"
        if [ -f "$(vendor_dir vim-plug)/plug.vim" ]; then
            cp "$(vendor_dir vim-plug)/plug.vim" "$plug_dest"
            log "Installed vim-plug from vendor/"
        elif can_download && have curl; then
            curl -fsSLo "$plug_dest" https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
                || warn "could not download vim-plug"
        else
            warn "vim-plug is not installed and cannot be fetched, Neovim will run without plugins"
        fi
    fi

    if [ -d "$(vendor_dir plugged)" ]; then
        mkdir -p "$plugged"
        for entry in "$(vendor_dir plugged)"/*; do
            [ -d "$entry" ] || continue
            copy_dir_if_missing "$entry" "${plugged}/$(basename "$entry")"
        done
    fi

    if have nvim && can_download && [ -f "$plug_dest" ]; then
        log "Installing Neovim plugins"
        nvim --headless -u "${config_home}/nvim/init.vim" -c 'PlugInstall --sync' -c 'PlugClean!' -c 'qa!' \
            </dev/null >/dev/null 2>&1 || warn "PlugInstall reported a problem"
        missing_file="$(mktemp)"
        nvim_missing_plugins "$missing_file"
        if [ -s "$missing_file" ]; then
            warn "these Neovim plugins are not installed:"
            sed 's/^/  /' "$missing_file" >&2
        fi
        rm -f "$missing_file"
    fi
}

install_screen() {
    link_file "${OMT}/screen/screenrc" "${HOME}/.screenrc"
}

install_tmux() {
    local name url
    local plugins_dir="${HOME}/.tmux/plugins"

    link_file "${OMT}/tmux/tmux.conf" "${HOME}/.tmux.conf"
    for name in tmux-resurrect tmux-continuum; do
        url="https://github.com/tmux-plugins/${name}"
        if [ -d "${plugins_dir}/${name}" ]; then
            continue
        elif [ -d "$(vendor_dir tmux-plugins)/${name}" ]; then
            copy_dir_if_missing "$(vendor_dir tmux-plugins)/${name}" "${plugins_dir}/${name}"
        elif can_download && have git; then
            log "Installing ${name}"
            clone_or_update "$url" "${plugins_dir}/${name}" || warn "could not clone ${url}"
        else
            warn "${name} is not installed and cannot be fetched, tmux will run without it"
        fi
    done
}

install_git() {
    local seed="${HOME}/.gitconfig"

    link_file "${OMT}/git/gitconfig" "${config_home}/git/config"
    link_file "${OMT}/git/ignore" "${config_home}/git/ignore"
    # `git config --global` writes to ~/.gitconfig when it exists, so create it
    # to keep your name and email out of the repository.
    if [ ! -e "$seed" ]; then
        {
            printf '# Machine-specific git settings. The shared settings live in %s/git/config.\n' "$OMT"
            printf '# [user]\n#     name = Your Name\n#     email = you@example.com\n'
            if [ "$platform" = "macos" ]; then
                printf '[credential]\n    helper = osxkeychain\n'
            fi
        } > "$seed"
        log "Created ${seed}. Add your name and email: git config --global user.name ..."
    fi
}

install_ssh() {
    local cfg="${HOME}/.ssh/config"
    local local_cfg="${HOME}/.ssh/config.local"

    mkdir -p "${HOME}/.ssh/cm"
    chmod 700 "${HOME}/.ssh" "${HOME}/.ssh/cm"
    # An existing real config holds your hosts. Keep it as config.local, which
    # the shared config includes first, instead of hiding it in a backup.
    if [ -f "$cfg" ] && [ ! -L "$cfg" ] && [ ! -e "$local_cfg" ]; then
        mv -- "$cfg" "$local_cfg"
        chmod 600 "$local_cfg"
        log "Moved your existing ${cfg} to ${local_cfg}, which the new config includes"
    fi
    link_file "${OMT}/ssh/config" "$cfg"
    if [ ! -e "$local_cfg" ]; then
        seed_file "${OMT}/ssh/config.local.example" "$local_cfg"
        chmod 600 "$local_cfg"
    fi
}

install_gdb() {
    link_file "${OMT}/gdb/gdbinit" "${HOME}/.gdbinit"
}

install_cli() {
    seed_file "${OMT}/cli/btop.conf" "${config_home}/btop/btop.conf"
}

install_pi() {
    link_file "${OMT}/pi/AGENTS.md" "${omp_dir}/AGENTS.md"
    link_file "${OMT}/pi/skills" "${omp_dir}/skills"

    if ! have omp && can_download; then
        if have bun; then
            log "Installing oh-my-pi with bun"
            bun install -g @oh-my-pi/pi-coding-agent || warn "bun could not install oh-my-pi"
        elif have brew; then
            log "Installing oh-my-pi with Homebrew"
            brew install can1357/tap/omp || warn "brew could not install oh-my-pi"
        else
            warn "oh-my-pi is not installed. Install bun or Homebrew and run this again, or see https://omp.sh"
        fi
    fi
    if ! have omp && ! can_download; then
        log "oh-my-pi is not installed. With a network, run: bun install -g @oh-my-pi/pi-coding-agent"
    fi
    if [ ! -e "${omp_dir}/models.yml" ]; then
        log "To use a local server, copy pi/models.yml.example to ${omp_dir}/models.yml and edit it"
    fi
}

install_starship() {
    local target tarball tmp bin_dir="${HOME}/.local/bin"

    if have starship || [ -x "${bin_dir}/starship" ]; then
        return 0
    fi
    target="$(starship_target)" || { warn "no starship build for this machine"; return 0; }
    tarball="starship-${target}.tar.gz"
    tmp="$(mktemp -d)"

    if [ -f "$(vendor_dir bin)/${tarball}" ]; then
        cp "$(vendor_dir bin)/${tarball}" "${tmp}/${tarball}"
        cp "$(vendor_dir bin)/${tarball}.sha256" "${tmp}/${tarball}.sha256" 2>/dev/null || true
    elif ! can_download; then
        warn "starship is not installed and cannot be fetched. The shells fall back to a plain prompt."
        rm -rf "$tmp"
        return 0
    elif have brew; then
        rm -rf "$tmp"
        log "Installing starship with Homebrew"
        brew install starship || warn "brew could not install starship"
        return 0
    else
        log "Downloading starship"
        if ! curl -fsSL -o "${tmp}/${tarball}" "https://github.com/starship/starship/releases/latest/download/${tarball}" \
            || ! curl -fsSL -o "${tmp}/${tarball}.sha256" "https://github.com/starship/starship/releases/latest/download/${tarball}.sha256"; then
            warn "could not download starship. The shells fall back to a plain prompt."
            rm -rf "$tmp"
            return 0
        fi
    fi

    if [ -f "${tmp}/${tarball}.sha256" ] && ! verify_sha256 "${tmp}/${tarball}" "${tmp}/${tarball}.sha256"; then
        warn "starship checksum did not match, not installing it"
        rm -rf "$tmp"
        return 0
    fi
    mkdir -p "$bin_dir"
    tar -xzf "${tmp}/${tarball}" -C "$tmp" starship
    install -m 755 "${tmp}/starship" "${bin_dir}/starship"
    rm -rf "$tmp"
    log "Installed starship to ${bin_dir}/starship"
}

# Installs a Python command-line tool with pipx, then uv, then pip. Never fatal.
install_python_tool() {
    local tool="$1"

    have "$tool" && return 0
    log "Installing ${tool}"
    if have pipx && pipx install "$tool"; then
        return 0
    elif have uv && uv tool install "$tool"; then
        return 0
    elif have pip3 && pip3 install --user "$tool"; then
        return 0
    fi
    warn "could not install ${tool}. It is optional, the shells skip it when missing."
}

install_tools() {
    if [ "$skip_tools" = "1" ]; then
        log "Skipping tools (OMT_SKIP_TOOLS=1)"
        return 0
    fi
    install_starship
    if [ "$offline" = "1" ]; then
        log "Offline: not installing fzf or autopep8"
        return 0
    fi

    if ! have fzf && [ ! -x "${HOME}/.fzf/bin/fzf" ]; then
        log "Installing fzf"
        if have brew && brew install fzf; then
            :
        elif { [ -d "${HOME}/.fzf" ] || git clone --quiet --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"; } \
            && "${HOME}/.fzf/install" --all --no-update-rc; then
            :
        else
            warn "could not install fzf. It is optional, the shells skip it when missing."
        fi
    fi
    install_python_tool autopep8
}

# ---------------------------------------------------------------------------
# Unraid keeps its root filesystem in RAM, so everything above vanishes on
# reboot. The repository lives on the flash drive and this hook re-runs the
# installer, offline, from /boot/config/go at every boot.
# ---------------------------------------------------------------------------
unraid_persist() {
    local run_list="$1"

    [ -f "$go_file" ] || { warn "${go_file} not found, skipping boot persistence"; return 0; }
    case "$OMT" in
        /boot/*) ;;
        *) warn "This repository is not on the flash drive (${OMT}). It would be gone after a reboot, so move it under /boot/config first." ;;
    esac
    if grep -qF "$go_marker" "$go_file"; then
        log "${go_file} already has the oh-my-term block (edit or delete it to change the component list)"
        return 0
    fi
    cp "$go_file" "${go_file}.bak.$(timestamp)"
    cat >> "$go_file" <<EOF

${go_marker}
bash "${OMT}/setup.sh" --offline --no-chsh ${run_list} > /var/log/oh-my-term.log 2>&1
EOF
    log "Added boot-time install to ${go_file} (backup saved beside it)"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

requested=""
doctor_mode=0
while [ $# -gt 0 ]; do
    case "$1" in
        doctor) doctor_mode=1 ;;
        --offline) offline=1 ;;
        --no-chsh) no_chsh=1 ;;
        --no-tools) skip_tools=1 ;;
        --list) list_components; exit 0 ;;
        -h | --help) usage; exit 0 ;;
        -*) die "unknown option: $1 (try --help)" ;;
        all) requested="${requested} ${ALL_COMPONENTS}" ;;
        *) requested="${requested} $1" ;;
    esac
    shift
done
[ -n "$requested" ] || requested="$ALL_COMPONENTS"

for c in $requested; do
    case " ${ALL_COMPONENTS} " in
        *" ${c} "*) ;;
        *) die "unknown component: ${c} (try --list)" ;;
    esac
done

if [ "$doctor_mode" = "1" ]; then
    run_doctor "$requested" && exit 0
    exit 1
fi

log "Platform: ${platform}"
mkdir -p "${config_home}"
if [ ! "$OMT" -ef "${config_home}/oh-my-term" ]; then
    link_file "$OMT" "${config_home}/oh-my-term"
fi

for c in $requested; do
    "install_${c}"
done

if [ "$platform" = "unraid" ]; then
    unraid_persist "$requested"
fi

log "Done."
log "Terminal colors: import a file from ${OMT}/theme/emulator into your terminal app."
log "Machine-specific settings go in ~/.zshrc.local, ~/.bashrc.local, ~/.vimrc.local, ~/.tmux.conf.local, ~/.gdbinit.local and ~/.ssh/config.local."
