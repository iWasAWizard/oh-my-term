# oh-my-term roadmap

Handoff notes for continuing work in Claude Code. The first version is built and was tested on Linux. This file lists what is untested, what is missing, and what to build next, roughly in priority order.

## Project constraints

- No unmaintained or unsupported tools or dependencies. thefuck was removed for this reason, because 3.32 does not run on Python 3.12 or newer.
- The minimal tier (bash, vim, screen) needs no plugins, no network and no framework.
- `setup.sh` and `lib/install.sh` must stay compatible with bash 3.2, the bash that ships with macOS. Do not use associative arrays, `mapfile`, `${var,,}` or other bash 4+ features.
- `shell/common.sh` is POSIX sh and is sourced by both bash and zsh.
- Everything installs as symlinks into `$HOME`, through the stable `~/.config/oh-my-term` link. Files that tools rewrite are seeded once and never overwritten.
- Code style: spaces, never tabs. Complete files, no truncation. No emojis in documentation.
- `scripts/check-theme.sh` and `shellcheck -e SC1091` should stay clean.

## What was tested

Linux only, using fake `$HOME` directories in a container:

- nvim 0.9.5 with and without plugins, including the theme fallback
- tmux 3.4 (config loads without errors, key bindings), screen 4.09, gdb 15.1, git
- bash and zsh in a pty, with and without starship, including history search on the arrow keys
- `setup.sh` with every component, the offline path with the network cut after `vendor.sh`, and the Unraid go-file edit including re-runs
- omp 18.16.0 installed with bun

## What was not tested

- Real macOS, including bash 3.2 itself. The constraint is met by avoiding newer syntax and by shellcheck, not by a run.
- A physical Unraid box. It is also unverified what a current Unraid release ships. As far as I know it has neither zsh nor neovim.
- The ssh config, because the container had no ssh client. `ssh -G somehost` would validate it.
- Real terminal apps importing the files in `theme/emulator/`.

## Priority 1: close the testing gaps

1. GitHub Actions workflow.
   - Run shellcheck and `scripts/check-theme.sh`.
   - Run `setup.sh` in fresh Debian, Ubuntu and Alpine containers. Alpine will show whether the bash requirement bites.
   - Run `setup.sh` on `macos-latest`.
   - Run `ssh -G` against the shipped ssh config.
2. `./setup.sh doctor`. Check that every link resolves, report tool versions against the minimums (tmux 3.0, neovim 0.9, bash 3.2, zsh 5.x), and list what is missing and which tier the machine falls back to.
3. Missing-programs report at the end of `setup.sh`, for machines where zsh, nvim, tmux or starship are not installed. Print exactly what is missing and what you get without it.

## Priority 2: airgap and supply chain

1. Pin `scripts/vendor.sh`. It currently clones HEAD of every repository and downloads starship `latest`. Add a lockfile of commit SHAs and tarball sha256 values, checked into the repository, so bundles are reproducible and refreshes show up as a reviewable diff. The starship checksum is fetched from the same release as the tarball, so it catches corruption but not tampering.
2. `scripts/bundle.sh`. Run `vendor.sh`, tar the repository plus `vendor/`, and write a sha256 manifest. The transfer to an isolated machine becomes one file that can be verified on arrival.
3. Programs on airgapped machines. `vendor.sh` carries configs and plugins and starship, but not zsh, neovim or tmux. Options are static builds of nvim and tmux in `vendor/bin`, or relying on the missing-programs report from priority 1.
4. ALE linters and fixers. `nvim/init.vim` configures flake8, pylint, shellcheck, hadolint, yamllint, shfmt and autopep8. Only autopep8 is installed by the `tools` component, so the rest fail quietly. Either install them, vendor them, or trim the config to what is present.

## Priority 3: installer features

- `setup.sh --dry-run`, to print what would be linked, seeded or installed.
- `setup.sh --uninstall`, which is easy because everything is a symlink. It should restore the newest `.bak.<timestamp>` when one exists.
- `setup.sh --update`, to pull the repository and refresh plugins. Offline machines get the same result from a new bundle.
- Cosmetic: the Unraid go-file line has a double space in the component list.

## Priority 4: content

- `pi/skills/` is empty and `pi/AGENTS.md` is a starter. Add the real skills and global rules.
- bun skips the postinstall scripts of onnxruntime-node and protobufjs for omp. omp started without them. Revisit if a feature complains, with `bun pm -g trust --all`.
- Archive oh-my-vim and oh-my-zsh with a pointer to this repository.

## Later, only if there is a reason

- gdb extension layer for binary analysis work. It would need vendoring for airgap, and some are heavy.
- Serial tooling config for boxes where screen is not ideal (picocom or minicom).
- Per-host profiles, such as `server` and `workstation`, that skip components automatically. This is the case where chezmoi earns its place. With four or five machines, `~/.zshrc.local` and friends are enough. chezmoi could use this repository as its source later.
- Neovim modernization with built-in LSP and treesitter. It is a rewrite, and nothing is forcing it. The current plugin set is the same vim-plug list as before.
- Terminal emulator settings beyond colors, such as fonts and key bindings.
- Shell startup time benchmark for the zsh config.

## Decisions already made

- Ship bash and zsh, vim and neovim, screen and tmux. Minimal tier for bash, vim and screen. Full tier for zsh, neovim and tmux.
- Palette is Nord. Tools that can use the 16 ANSI colors do, so importing a terminal theme themes them. Tools that need explicit colors use the hex values from `theme/palette.sh`.
- starship is optional. bash falls back to a plain colored prompt, zsh falls back to the Kali prompt.
- oh-my-pi (omp) is the pi framework. `setup.sh` links `AGENTS.md` and `skills/` and never touches omp's `config.yml` or `models.yml`.
- No chezmoi in the first version.
- tmux uses the screen prefix and window keys on purpose, so switching between them keeps muscle memory.
