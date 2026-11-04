# shellcheck shell=sh
# oh-my-term shared shell setup, sourced by bashrc and zshrc.
# Keep this file POSIX-compatible: it has to run in bash 3.2 and zsh.

OMT_HOME="${OMT_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-term}"
export OMT_HOME

omt_have() {
    command -v "$1" >/dev/null 2>&1
}

omt_path_prepend() {
    [ -d "$1" ] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
if ! omt_have brew; then
    for _omt_brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [ -x "$_omt_brew" ]; then
            eval "$("$_omt_brew" shellenv)"
            break
        fi
    done
    unset _omt_brew
fi
omt_path_prepend "$HOME/.opencode/bin"
omt_path_prepend "${BUN_INSTALL:-$HOME/.bun}/bin"  # global bun packages, such as omp
omt_path_prepend "$HOME/.local/bin"
export PATH

# ---------------------------------------------------------------------------
# Editor, pager
# ---------------------------------------------------------------------------
if [ -z "${EDITOR:-}" ]; then
    for _omt_ed in vim nvim vi nano; do
        if omt_have "$_omt_ed"; then
            EDITOR="$_omt_ed"
            break
        fi
    done
    unset _omt_ed
fi
export EDITOR="${EDITOR:-vi}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R -i -M -F -X}"

# less colors for man pages, using the terminal's own palette
_omt_esc=$(printf '\033')
LESS_TERMCAP_mb="${_omt_esc}[1;31m"   # begin blink
LESS_TERMCAP_md="${_omt_esc}[1;36m"   # begin bold
LESS_TERMCAP_me="${_omt_esc}[0m"      # reset bold/blink
LESS_TERMCAP_so="${_omt_esc}[01;33m"  # begin reverse video
LESS_TERMCAP_se="${_omt_esc}[0m"      # reset reverse video
LESS_TERMCAP_us="${_omt_esc}[1;32m"   # begin underline
LESS_TERMCAP_ue="${_omt_esc}[0m"      # reset underline
export LESS_TERMCAP_mb LESS_TERMCAP_md LESS_TERMCAP_me LESS_TERMCAP_so LESS_TERMCAP_se LESS_TERMCAP_us LESS_TERMCAP_ue
unset _omt_esc

# Ctrl-S and Ctrl-Q are flow control by default, which freezes the terminal on
# the Ctrl-S save mapping in vim
if [ -t 0 ]; then
    stty -ixon 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Colors for ls, grep, diff and ip. These use the 16 ANSI colors, so they pick
# up the Nord palette from the terminal (see theme/emulator).
# ---------------------------------------------------------------------------
if omt_have dircolors; then
    if [ -r "$HOME/.dircolors" ]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
    export LS_COLORS="$LS_COLORS:ow=30;44:" # readable folders with 777 permissions
elif omt_have gdircolors; then
    eval "$(gdircolors -b)"
    export LS_COLORS="$LS_COLORS:ow=30;44:"
fi

if ls --color=auto -d . >/dev/null 2>&1; then
    alias ls='ls --color=auto'  # GNU ls
else
    export CLICOLOR=1           # BSD and macOS ls
fi

alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'  # fgrep and egrep are obsolescent in current GNU grep
alias egrep='grep -E --color=auto'
if diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
    alias diff='diff --color=auto'
fi
if omt_have ip && ip --color=auto -V >/dev/null 2>&1; then
    alias ip='ip --color=auto'
fi

# ---------------------------------------------------------------------------
# Aliases and functions
# ---------------------------------------------------------------------------
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'
alias lls='ls -lahS'
alias llt='ls -laht'
alias lld='ls -lad */'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

mkcd() {
    mkdir -p -- "$1" && cd -- "$1" || return
}

# ---------------------------------------------------------------------------
# Small CLI tools: ripgrep, bat, fzf (colors come from theme/palette.sh)
# ---------------------------------------------------------------------------
if [ -r "$OMT_HOME/cli/ripgreprc" ]; then
    export RIPGREP_CONFIG_PATH="$OMT_HOME/cli/ripgreprc"
fi
if [ -r "$OMT_HOME/cli/bat.conf" ]; then
    export BAT_CONFIG_PATH="$OMT_HOME/cli/bat.conf"
fi
if ! omt_have bat && omt_have batcat; then
    alias bat='batcat'  # Debian and Ubuntu install bat under this name
fi

export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border \
--color=bg+:#3B4252,bg:#2E3440,spinner:#81A1C1,hl:#616E88,fg:#D8DEE9,header:#616E88,info:#81A1C1,pointer:#81A1C1,marker:#81A1C1,fg+:#D8DEE9,prompt:#81A1C1,hl+:#81A1C1"
if omt_have rg; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Machine-specific environment can go in ~/.profile.local (read by both shells)
if [ -r "$HOME/.profile.local" ]; then
    . "$HOME/.profile.local"
fi
