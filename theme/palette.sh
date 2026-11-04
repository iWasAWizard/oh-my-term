# oh-my-term palette: Nord (https://www.nordtheme.com). This is the one place
# the colors are defined. Configs that need a hex value (tmux, fzf, vim, the
# terminal emulator files) copy these values, and scripts/check-theme.sh fails
# if a config uses a hex color that is not listed here.
#
# Tools that can use the terminal's 16 ANSI colors (ls, grep, ripgrep, starship,
# screen) do, so that importing the emulator theme themes all of them at once.

NORD0='#2E3440'    # background
NORD1='#3B4252'    # ANSI black
NORD2='#434C5E'    # selection
NORD3='#4C566A'    # ANSI bright black
NORD3B='#616E88'   # comments
NORD4='#D8DEE9'    # foreground
NORD5='#E5E9F0'    # ANSI white
NORD6='#ECEFF4'    # ANSI bright white
NORD7='#8FBCBB'    # ANSI bright cyan
NORD8='#88C0D0'    # ANSI cyan
NORD9='#81A1C1'    # ANSI blue
NORD10='#5E81AC'
NORD11='#BF616A'   # ANSI red
NORD12='#D08770'
NORD13='#EBCB8B'   # ANSI yellow
NORD14='#A3BE8C'   # ANSI green
NORD15='#B48EAD'   # ANSI magenta
