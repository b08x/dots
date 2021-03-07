" Plugins will be downloaded under the specified directory.
call plug#begin('~/.vim/plugged')

" Declare the list of plugins.
Plug 'tpope/vim-sensible'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'connorholyday/vim-snazzy'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'https://github.com/dermusikman/sonicpi.vim.git'
Plug 'preservim/nerdtree'
Plug 'https://github.com/jalvesaq/vimcmdline.git'

" List ends here. Plugins become visible to Vim after this call.
call plug#end()

let mapleader = "\<space>"

command! FR set filetype=ruby

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
nnoremap <A-Right> <C-w>l
nnoremap <A-Left> <C-w>h
nnoremap <A-Up> <C-w>k
nnoremap <A-Down> <C-w>j

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

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"


nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

"let g:RubyRunner_key = '<Leader>b'
"let g:RubyRunner_keep_focus_key = '<Leader>B'
"let g:RubyRunner_open_below = 1

let cmdline_app           = {}
let cmdline_app['ruby']   = 'pry'
let cmdline_app['sh']     = 'bash'
let cmdline_in_buffer = 0
let cmdline_external_term_cmd = "terminator -e '%s' &"
