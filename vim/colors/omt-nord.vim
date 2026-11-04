" omt-nord: a small, plugin-free Nord colorscheme for vim and Neovim.
" The hex values are the Nord palette (theme/palette.sh). The cterm numbers are
" the nearest xterm-256 colors, used when the terminal has no true color.

highlight clear
if exists('syntax_on')
    syntax reset
endif
set background=dark
let g:colors_name = 'omt-nord'

" name: [gui hex, cterm number]
let s:c = {
\   'n0':  ['#2E3440', 236],
\   'n1':  ['#3B4252', 238],
\   'n2':  ['#434C5E', 239],
\   'n3':  ['#4C566A', 59],
\   'n3b': ['#616E88', 60],
\   'n4':  ['#D8DEE9', 188],
\   'n5':  ['#E5E9F0', 254],
\   'n6':  ['#ECEFF4', 255],
\   'n7':  ['#8FBCBB', 109],
\   'n8':  ['#88C0D0', 110],
\   'n9':  ['#81A1C1', 109],
\   'n10': ['#5E81AC', 67],
\   'n11': ['#BF616A', 131],
\   'n12': ['#D08770', 173],
\   'n13': ['#EBCB8B', 222],
\   'n14': ['#A3BE8C', 108],
\   'n15': ['#B48EAD', 139],
\   'none': ['NONE', 'NONE'],
\ }

function! s:hi(group, fg, bg, attr) abort
    let l:cmd = 'highlight ' . a:group
    let l:cmd .= ' guifg=' . s:c[a:fg][0] . ' guibg=' . s:c[a:bg][0]
    let l:cmd .= ' ctermfg=' . s:c[a:fg][1] . ' ctermbg=' . s:c[a:bg][1]
    let l:cmd .= ' gui=' . a:attr . ' cterm=' . a:attr
    execute l:cmd
endfunction

" Editor
call s:hi('Normal',       'n4',   'n0',   'NONE')
call s:hi('Cursor',       'n0',   'n4',   'NONE')
call s:hi('CursorLine',   'none', 'n1',   'NONE')
call s:hi('CursorColumn', 'none', 'n1',   'NONE')
call s:hi('ColorColumn',  'none', 'n1',   'NONE')
call s:hi('CursorLineNr', 'n4',   'n1',   'NONE')
call s:hi('LineNr',       'n3b',  'none', 'NONE')
call s:hi('SignColumn',   'n4',   'none', 'NONE')
call s:hi('FoldColumn',   'n3b',  'none', 'NONE')
call s:hi('Folded',       'n3b',  'n1',   'NONE')
call s:hi('Visual',       'none', 'n2',   'NONE')
call s:hi('VisualNOS',    'none', 'n2',   'NONE')
call s:hi('Search',       'n0',   'n8',   'NONE')
call s:hi('IncSearch',    'n0',   'n7',   'underline')
call s:hi('MatchParen',   'n8',   'n3',   'bold')
call s:hi('NonText',      'n2',   'none', 'NONE')
call s:hi('SpecialKey',   'n3',   'none', 'NONE')
call s:hi('Directory',    'n8',   'none', 'NONE')
call s:hi('Conceal',      'n3b',  'none', 'NONE')
call s:hi('VertSplit',    'n3',   'n0',   'NONE')
call s:hi('EndOfBuffer',  'n0',   'none', 'NONE')

" Bars and menus
call s:hi('StatusLine',   'n4',   'n3',   'NONE')
call s:hi('StatusLineNC', 'n4',   'n1',   'NONE')
call s:hi('WildMenu',     'n0',   'n8',   'NONE')
call s:hi('TabLine',      'n4',   'n1',   'NONE')
call s:hi('TabLineFill',  'n4',   'n1',   'NONE')
call s:hi('TabLineSel',   'n0',   'n8',   'NONE')
call s:hi('Pmenu',        'n4',   'n2',   'NONE')
call s:hi('PmenuSel',     'n8',   'n3',   'NONE')
call s:hi('PmenuSbar',    'n4',   'n2',   'NONE')
call s:hi('PmenuThumb',   'n8',   'n3',   'NONE')

" Messages
call s:hi('ErrorMsg',     'n4',   'n11',  'NONE')
call s:hi('WarningMsg',   'n0',   'n13',  'NONE')
call s:hi('ModeMsg',      'n4',   'none', 'NONE')
call s:hi('MoreMsg',      'n14',  'none', 'NONE')
call s:hi('Question',     'n14',  'none', 'NONE')
call s:hi('Title',        'n14',  'none', 'bold')

" Syntax
call s:hi('Comment',      'n3b',  'none', 'NONE')
call s:hi('Constant',     'n4',   'none', 'NONE')
call s:hi('String',       'n14',  'none', 'NONE')
call s:hi('Character',    'n14',  'none', 'NONE')
call s:hi('Number',       'n15',  'none', 'NONE')
call s:hi('Boolean',      'n9',   'none', 'NONE')
call s:hi('Float',        'n15',  'none', 'NONE')
call s:hi('Identifier',   'n4',   'none', 'NONE')
call s:hi('Function',     'n8',   'none', 'NONE')
call s:hi('Statement',    'n9',   'none', 'NONE')
call s:hi('Operator',     'n9',   'none', 'NONE')
call s:hi('PreProc',      'n9',   'none', 'NONE')
call s:hi('Type',         'n7',   'none', 'NONE')
call s:hi('Special',      'n12',  'none', 'NONE')
call s:hi('SpecialChar',  'n13',  'none', 'NONE')
call s:hi('Delimiter',    'n6',   'none', 'NONE')
call s:hi('Underlined',   'n8',   'none', 'underline')
call s:hi('Ignore',       'n3',   'none', 'NONE')
call s:hi('Error',        'n4',   'n11',  'NONE')
call s:hi('Todo',         'n13',  'none', 'bold')

" Diff
call s:hi('DiffAdd',      'n14',  'n1',   'NONE')
call s:hi('DiffChange',   'n13',  'n1',   'NONE')
call s:hi('DiffDelete',   'n11',  'n1',   'NONE')
call s:hi('DiffText',     'n8',   'n3',   'NONE')

" Spelling
highlight SpellBad   guisp=#BF616A gui=undercurl ctermfg=131 cterm=underline
highlight SpellCap   guisp=#EBCB8B gui=undercurl ctermfg=222 cterm=underline
highlight SpellLocal guisp=#8FBCBB gui=undercurl ctermfg=109 cterm=underline
highlight SpellRare  guisp=#B48EAD gui=undercurl ctermfg=139 cterm=underline

delfunction s:hi
unlet s:c
