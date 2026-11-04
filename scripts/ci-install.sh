#!/usr/bin/env bash
#
# The install test CI runs on every platform: install every component into
# $HOME, install again to prove it changes nothing, then run doctor and the
# smoke test. It writes into $HOME, so run it with a throwaway one:
#
#   HOME="$(mktemp -d)" ./scripts/ci-install.sh
#
# Environment variables:
#   OMT_SETUP_BASH   the bash that runs setup.sh (default: bash on PATH).
#                    CI sets /bin/bash on macOS to get bash 3.2.
#   OMT_OFFLINE=1    link only, no downloads (setup.sh reads this itself)
#   OMT_SKIP_TOOLS   outside CI this defaults to 1, because the tools component
#                    installs starship and fzf with Homebrew, which is not
#                    limited to $HOME. Set it to 0 to test that too.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install.sh
. "${repo_root}/lib/install.sh"

# setup.sh honors these, and a value left over in your shell would send the test
# to your real Oh My Zsh, Neovim and omp directories instead of $HOME.
unset ZSH ZSH_CUSTOM XDG_CONFIG_HOME XDG_DATA_HOME OMP_AGENT_DIR

real_home="$(eval "printf '%s' ~$(id -un)")"
if [ -z "${CI:-}" ] && [ "$HOME" = "$real_home" ]; then
    die "this would install into your real home. Use a throwaway one: HOME=\"\$(mktemp -d)\" $0"
fi
if [ -z "${CI:-}" ]; then
    export OMT_SKIP_TOOLS="${OMT_SKIP_TOOLS:-1}"
fi

bash_bin="${OMT_SETUP_BASH:-bash}"
export OMT_SMOKE_BASH="${OMT_SMOKE_BASH:-$bash_bin}"

setup() {
    "$bash_bin" "${repo_root}/setup.sh" --no-chsh "$@"
}

# Backups are named <file>.bak.<timestamp>. A second install must not add any.
count_backups() {
    find "$HOME" -maxdepth 4 -name '*.bak.*' -not -path "${HOME}/Library/*" 2>/dev/null | wc -l | tr -d ' '
}

# shellcheck disable=SC2016 # $BASH_VERSION must expand in the bash being tested, not here
printf 'bash for setup.sh: %s\n' "$("$bash_bin" -c 'printf %s "$BASH_VERSION"')"

log "First install"
# pi is linked only. Installing omp pulls in bun or a Homebrew tap, which is not what this tests.
setup bash zsh vim nvim screen tmux git ssh gdb cli tools
setup --offline pi
before="$(count_backups)"

log "Second install"
setup bash zsh vim nvim screen tmux git ssh gdb cli tools
setup --offline pi
after="$(count_backups)"
if [ "$before" != "$after" ]; then
    die "the second install created $((after - before)) backup file(s), so it is not idempotent"
fi

log "Doctor"
setup doctor

log "Smoke test"
"${repo_root}/scripts/smoke.sh"

# The checks below use empty homes of their own, so they do not disturb the install above.

log "--dry-run changes nothing"
dry_home="$(mktemp -d)"
HOME="$dry_home" setup --dry-run --offline >/dev/null
HOME="$dry_home" OMT_OFFLINE=0 setup --update --dry-run bash >/dev/null
if [ -n "$(find "$dry_home" -mindepth 1)" ]; then
    die "--dry-run created files in $dry_home: $(find "$dry_home" -mindepth 1 | head -n 5)"
fi

log "--update refuses to run offline"
if HOME="$dry_home" setup --update --offline >/dev/null 2>&1; then
    die "--update --offline should have failed"
fi

log "--uninstall removes the links and puts your files back"
un_home="$(mktemp -d)"
mkdir -p "${un_home}/.ssh"
printf 'my bashrc\n' > "${un_home}/.bashrc"
printf 'Host work\n' > "${un_home}/.ssh/config"
HOME="$un_home" setup --offline --no-tools >/dev/null
HOME="$un_home" setup --uninstall >/dev/null
[ "$(cat "${un_home}/.bashrc")" = "my bashrc" ] || die "--uninstall did not restore ~/.bashrc"
[ "$(cat "${un_home}/.ssh/config")" = "Host work" ] || die "--uninstall did not restore ~/.ssh/config"
find "$un_home" -type l | while read -r link; do
    case "$(readlink "$link")" in
        "${repo_root}"*) die "--uninstall left $link -> $(readlink "$link")" ;;
    esac
done

log "--uninstall restores the newest of several backups"
gen_home="$(mktemp -d)"
printf 'first\n' > "${gen_home}/.bashrc"
HOME="$gen_home" setup --offline --no-tools bash >/dev/null
rm -f "${gen_home}/.bashrc"
printf 'second\n' > "${gen_home}/.bashrc"
HOME="$gen_home" setup --offline --no-tools bash >/dev/null
rm -f "${gen_home}/.bashrc"
printf 'third\n' > "${gen_home}/.bashrc"
HOME="$gen_home" setup --offline --no-tools bash >/dev/null
# All three land within a second or two, and none may overwrite another
[ "$(find "$gen_home" -maxdepth 1 -name '.bashrc.bak.*' | wc -l | tr -d ' ')" = "3" ] \
    || die "expected three backups of ~/.bashrc, found: $(find "$gen_home" -maxdepth 1 -name '.bashrc.bak.*')"
HOME="$gen_home" setup --uninstall bash >/dev/null
[ "$(cat "${gen_home}/.bashrc")" = "third" ] || die "--uninstall did not restore the newest backup"
[ "$(find "$gen_home" -maxdepth 1 -name '.bashrc.bak.*' | wc -l | tr -d ' ')" = "2" ] \
    || die "--uninstall should leave the two older backups where they are"

log "--update pulls a new commit from a real remote and restarts with it"
# A throwaway remote on disk, so this needs no network. The copy leaves out .git, vendor/ and
# dist/, which also lets it run from an extracted bundle that is not a git checkout.
upd="$(mktemp -d)"
mkdir "${upd}/seed"
(cd "$repo_root" && tar --exclude=.git --exclude=vendor --exclude=dist -cf - .) | tar -C "${upd}/seed" -xf -
ci_git() {
    git -c user.name=ci -c user.email=ci@example.invalid "$@"
}
ci_git -C "${upd}/seed" init -q
ci_git -C "${upd}/seed" symbolic-ref HEAD refs/heads/main
ci_git -C "${upd}/seed" add -A
ci_git -C "${upd}/seed" commit -q -m base
ci_git clone -q --bare "${upd}/seed" "${upd}/origin.git"
ci_git clone -q "${upd}/origin.git" "${upd}/installed"
ci_git clone -q "${upd}/origin.git" "${upd}/other"
ci_git -C "${upd}/other" commit -q --allow-empty -m "a new commit upstream"
ci_git -C "${upd}/other" push -q origin main
upd_home="$(mktemp -d)"
HOME="$upd_home" OMT_OFFLINE=0 "$bash_bin" "${upd}/installed/setup.sh" --update --no-chsh --no-tools bash >/dev/null
[ "$(ci_git -C "${upd}/installed" rev-parse HEAD)" = "$(ci_git -C "${upd}/other" rev-parse HEAD)" ] \
    || die "--update did not pull the new commit"
case "$(readlink "${upd_home}/.bashrc")" in
    "${upd}/installed/"*) ;;
    *) die "--update installed from somewhere other than the updated checkout: $(readlink "${upd_home}/.bashrc")" ;;
esac
