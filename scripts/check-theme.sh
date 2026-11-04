#!/usr/bin/env bash
#
# Fails if a config uses a hex color that is not in theme/palette.sh.
# Run it after editing any theme or color setting.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
palette="${repo_root}/theme/palette.sh"

allowed="$(grep -oE "#[0-9A-Fa-f]{6}" "$palette" | tr 'a-f' 'A-F' | sort -u)"

status=0
while IFS= read -r file; do
    for color in $(grep -oE "#[0-9A-Fa-f]{6}\b" "$file" | tr 'a-f' 'A-F' | sort -u); do
        if ! printf '%s\n' "$allowed" | grep -qx "$color"; then
            printf 'not in palette: %s in %s\n' "$color" "${file#"${repo_root}/"}"
            status=1
        fi
    done
done < <(find "${repo_root}/tmux" "${repo_root}/vim" "${repo_root}/shell" "${repo_root}/theme/emulator" \
    -type f ! -name '*.md')

if [ "$status" = 0 ]; then
    printf 'all colors are in the palette\n'
fi
exit "$status"
