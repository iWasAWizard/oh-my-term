# oh-my-term

One repository for the terminal tools I live in, set up the same way on every machine: a MacBook, an Unraid server, Kali and other Linux VMs, and boxes with no internet.

It replaces the separate oh-my-vim and oh-my-zsh repositories. Everything installs with symlinks, so editing a file in this repository changes the live config, and `git pull` updates every machine.

## Quick start

```sh
git clone git@github.com:iWasAWizard/oh-my-term.git
cd oh-my-term
./setup.sh                 # everything
./setup.sh bash vim screen # only the minimal tier
./setup.sh --list          # show the components
./setup.sh doctor          # check the install
```

`setup.sh` is idempotent. Anything it would replace is moved aside to `<name>.bak.<timestamp>` first. Open a new terminal afterwards, or run `reload`.

The installer runs on the bash that ships with macOS (3.2). It needs `git` and `curl` for the parts that download, and nothing else.

## Two tiers

Each tool has a minimal config and a full one. The minimal ones need no plugins, no network and no framework, so they work on a locked-down box. The full ones add plugins on top of the minimal ones.

| Job | Minimal | Full |
| --- | --- | --- |
| Shell | bash | zsh with Oh My Zsh |
| Editor | vim | neovim, layered on the minimal vimrc |
| Multiplexer | screen | tmux |

Both shells share `shell/common.sh` (PATH, editor, pager, colors, aliases, fzf options), so they behave the same. The neovim config sources `vim/vimrc` first and then adds vim-plug and the plugins, so the two editors share every mapping and option.

## Components

| Component | What it installs |
| --- | --- |
| `bash` | `~/.bashrc`, `~/.inputrc`, and a `~/.bash_profile` shim when you have no login-shell file yet |
| `zsh` | `~/.zshrc`, Oh My Zsh, zsh-autosuggestions, zsh-syntax-highlighting, and `chsh` to zsh |
| `vim` | `~/.vimrc` and the bundled `omt-nord` colorscheme |
| `nvim` | `~/.config/nvim/init.vim` and the plugins listed in it |
| `screen` | `~/.screenrc` |
| `tmux` | `~/.tmux.conf`, tmux-resurrect and tmux-continuum |
| `git` | shared settings in `~/.config/git/config`, a global ignore file, and a seeded `~/.gitconfig` for your identity |
| `ssh` | `~/.ssh/config` with keepalives and connection sharing |
| `gdb` | `~/.gdbinit` |
| `cli` | btop defaults. ripgrep, bat, less and fzf are configured by the shell files |
| `pi` | oh-my-pi (omp), a global `AGENTS.md` and a skills directory |
| `tools` | starship, fzf and autopep8 |

Flags and environment variables:

| Flag | Variable | Effect |
| --- | --- | --- |
| `--offline` | `OMT_OFFLINE=1` | Never use the network, install from `vendor/` |
| `--no-chsh` | `OMT_NO_CHSH=1` | Leave the login shell alone |
| `--no-tools` | `OMT_SKIP_TOOLS=1` | Skip the `tools` component |
| | `OMT_PLATFORM` | Force `macos`, `linux` or `unraid` |
| | `OMT_GO_FILE` | Unraid boot script to edit, default `/boot/config/go` |
| | `ZSH`, `ZSH_CUSTOM` | Oh My Zsh location, default `~/.oh-my-zsh` |

### Missing programs

Every config works without the programs that make up the full tier. At the end of an install, `setup.sh` lists the programs the chosen components use that are missing or too old (zsh, nvim, tmux, vim, screen, starship, fzf, omp and so on), what you get without each one, and a command that installs it when it knows the package manager. `--no-tools` leaves starship and fzf out of the list. The report only informs and never changes the exit status.

### Checking an install

`./setup.sh doctor` changes nothing. It reports:

- Program versions against the minimums: bash 3.2, zsh 5.0, tmux 3.0 and neovim 0.9. A program that is installed but too old counts as a failure.
- Whether every link and seeded file is in place. A broken link is a failure. A missing file, or one that points somewhere else, is a warning.
- Whether login bash sessions load `~/.bashrc`, whether the neovim plugins are installed, and whether `ssh -G` accepts the ssh config.
- Which tier the machine runs for the shell, the editor and the multiplexer, and what is missing for the full one.

Pass component names to check only those links, for example `./setup.sh doctor bash vim`. The exit status is 1 when anything failed, and warnings alone do not change it.

### How the links work

`setup.sh` links `~/.config/oh-my-term` to wherever you cloned the repository. The rc files find `shell/common.sh` through that link, so the clone can live anywhere and move later. Run `setup.sh` again after moving it.

Files that tools rewrite themselves are copied once and never overwritten: `~/.gitconfig`, `~/.config/btop/btop.conf` and `~/.ssh/config.local`. The omp `config.yml` and `models.yml` are not touched at all.

## Machines with no internet

On a machine that has internet, from inside the repository:

```sh
./scripts/vendor.sh
```

This fills `vendor/` with Oh My Zsh, the zsh plugins, the tmux plugins, vim-plug, every neovim plugin listed in `nvim/init.vim`, and starship builds for Linux and macOS on x86_64 and arm64 (checked against their published sha256). `vendor/` is ignored by git.

Copy the whole directory to the other machine, for example with `tar`, and run:

```sh
./setup.sh --offline
```

Offline installs skip omp, fzf and autopep8, because none of them has a vendored copy. The shell files skip anything that is not present, so nothing breaks, and you can add those by hand later. The minimal tier needs none of this and works from a plain clone.

## Unraid

Unraid keeps its root filesystem in RAM, so anything in `/root` disappears at reboot. On Unraid, `setup.sh` adds a block to `/boot/config/go` that reruns `setup.sh --offline --no-chsh` with the components you chose, and the links come back on every boot.

Put the repository on the flash drive for this, for example `/boot/config/oh-my-term`, and run `./scripts/vendor.sh` on another machine first so `vendor/` is there. The installer warns if the repository is not under `/boot`. To change the component list afterwards, edit the `# oh-my-term persistence` block in the go file.

## Per-machine settings

Nothing machine-specific belongs in the repository. Each tool reads an optional local file:

| File | Read | Use it for |
| --- | --- | --- |
| `~/.profile.local` | by bash and zsh, from `common.sh` | environment variables, PATH |
| `~/.bashrc.pre`, `~/.bashrc.local` | first, last | bash overrides |
| `~/.zshrc.pre`, `~/.zshrc.local` | first, last | zsh overrides. Extra Oh My Zsh plugins go in `OMT_ZSH_EXTRA_PLUGINS` |
| `~/.vimrc.pre`, `~/.vimrc.local` | first, last | vim and neovim overrides. Set `g:omt_theme` in `.pre` to change the colorscheme |
| `~/.tmux.conf.local` | last | tmux overrides |
| `~/.gdbinit.local` | last | gdb overrides |
| `~/.ssh/config.local` | first | hosts. `ssh/config.local.example` has examples, including a block for old network gear that needs legacy algorithms |
| `~/.gitconfig` | after the shared config | your name, email and signing key |

## Theme

The palette is Nord. `theme/palette.sh` is the single definition, and `scripts/check-theme.sh` fails if a config uses a hex color that is not in it.

Tools that can use the 16 ANSI colors do (ls, grep, ripgrep, less, starship, screen), so they follow your terminal's palette. Importing a Nord theme into the terminal app themes all of them at once. The files are in `theme/emulator/`:

- `nord.itermcolors` for iTerm2
- `nord.alacritty.toml` for Alacritty
- `nord.kitty.conf` for kitty

`theme/gen-emulator.py` regenerates them from the palette. Tools that need explicit colors (tmux, fzf, vim, bat, btop) use the matching Nord hex values.

## Prompt

When starship is installed, both shells use `shell/starship.toml`, a two-line prompt in the style of the Kali default:

```
┌──(user㉿host)-[~/some/dir] main !2 py v3.13.1
└─$
```

The exit code and background job count appear at the end of the first line. Without starship, bash falls back to a plain colored prompt with the exit code and virtualenv, and zsh falls back to the Kali prompt it carried before.

## tmux and screen

The tmux config uses the screen keys, so switching between them does not cost muscle memory.

| Keys | Action |
| --- | --- |
| `C-a` | prefix, in both |
| `C-a a` | send a literal `C-a` |
| `C-a C-a` | last window |
| `C-a c` | new window |
| `C-a A` | rename window |
| `C-a "` | window list |
| `C-a Space` | next window |
| `C-a \|` and `C-a -` | split side by side and stacked (tmux) |
| `C-a h/j/k/l` | move between panes (tmux) |
| `C-a r` | reload the config (tmux) |

tmux needs version 3.0 or newer. Copying inside tmux reaches the local clipboard over SSH through OSC52, provided the terminal app allows it. Neovim 0.10 and newer handles OSC52 itself, and the config carries its own copy for older versions.

screen stays in the minimal tier because it handles serial consoles (`screen /dev/ttyUSB0 115200`) and is installed on nearly everything.

## pi

[oh-my-pi](https://omp.sh) (`omp`) is the agent harness. The `pi` component links `pi/AGENTS.md` to `~/.omp/agent/AGENTS.md` and `pi/skills/` to `~/.omp/agent/skills`, then installs omp with bun, or with Homebrew if there is no bun.

- Put global instructions in `pi/AGENTS.md`. Put skills in `pi/skills/<name>/SKILL.md`.
- For a local OpenAI-compatible server, copy `pi/models.yml.example` to `~/.omp/agent/models.yml` and edit it.
- bun skips the postinstall scripts of two of omp's dependencies (onnxruntime-node and protobufjs) by default. omp started fine without them in testing. Run `bun pm -g trust --all` if a feature complains.

## Layout

```
setup.sh            installer
lib/install.sh      helpers used by setup.sh and scripts/vendor.sh
lib/doctor.sh       the checks behind setup.sh doctor
scripts/            vendor.sh (fill vendor/), check-theme.sh, smoke.sh, ci-install.sh
shell/              bashrc, zshrc, common.sh, inputrc, starship.toml
vim/  nvim/         vimrc and colorscheme, init.vim
screen/  tmux/      screenrc, tmux.conf
git/  ssh/  gdb/    gitconfig and ignore, ssh config, gdbinit
cli/                ripgrep, bat and btop configs
theme/              palette.sh, gen-emulator.py, emulator/
pi/                 AGENTS.md, skills/, models.yml.example
vendor/             downloads for offline installs (git-ignored)
```

## Notes

- Not yet run on real macOS, and not yet run on a physical Unraid box. Linux behavior was tested with a fake `$HOME`, including pty-driven bash and zsh sessions, the offline path with the network cut, and the Unraid go-file edit.
- Oh My Zsh installed from `vendor/` has no `.git` directory, so its self-update is switched off for that install.
- Shell prompts use Unicode box characters and `㉿`. The terminal font needs to have them.
- No chezmoi. Symlinks cover the one-user, few-machine case and work on the airgapped boxes. If the number of machines grows or you want per-host templating, chezmoi can read this repository as its source later.

## Testing

GitHub Actions (`.github/workflows/ci.yml`) runs on every push to `main` and every pull request:

- shellcheck, a no-tabs check and `scripts/check-theme.sh`.
- A full install in fresh Debian 13, Ubuntu 24.04 and Alpine 3.22 containers, and on `macos-latest` with `/bin/bash` (bash 3.2). Each one installs twice and fails if the second run creates backup files, then runs `setup.sh doctor` and `scripts/smoke.sh`. `oh-my-pi` is linked but not installed.
- A minimal-tier install (bash, vim, screen, no network) that checks `doctor` reports the minimal tier.

To run the install test yourself, use a throwaway home, because it writes there:

```sh
HOME="$(mktemp -d)" ./scripts/ci-install.sh
```

## License

MIT, see `LICENSE`.
