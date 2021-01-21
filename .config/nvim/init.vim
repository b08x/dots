" Plugins will be downloaded under the specified directory.
call plug#begin('~/.vim/plugged')

" Declare the list of plugins.
Plug 'tpope/vim-sensible'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'rrethy/vim-hexokinase', { 'do': 'make hexokinase' }
Plug 'connorholyday/vim-snazzy'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'https://github.com/dermusikman/sonicpi.vim.git'
Plug 'preservim/nerdtree'


" List ends here. Plugins become visible to Vim after this call.
call plug#end()

" Configure autoindent
set tabstop=2 softtabstop=2 expandtab shiftwidth=2 autoindent

" remember last cursor place
au BufReadPost * if line("'\"") > 0|if line("'\"") <= line("$")|exe("norm '\"")|else|exe "norm $"|endif|endif

" Configure Airline
let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
      let g:airline_symbols = {}
endif
let g:airline_symbols.space = "\ua0"
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_buffers = 0
let g:airline_theme = 'minimalist'

" Configure hexokinase colorizer
:set termguicolors
let g:Hexokinase_highlighters = [ 'virtual' ]

" Set colorscheme
let g:SnazzyTransparent = 1
colorscheme snazzy

" Default term cursor
set guicursor=

" Enable copy to system clipboard
set clipboard+=unnamedplus

let g:sonicpi_command = 'sonic-pi-tool'
let g:sonicpi_send = 'eval-stdin'
let g:sonicpi_stop = 'stop'
let g:vim_redraw = 1

" Window navigation
noremap <A-Right> <C-w>l
noremap <A-Left> <C-w>h
noremap <A-Up> <C-w>k
noremap <A-Down> <C-w>j

map <F2> :NERDTreeToggle<cr>

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
"inoremap <silent><expr> <TAB>
"      \ pumvisible() ? "\<C-n>" :
"      \ <SID>check_back_space() ? "\<TAB>" :
"      \ coc#refresh()
"inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

"set runtimepath^=~/.vim runtimepath+=~/.vim/after
"let &packpath = &runtimepath
"source ~/.vimrc

