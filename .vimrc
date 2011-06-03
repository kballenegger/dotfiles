set smartindent
set number
set tabstop=4
syntax on
filetype plugin on
filetype indent on
set shiftwidth=4
set expandtab

" mapping enter and shift enter to newline without insert mode

map <S-Enter> O<Esc>
map <CR> o<Esc>

" mapping to quick no indent

nnoremap <C-p> :set invpaste paste?<CR>
set pastetoggle=<C-p>
set showmode

