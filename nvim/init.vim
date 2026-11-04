" oh-my-term Neovim config: the full tier. It loads the minimal vimrc from this
" repository first (vim/vimrc), then adds plugins and their settings on top.
"
" Plugins come from vim-plug into ~/.local/share/nvim/plugged. Without network
" they are copied from vendor/ by setup.sh, and anything missing is skipped, so
" this file still starts and behaves like the minimal vimrc.
"
" Machine-specific settings: ~/.vimrc.pre (first) and ~/.vimrc.local (last).

let s:omt = !empty($OMT_HOME) ? $OMT_HOME : expand('~/.config/oh-my-term')

" The minimal vimrc must not source ~/.vimrc.local itself, it runs last here.
" The theme defaults to the Nord plugin, and ~/.vimrc.pre can still change it.
let g:omt_layered = 1
let g:omt_theme = 'nord'
execute 'source ' . fnameescape(s:omt . '/vim/vimrc')

" ---------------------------------------------------------------------------
" Plugins
" ---------------------------------------------------------------------------
" ALE reads these when it loads, so they go before plug#begin
let g:ale_completion_enabled = 1
let g:ale_fix_on_save = 1

let s:plug_file = stdpath('data') . '/site/autoload/plug.vim'
if filereadable(s:plug_file)
    call plug#begin(stdpath('data') . '/plugged')

    Plug 'preservim/nerdtree'
    Plug 'vim-airline/vim-airline'
    Plug 'tpope/vim-fugitive'
    Plug 'airblade/vim-gitgutter'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-commentary'
    Plug 'jiangmiao/auto-pairs'
    Plug 'matze/vim-move'
    Plug 'preservim/tagbar'
    Plug 'dyng/ctrlsf.vim'
    Plug 'derekwyatt/vim-fswitch'
    Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
    Plug 'junegunn/fzf.vim'
    Plug 'airblade/vim-rooter'
    Plug 'sheerun/vim-polyglot'
    Plug 'dense-analysis/ale'
    Plug 'editorconfig/editorconfig-vim'
    Plug 'nordtheme/vim', { 'as': 'nord' }

    call plug#end()
endif

" Nord from the plugin when it is installed, otherwise the bundled copy
try
    execute 'colorscheme ' . g:omt_theme
catch
    try
        colorscheme omt-nord
    catch
        colorscheme default
    endtry
endtry

" ---------------------------------------------------------------------------
" Mappings (they only do something when the plugin is installed)
" ---------------------------------------------------------------------------
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <C-p> :Files<CR>

nmap <C-F>f <Plug>CtrlSFPrompt
xmap <C-F>f <Plug>CtrlSFVwordPath
xmap <C-F>F <Plug>CtrlSFVwordExec
nmap <C-F>n <Plug>CtrlSFCwordPath
nnoremap <C-F>o :CtrlSFOpen<CR>
nnoremap <C-F>t :CtrlSFToggle<CR>
inoremap <C-F>t <Esc>:CtrlSFToggle<CR>
nmap <C-Z> :vsplit <bar> :wincmd l <bar> :FSRight<CR>
nmap <F2> :call AutoPairsToggle()<CR>
nmap <F3> :NERDTreeToggle<CR>
nmap <F4> :TagbarToggle<CR>
nmap <F5> :GitGutterToggle<CR>

" ---------------------------------------------------------------------------
" Plugin settings
" ---------------------------------------------------------------------------
let g:NERDTreeShowBookmarks = 1
let g:NERDTreeShowHidden = 1
let g:NERDTreeShowLineNumbers = 0
let g:NERDTreeMinimalMenu = 1
let g:NERDTreeWinPos = 'left'
let g:NERDTreeWinSize = 31

let g:tagbar_autofocus = 1
let g:tagbar_autoshowtag = 1
let g:tagbar_position = 'botright vertical'

if executable('rg')
    let g:ctrlsf_backend = 'rg'
elseif executable('ag')
    let g:ctrlsf_backend = 'ag'
else
    let g:ctrlsf_backend = 'ack'
endif
let g:ctrlsf_auto_close = { "normal":0, "compact":0 }
let g:ctrlsf_auto_focus = { "at":"start" }
let g:ctrlsf_auto_preview = 0
let g:ctrlsf_case_sensitive = 'smart'
let g:ctrlsf_default_view = 'normal'
let g:ctrlsf_regex_pattern = 0
let g:ctrlsf_position = 'right'
let g:ctrlsf_winsize = '46'
let g:ctrlsf_default_root = 'cwd'

let g:rooter_silent_chdir = 1
let g:EditorConfig_exclude_patterns = ['fugitive://.*']

let g:ale_linters = {
\   'python': ['flake8', 'pylint'],
\   'sh': ['shellcheck'],
\   'dockerfile': ['hadolint'],
\   'yaml': ['yamllint'],
\}
let g:ale_fixers = {
\   'python': ['autopep8'],
\   'sh': ['shfmt'],
\}

augroup omt_fswitch
    autocmd!
    autocmd BufEnter *.cpp let b:fswitchdst = 'hpp,h'
    autocmd BufEnter *.h let b:fswitchdst = 'cpp,c'
augroup END

if filereadable(expand('~/.vimrc.local'))
    source ~/.vimrc.local
endif
