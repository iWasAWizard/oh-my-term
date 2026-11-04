# shellcheck shell=bash disable=SC2154
#
# setup.sh doctor: a read-only health check. Sourced by setup.sh, which sets
# OMT, platform, config_home, data_home, omp_dir, ZSH and ZSH_CUSTOM and
# defines nvim_missing_plugins. Changes nothing on disk.
# Keep this file compatible with bash 3.2 (the bash that ships with macOS).

doctor_ok=0
doctor_warn=0
doctor_fail=0
doctor_comp=""

# doc_report LEVEL MESSAGE
# ok, warn and fail are counted. info is for optional things and is not.
doc_report() {
    local level="$1"
    local tag

    shift
    case "$level" in
        ok) doctor_ok=$((doctor_ok + 1)); tag="ok  " ;;
        warn) doctor_warn=$((doctor_warn + 1)); tag="warn" ;;
        fail) doctor_fail=$((doctor_fail + 1)); tag="FAIL" ;;
        *) tag="info" ;;
    esac
    printf '  [%s] %s\n' "$tag" "$*"
}

# doc_path PATH: PATH with $HOME shortened to ~
doc_path() {
    # shellcheck disable=SC2088 # a literal ~ is what we want to print
    case "$1" in
        "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# doc_tool PROGRAM
# Checks the version against program_min, and says what you get without it.
doc_tool() {
    local name="$1"
    local min fallback ver

    min="$(program_min "$name")"
    fallback="$(program_fallback "$name")"
    if ! have "$name"; then
        doc_report warn "${name} is not installed: ${fallback}"
        return 0
    fi
    ver="$(program_version "$name")"
    if [ -z "$ver" ]; then
        doc_report warn "${name} is installed ($(command -v "$name")) but its version could not be read"
    elif [ -z "$min" ]; then
        doc_report ok "${name} ${ver}"
    elif version_ge "$ver" "$min"; then
        doc_report ok "${name} ${ver} (needs ${min})"
    else
        doc_report fail "${name} ${ver} is older than the ${min} this config needs: ${fallback}"
    fi
}

# doc_optional PROGRAM
# A program the shells skip when it is missing. Also looks where setup.sh puts it.
doc_optional() {
    local name="$1"
    local alt

    alt="$(program_alt "$name")"
    if have "$name"; then
        doc_report ok "${name} ($(command -v "$name"))"
    elif [ -n "$alt" ] && [ -x "$alt" ]; then
        doc_report ok "${name} ($(doc_path "$alt"), not on PATH in this shell)"
    else
        doc_report info "${name} is not installed: $(program_fallback "$name")"
    fi
}

# doc_link SRC DST: DST should be a link that resolves to SRC
doc_link() {
    local src="$1"
    local dst="$2"
    local shown

    shown="$(doc_path "$dst")"
    if [ -L "$dst" ] && [ ! -e "$dst" ]; then
        doc_report fail "${shown} is a broken link to $(readlink "$dst")"
    elif [ ! -e "$dst" ]; then
        doc_report warn "${shown} is missing (run: ./setup.sh ${doctor_comp})"
    elif [ "$src" -ef "$dst" ]; then
        doc_report ok "${shown}"
    elif [ -L "$dst" ]; then
        doc_report warn "${shown} links to $(readlink "$dst"), not to this repository"
    else
        doc_report warn "${shown} is a regular file, not a link into this repository"
    fi
}

# doc_seed DST: a file setup.sh copies once and then leaves to you
doc_seed() {
    if [ -e "$1" ]; then
        doc_report ok "$(doc_path "$1") (seeded, yours to edit)"
    else
        doc_report warn "$(doc_path "$1") is missing (run: ./setup.sh ${doctor_comp})"
    fi
}

# ---------------------------------------------------------------------------
# per-component checks, in the same order as the install_* functions
# ---------------------------------------------------------------------------

doc_check_bash() {
    local f found=""

    doc_link "${OMT}/shell/bashrc" "${HOME}/.bashrc"
    doc_link "${OMT}/shell/inputrc" "${HOME}/.inputrc"
    # bash reads the first of these for a login shell, and macOS terminals start login shells
    for f in .bash_profile .bash_login .profile; do
        if [ -e "${HOME}/${f}" ]; then
            found="${HOME}/${f}"
            break
        fi
    done
    if [ -z "$found" ]; then
        doc_report warn "no login-shell file, so login bash sessions skip ~/.bashrc (run: ./setup.sh bash)"
    elif [ "$found" -ef "${OMT}/shell/bash_profile" ] || grep -q 'bashrc' "$found" 2>/dev/null; then
        doc_report ok "$(doc_path "$found") loads ~/.bashrc"
    else
        doc_report warn "$(doc_path "$found") does not mention .bashrc, so login bash sessions skip it"
    fi
}

doc_check_zsh() {
    local name zsh_path

    doc_link "${OMT}/shell/zshrc" "${HOME}/.zshrc"
    if [ -f "${ZSH}/oh-my-zsh.sh" ]; then
        doc_report ok "Oh My Zsh at $(doc_path "$ZSH")"
    else
        doc_report warn "Oh My Zsh is not installed at $(doc_path "$ZSH"), the zshrc still works without it"
    fi
    for name in zsh-autosuggestions zsh-syntax-highlighting; do
        if [ -f "${ZSH_CUSTOM}/plugins/${name}/${name}.plugin.zsh" ] || [ -f "${ZSH_CUSTOM}/plugins/${name}/${name}.zsh" ]; then
            doc_report ok "${name}"
        else
            doc_report warn "${name} is not installed"
        fi
    done
    if have zsh; then
        zsh_path="$(command -v zsh)"
        if [ "${SHELL:-}" = "$zsh_path" ]; then
            doc_report ok "login shell is zsh"
        else
            doc_report info "login shell is ${SHELL:-unknown}, not zsh (change it with: chsh -s ${zsh_path})"
        fi
    fi
}

doc_check_vim() {
    doc_link "${OMT}/vim/vimrc" "${HOME}/.vimrc"
    doc_link "${OMT}/vim/colors/omt-nord.vim" "${HOME}/.vim/colors/omt-nord.vim"
}

doc_check_nvim() {
    local plug="${data_home}/nvim/site/autoload/plug.vim"
    local missing_file name

    doc_link "${OMT}/nvim/init.vim" "${config_home}/nvim/init.vim"
    doc_link "${OMT}/vim/colors/omt-nord.vim" "${config_home}/nvim/colors/omt-nord.vim"
    if [ -f "$plug" ]; then
        doc_report ok "vim-plug"
    else
        doc_report warn "vim-plug is not installed, Neovim runs without plugins"
    fi
    if have nvim && [ -f "$plug" ] && [ -e "${config_home}/nvim/init.vim" ]; then
        missing_file="$(mktemp)"
        nvim_missing_plugins "$missing_file"
        if [ -s "$missing_file" ]; then
            while IFS= read -r name; do
                doc_report warn "Neovim plugin not installed: ${name}"
            done < "$missing_file"
        else
            doc_report ok "every Neovim plugin in init.vim is installed"
        fi
        rm -f "$missing_file"
    fi
}

doc_check_screen() {
    doc_link "${OMT}/screen/screenrc" "${HOME}/.screenrc"
}

doc_check_tmux() {
    local name

    doc_link "${OMT}/tmux/tmux.conf" "${HOME}/.tmux.conf"
    for name in tmux-resurrect tmux-continuum; do
        if [ -d "${HOME}/.tmux/plugins/${name}" ]; then
            doc_report ok "${name}"
        else
            doc_report warn "${name} is not installed, tmux runs without it"
        fi
    done
}

doc_check_git() {
    doc_link "${OMT}/git/gitconfig" "${config_home}/git/config"
    doc_link "${OMT}/git/ignore" "${config_home}/git/ignore"
    doc_seed "${HOME}/.gitconfig"
    if have git; then
        if [ -n "$(git config --global --get user.name 2>/dev/null || true)" ] \
            && [ -n "$(git config --global --get user.email 2>/dev/null || true)" ]; then
            doc_report ok "git user.name and user.email are set"
        else
            doc_report warn "git user.name or user.email is not set (git config --global user.name ...)"
        fi
    fi
}

doc_check_ssh() {
    local err

    doc_link "${OMT}/ssh/config" "${HOME}/.ssh/config"
    doc_seed "${HOME}/.ssh/config.local"
    if have ssh && [ -e "${HOME}/.ssh/config" ]; then
        if err="$(ssh -F "${HOME}/.ssh/config" -G omt-doctor.invalid 2>&1 >/dev/null)"; then
            doc_report ok "ssh -G accepts the config"
        else
            doc_report fail "ssh -G rejected the config: $(printf '%s\n' "$err" | head -n 1)"
        fi
    fi
}

doc_check_gdb() {
    doc_link "${OMT}/gdb/gdbinit" "${HOME}/.gdbinit"
}

doc_check_cli() {
    doc_seed "${config_home}/btop/btop.conf"
}

doc_check_pi() {
    doc_link "${OMT}/pi/AGENTS.md" "${omp_dir}/AGENTS.md"
    doc_link "${OMT}/pi/skills" "${omp_dir}/skills"
}

# ---------------------------------------------------------------------------
# sections
# ---------------------------------------------------------------------------

doc_programs() {
    printf '\nPrograms\n'
    doc_tool bash
    doc_tool zsh
    doc_tool tmux
    doc_tool nvim
    doc_tool vim
    doc_tool screen
    doc_tool git
    doc_optional starship
    doc_optional fzf
    doc_optional omp
    doc_optional autopep8
}

doc_links() {
    local c

    printf '\nLinks and files\n'
    doctor_comp="all"
    printf ' core\n'
    doc_link "$OMT" "${config_home}/oh-my-term"
    for c in $1; do
        # tools has no files of its own, its programs are listed under Programs
        [ "$c" = "tools" ] && continue
        doctor_comp="$c"
        printf ' %s\n' "$c"
        "doc_check_${c}"
    done
}

doc_tier_line() {
    printf '  %-8s %-8s %s\n' "$1" "$2" "$3"
}

doc_tiers() {
    printf '\nTier this machine runs\n'
    if program_usable zsh; then
        doc_tier_line shell full "zsh $(program_version zsh)"
    else
        doc_tier_line shell minimal "bash $(program_version bash) (zsh 5.0 or newer is missing)"
    fi
    if program_usable nvim; then
        doc_tier_line editor full "neovim $(program_version nvim)"
    elif have vim; then
        doc_tier_line editor minimal "vim $(program_version vim) (neovim 0.9 or newer is missing)"
    else
        doc_tier_line editor none "neither neovim 0.9 or newer nor vim is installed"
    fi
    if program_usable tmux; then
        doc_tier_line mux full "tmux $(program_version tmux)"
    elif have screen; then
        doc_tier_line mux minimal "screen $(program_version screen) (tmux 3.0 or newer is missing)"
    else
        doc_tier_line mux none "neither tmux 3.0 or newer nor screen is installed"
    fi
}

# run_doctor COMPONENTS
# Returns 1 when anything failed. Warnings alone do not fail the check.
run_doctor() {
    printf 'oh-my-term doctor\n'
    printf '  repository  %s\n' "$OMT"
    printf '  platform    %s\n' "$platform"

    doc_programs
    doc_links "$1"
    doc_tiers

    printf '\n%s ok, %s warnings, %s failures\n' "$doctor_ok" "$doctor_warn" "$doctor_fail"
    [ "$doctor_fail" -eq 0 ]
}
