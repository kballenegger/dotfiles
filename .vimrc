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

" matching of brackets, if else, etc
runtime macros/matchit.vim

" better buffers
set hidden

" better completion
set wildmode=list:longest

" scroll by three lines when cursor moves off screen
set scrolloff=3

" swap files location
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp

" scroll viewport faster
nnoremap <C-e> 3<C-e>
nnoremap <C-y> 3<C-y>

