" kill vi compatibility
set nocompatible

" ==============================
"           PATHOGEN
" ==============================

" use YCM if possible, otherwise use supertab
if filereadable($HOME . "/.vim/bundle/you-complete-me/third_party/ycmd/ycm_core.so")
    let g:pathogen_disabled = ['supertab']
else
    let g:pathogen_disabled = ['you-complete-me']
endif

" enable pathogen
call pathogen#infect()


" ==============================
"              VIM
" ==============================

" go-lang (this must come before syntax on, for some reason...)
set rtp+=$GOROOT/misc/vim

" enable file types and syntax highlighing
syntax on
filetype plugin on
filetype indent on

" color scheme
let g:solarized_termcolors=256
set background=dark
colorscheme solarized
highlight clear SignColumn

" show line numbers
set number

" basic editor things
set encoding=utf-8
set ttyfast
set showcmd
set hidden
set ruler
set cursorline

" scroll by three lines when cursor moves off screen
set scrolloff=7

" indentation
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab

" tabs & buffers
set showtabline=1

" search
nnoremap / /\v
vnoremap / /\v
nnoremap ? ?\v
vnoremap ? ?\v
set ignorecase
set smartcase
set gdefault

" swap files location
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp

" wrapping
set wrap
set textwidth=80
set formatoptions=qrn1

" over 80-char width
set colorcolumn=+1
highlight OverLength ctermbg=233 ctermfg=124
match OverLength /\%81v.\+/

" trailing whitespace highlight
highlight ExtraWhitespace ctermbg=238
au InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
au InsertLeave * match ExtraWhitespace /\s\+$/

" backspace bullshit
set backspace=indent,eol,start

" mouse
if has("mouse")
    set mouse=a
endif

" use system clipboard
set clipboard=unnamed

" map . in visual mode to repeat on each line
vnoremap . :normal .<CR>

" execute local .vimrcs, disallowing certain commands
set exrc
set secure


" ==============================
"           MAPPINGS
" ==============================

" tabs & buffers
nnoremap <leader>[ :bn<CR>
nnoremap <leader>] :bp<CR>
" delete buffer without closing splits
nnoremap <leader>w :enew\|bd<space>#<CR>
" loads an empty buffer
nnoremap <leader>o :enew<CR>

" tabs are 'layouts'
nnoremap <leader>l :tabnew<CR>
nnoremap <leader>{ :tabprev<CR>
nnoremap <leader>} :tabnext<CR>

" disable help mapping
nnoremap <F1> <nop>
inoremap <F1> <nop>
vnoremap <F1> <nop>

" reselect pasted text
nnoremap <leader>v V`]

" disable arrow keys
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>

nnoremap j gj
nnoremap k gk

" fix arrow keys in tmux
nnoremap <Esc>A <nop>
nnoremap <Esc>B <nop>
nnoremap <Esc>C <nop>
nnoremap <Esc>D <nop>
inoremap <Esc>A <nop>
inoremap <Esc>B <nop>
inoremap <Esc>C <nop>
inoremap <Esc>D <nop>

" splits
nnoremap <leader>q :enew\|bd<CR>

" using escape sequences, aka alt
"noremap <esc>mu <C-w>k
"noremap <esc>md <C-w>j
"noremap <esc>ml <C-w>h
"noremap <esc>mr <C-w>l
"inoremap <esc>mu <esc><C-w>k
"inoremap <esc>md <esc><C-w>j
"inoremap <esc>ml <esc><C-w>h
"inoremap <esc>mr <esc><C-w>l

let g:tmux_navigator_no_mappings = 1

" coordinated vim & tmux pane/split navigation
" vim-way: with alt-arrow
nnoremap <silent> <esc>mu :TmuxNavigateUp<cr>
nnoremap <silent> <esc>md :TmuxNavigateDown<cr>
nnoremap <silent> <esc>ml :TmuxNavigateLeft<cr>
nnoremap <silent> <esc>mr :TmuxNavigateRight<cr>
inoremap <silent> <esc>mu <esc>:TmuxNavigateUp<cr>
inoremap <silent> <esc>md <esc>:TmuxNavigateDown<cr>
inoremap <silent> <esc>ml <esc>:TmuxNavigateLeft<cr>
inoremap <silent> <esc>mr <esc>:TmuxNavigateRight<cr>
" tmux-way: with `-arrow
"nnoremap <silent> `<up> :TmuxNavigateUp<cr>
"nnoremap <silent> `<down> :TmuxNavigateDown<cr>
"nnoremap <silent> `<left> :TmuxNavigateLeft<cr>
"nnoremap <silent> `<right> :TmuxNavigateRight<cr>
"inoremap <silent> `<up>    <esc>:TmuxNavigateUp<cr>
"inoremap <silent> `<down>  <esc>:TmuxNavigateDown<cr>
"inoremap <silent> `<left>  <esc>:TmuxNavigateLeft<cr>
"inoremap <silent> `<right> <esc>:TmuxNavigateRight<cr>

" more advanced splits
" window
nnoremap <leader>sw<left>  :topleft  vnew<CR>
nnoremap <leader>sw<right> :botright vnew<CR>
nnoremap <leader>sw<up>    :topleft  new<CR>
nnoremap <leader>sw<down>  :botright new<CR>
" buffer
nnoremap <leader>s<left>   :leftabove  vnew<CR>
nnoremap <leader>s<right>  :rightbelow vnew<CR>
nnoremap <leader>s<up>     :leftabove  new<CR>
nnoremap <leader>s<down>   :rightbelow new<CR>

" resize splits
nnoremap <c-right> 5<c-w>>
nnoremap <c-left> 5<c-w><
nnoremap <c-up> 5<c-w>+
nnoremap <c-down> 5<c-w>-
" stupid terminal key ququence for this
noremap <esc>cr 5<c-w>>
noremap <esc>cl 5<c-w><
noremap <esc>cu 5<c-w>+
noremap <esc>cd 5<c-w>-
inoremap <esc>cr <esc>5<c-w>>a
inoremap <esc>cl <esc>5<c-w><a
inoremap <esc>cu <esc>5<c-w>+a
inoremap <esc>cd <esc>5<c-w>-a

" mapping enter and shift enter to newline without insert mode
nnoremap <S-CR> O<Esc>
nnoremap <CR> o<Esc>
autocmd CmdwinEnter * unmap <buffer> <CR>

" paste mode
nnoremap <C-p> :set invpaste paste?<CR>

" scroll viewport faster
nnoremap <C-e> 7<C-e>
nnoremap <C-y> 7<C-y>

" statusline
set laststatus=2
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

" visual indent
vnoremap > >gv
vnoremap < <gv

" beg / end of line, easier mappings
noremap H ^
noremap L $

"escape is hard to reach so map kj to <ESC>
inoremap kj <Esc>l

" scroll up and down faster
noremap K 5k
noremap J 5j
noremap <C-j> J


" sudo write
cnoremap w!! w !sudo tee % >/dev/null

" keep search matches in the middle of the window
nnoremap n nzzzv
nnoremap N Nzzzv

" disable ex-mode and let Q be @q
nnoremap Q @q


" ==============================
"           FILETYPES
" ==============================

" extension mappings
au BufNewFile,BufRead *.cljs setfiletype clojure
au BufNewFile,BufRead *.wisp setfiletype clojure
au BufNewFile,BufRead *.md setlocal ft=markdown
au BufNewFile,BufRead *.less setfiletype css

" ruby
au BufNewFile,BufRead *.ru setfiletype ruby
autocmd Filetype ruby setlocal ts=2 sw=2 expandtab

" markdown
autocmd Filetype markdown setlocal foldmethod=manual
let g:markdown_fenced_languages = [
            \   'sh',
            \   'ruby',
            \   'python',
            \   'c',
            \   'javascript',
            \   'objc',
            \   'java'
            \ ]


" ==============================
"            PLUGINS
" ==============================


" source powerline, which is not a pathogen plugin
set rtp+=/usr/local/lib/python2.7/site-packages/powerline/bindings/vim

" autoreload buffers
let autoreadargs={'autoread':1,'quiet':1}
au VimEnter * execute WatchForChanges("*",autoreadargs)

" ctrl-p
let g:ctrlp_map = '<leader>p'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 2
let g:ctrlp_prompt_mappings = {
            \ 'PrtClearCache()':      ['<C-r>'],
            \ 'ToggleRegex()':        ['<esc>r'],
            \ }
let g:ctrlp_arg_map = 1
let g:ctrlp_open_new_file = 'r'
let g:ctrlp_user_command = ['.git/', 'git --git-dir=%s/.git ls-files -oc --exclude-standard']
nnoremap <leader>b :CtrlPBuffer<CR>

" you complete me
let g:ycm_add_preview_to_completeopt = 0
let g:ycm_confirm_extra_conf = 0

" you complete me + utilsnips integration
if filereadable($HOME . "/.vim/bundle/you-complete-me/third_party/ycmd/ycm_core.so")
    function! g:UltiSnips_Complete()
        call UltiSnips_ExpandSnippet()
        if g:ulti_expand_res == 0
            if pumvisible()
                return "\<C-n>"
            else
                call UltiSnips_JumpForwards()
                if g:ulti_jump_forwards_res == 0
                    return "\<TAB>"
                endif
            endif
        endif
        return ""
    endfunction

    au BufEnter * exec "inoremap <silent> " . g:UltiSnipsExpandTrigger . " <C-R>=g:UltiSnips_Complete()<cr>"
    let g:UltiSnipsExpandTrigger="<leader><tab>"
    let g:UltiSnipsJumpForwardTrigger="<tab>"
endif

" easy-align
vnoremap <leader>a :LiveEasyAlign<cr>
nnoremap <leader>a vip:LiveEasyAlign<cr>

" ack
nnoremap <leader>/ :Ack!<space>
let g:ackprg = "ack-git-ls-files"
"let g:ack_use_dispatch = 1
let g:ack_mappings = { "<CR>": "<CR>zz" }
let g:ack_default_options =
            \ " -s -H --nocolor --nogroup --column --smart-case"

" syntastic
let g:syntastic_objc_checkers = ['ycm']
let g:syntastic_c_checkers = ['ycm']
let g:syntastic_cpp_checkers = ['ycm']
let g:syntastic_error_symbol = '✗'
let g:syntastic_warning_symbol = '!'
let g:syntastic_quiet_messages = {'level': 'warnings'}
let g:syntastic_aggregate_errors = 1
let g:syntastic_ruby_checkers = ['mri', 'rubocop']

" tagbar
nnoremap <leader>t :TagbarToggle<CR>

" json
autocmd InsertEnter *.json setlocal conceallevel=0
autocmd InsertLeave *.json setlocal conceallevel=2

" pencil
let g:pencil#wrapModeDefault = 'hard'   " or 'soft'

augroup pencil
  autocmd!
  autocmd FileType markdown,mkd,md call pencil#init()
  autocmd FileType textile call pencil#init()
  autocmd FileType text call pencil#init()
augroup END

" lexical
augroup lexical
  autocmd!
  autocmd FileType markdown call lexical#init()
  autocmd FileType textile call lexical#init()
  autocmd FileType text call lexical#init()
augroup END

" smart quotes
augroup textobj_quote
  autocmd!
  autocmd FileType markdown call textobj#quote#init()
  autocmd FileType textile call textobj#quote#init()
  autocmd FileType text call textobj#quote#init({'educate': 0})
augroup END

" sentence selection
augroup textobj_sentence
  autocmd!
  autocmd FileType markdown call textobj#sentence#init()
  autocmd FileType textile call textobj#sentence#init()
augroup END


" ==============================
" =        END OF VIMRC        =
" ==============================
