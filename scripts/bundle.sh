#!/usr/bin/env bash
#
# Packs the repository and vendor/ into one archive for a machine with no
# internet, and checks the result on arrival.
#
#   ./scripts/bundle.sh                 fill vendor/ from vendor.lock, then write
#                                       dist/oh-my-term-<commit>.tar.gz and a .sha256 beside it
#   ./scripts/bundle.sh --allow-dirty   bundle even with uncommitted changes
#   ./scripts/bundle.sh --verify [DIR]  check an extracted bundle against its
#                                       manifest (default: this repository)
#
# On the isolated machine:
#
#   shasum -a 256 -c oh-my-term-<commit>.tar.gz.sha256   (sha256sum -c on Linux)
#   tar -xzf oh-my-term-<commit>.tar.gz
#   cd oh-my-term && ./scripts/bundle.sh --verify && ./setup.sh --offline
#
# The archive holds MANIFEST.sha256 (the sha256 of every file), MANIFEST.links
# (every symlink and where it points) and BUNDLE (the commit it was built from).
# The manifest travels with the files it describes, so it catches corruption and
# edits made in transit. To catch a swapped archive too, write the .sha256 value
# down on the machine you built it on and compare it by another route.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/install.sh
. "${repo_root}/lib/install.sh"

out_dir="${OMT_BUNDLE_DIR:-${repo_root}/dist}"

usage() {
    sed -n '3,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# sha256_files: reads file names on stdin, one per line, prints "hash  name" for each
sha256_files() {
    if have sha256sum; then
        tr '\n' '\0' | xargs -0 sha256sum
    else
        tr '\n' '\0' | xargs -0 shasum -a 256
    fi
}

# sha256_check MANIFEST: prints every line that did not check out, fails if there was one
sha256_check() {
    local out errors status=0

    # Separate streams: the tools buffer stdout, and one pipe for both splits lines
    errors="$(mktemp)"
    if have sha256sum; then
        out="$(sha256sum -c "$1" 2>"$errors")" || status=$?
    else
        out="$(shasum -a 256 -c "$1" 2>"$errors")" || status=$?
    fi
    printf '%s\n' "$out" | grep -v ': OK$' | grep -v '^[[:space:]]*$' || true
    grep -v '^[[:space:]]*$' "$errors" || true
    rm -f "$errors"
    return "$status"
}

# list_links: every symlink under the current directory as "path -> target"
list_links() {
    local link

    find . -type l | LC_ALL=C sort | while read -r link; do
        printf '%s -> %s\n' "$link" "$(readlink "$link")"
    done
}

# list_files: every regular file under the current directory except the manifest
list_files() {
    find . -type f ! -name MANIFEST.sha256 | LC_ALL=C sort
}

# write_manifests: run inside the tree. The links come first so the file manifest covers them.
write_manifests() {
    list_links > MANIFEST.links
    list_files | sha256_files > MANIFEST.sha256
}

# verify_tree DIR
verify_tree() {
    local dir="$1"
    local problems=0
    local extra links_now

    [ -f "${dir}/MANIFEST.sha256" ] || die "no MANIFEST.sha256 in ${dir}, so this is not a bundle"
    [ -f "${dir}/MANIFEST.links" ] || die "no MANIFEST.links in ${dir}, so this is not a bundle"
    cd -- "$dir"

    log "Checking every file against MANIFEST.sha256"
    if ! sha256_check MANIFEST.sha256; then
        problems=$((problems + 1))
    fi

    # Files the manifest does not mention were added after the bundle was built
    extra="$(comm -13 <(awk '{ sub(/^[^ ]+  /, ""); print }' MANIFEST.sha256 | LC_ALL=C sort) <(list_files))"
    if [ -n "$extra" ]; then
        printf 'not in the manifest: %s\n' "$extra" | sed '2,$s/^/                     /'
        problems=$((problems + 1))
    fi

    links_now="$(list_links)"
    if [ "$links_now" != "$(cat MANIFEST.links)" ]; then
        warn "the symlinks differ from MANIFEST.links:"
        diff <(cat MANIFEST.links) <(printf '%s\n' "$links_now") >&2 || true
        problems=$((problems + 1))
    fi

    if [ "$problems" -ne 0 ]; then
        die "${dir} does not match its manifest"
    fi
    log "All $(wc -l < MANIFEST.sha256 | tr -d ' ') files and $(wc -l < MANIFEST.links | tr -d ' ') symlinks match"
    if [ -f BUNDLE ]; then
        sed 's/^/    /' BUNDLE
    fi
}

build_bundle() {
    local allow_dirty="$1"
    local commit dirty="" name stage archive list

    have git || die "git is required to build a bundle"
    git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || die "${repo_root} is not a git checkout"
    commit="$(git -C "$repo_root" rev-parse --short HEAD)"
    if [ -n "$(git -C "$repo_root" status --porcelain --untracked-files=no)" ]; then
        if [ "$allow_dirty" != "1" ]; then
            die "there are uncommitted changes to tracked files, so the bundle would not match a commit. Commit them, or pass --allow-dirty."
        fi
        dirty="-dirty"
    fi

    log "Filling vendor/ from vendor.lock"
    "${repo_root}/scripts/vendor.sh"
    "${repo_root}/scripts/vendor.sh" --verify

    name="oh-my-term-${commit}${dirty}"
    stage="$(mktemp -d)"
    mkdir -p "${stage}/oh-my-term" "$out_dir"
    archive="${out_dir}/${name}.tar.gz"

    log "Copying the tracked files and vendor/"
    list="${stage}/files"
    { git -C "$repo_root" ls-files; printf 'vendor\n'; } > "$list"
    tar -C "$repo_root" -cf - -T "$list" | tar -C "${stage}/oh-my-term" -xf -

    {
        printf 'oh-my-term bundle\n'
        printf 'commit: %s%s\n' "$(git -C "$repo_root" rev-parse HEAD)" "$dirty"
        printf 'built:  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'lock:   %s\n' "$(sha256_of "${repo_root}/vendor.lock")"
    } > "${stage}/oh-my-term/BUNDLE"

    log "Writing the manifests"
    (cd -- "${stage}/oh-my-term" && write_manifests)

    log "Writing ${archive}"
    tar -C "$stage" -czf "$archive" oh-my-term
    (cd -- "$out_dir" && printf '%s\n' "${name}.tar.gz" | sha256_files > "${name}.tar.gz.sha256")
    rm -rf "${stage:?}"

    log "Built ${archive} ($(du -h "$archive" | cut -f 1 | tr -d ' '))"
    log "sha256 $(cut -d ' ' -f 1 "${archive}.sha256"). Write this down here and compare it on the other machine."
}

mode=build
allow_dirty=0
target="$repo_root"
while [ $# -gt 0 ]; do
    case "$1" in
        --allow-dirty) allow_dirty=1 ;;
        --verify)
            mode=verify
            if [ $# -gt 1 ]; then
                target="$2"
                shift
            fi
            ;;
        -h | --help) usage; exit 0 ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

case "$mode" in
    build) build_bundle "$allow_dirty" ;;
    verify) verify_tree "$target" ;;
esac
