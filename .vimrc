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

" enable truecolor
let $NVIM_TUI_ENABLE_TRUE_COLOR=1

" go-lang (this must come before syntax on, for some reason...)
set rtp+=$GOROOT/misc/vim

" enable file types and syntax highlighing
syntax on
filetype plugin indent on

" color scheme
let g:solarized_termcolors=256
if $ITERM_PROFILE == 'light'
  set background=light
else
  set background=dark
endif
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
set tabstop=2
set shiftwidth=2
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
set nohlsearch

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
augroup OverLength
  autocmd!
  au BufEnter             * call matchadd('OverLength', '\%81v.\+', -1)
  au InsertEnter          * highlight clear OverLength
  au InsertLeave          * highlight OverLength ctermbg=233 ctermfg=124
augroup END

" trailing whitespace highlight
highlight ExtraWhitespace ctermbg=238
augroup ExtraWhitespace
  autocmd!
  au BufEnter             * call matchadd('ExtraWhitespace', '\s\+\%#\@<!$', -1)
  au InsertEnter          * highlight clear ExtraWhitespace
  au InsertLeave          * highlight ExtraWhitespace ctermbg=238
augroup END

" backspace bullshit
set backspace=indent,eol,start

" mouse
if has('mouse')
    set mouse=a
endif

" use system clipboard
set clipboard=unnamed

" map . in visual mode to repeat on each line
vnoremap . :normal .<CR>

" execute local .vimrcs, disallowing certain commands
set exrc
set secure

" better fold display
fu! CustomFoldText()
    "get first non-blank line
    let fs = v:foldstart
    while getline(fs) =~ '^\s*$' | let fs = nextnonblank(fs + 1)
    endwhile
    if fs > v:foldend
        let line = getline(v:foldstart)
    else
        let line = substitute(getline(fs), '\t', repeat(' ', &tabstop), 'g')
    endif

    let w               = winwidth(0) - &foldcolumn - (&number ? 8 : 0)
    let foldSize        = 1 + v:foldend - v:foldstart
    let foldSizeStr     = " " . foldSize . " lines "
    let foldLevelStr    = repeat("+--", v:foldlevel)
    let lineCount       = line("$")
    let foldPercentage  = printf("[%.1f", (foldSize*1.0)/lineCount*100) . "%] "
    let expansionString = repeat(".", w - strwidth(foldSizeStr.line.foldLevelStr.foldPercentage))
    return line . expansionString . foldSizeStr . foldPercentage . foldLevelStr
endf
set foldtext=CustomFoldText()

" ctags
set tags=.git/tags

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
nnoremap <expr> gp '`[' . strpart(getregtype(), 0, 1) . '`]'

" disable arrow keys
nnoremap <up>    <nop>
nnoremap <down>  <nop>
nnoremap <left>  <nop>
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
" tmux-way: with `-arrow
nnoremap <silent> `<up> :TmuxNavigateUp<cr>
nnoremap <silent> `<down> :TmuxNavigateDown<cr>
nnoremap <silent> `<left> :TmuxNavigateLeft<cr>
nnoremap <silent> `<right> :TmuxNavigateRight<cr>
inoremap <silent> `<up>    <esc>:TmuxNavigateUp<cr>
inoremap <silent> `<down>  <esc>:TmuxNavigateDown<cr>
inoremap <silent> `<left>  <esc>:TmuxNavigateLeft<cr>
inoremap <silent> `<right> <esc>:TmuxNavigateRight<cr>
if has('nvim')
  tnoremap <silent> `<up>    <C-\><C-n>:TmuxNavigateUp<cr>
  tnoremap <silent> `<down>  <C-\><C-n>:TmuxNavigateDown<cr>
  tnoremap <silent> `<left>  <C-\><C-n>:TmuxNavigateLeft<cr>
  tnoremap <silent> `<right> <C-\><C-n>:TmuxNavigateRight<cr>
endif

" more advanced splits
" window
nnoremap <leader>sw<left>  :topleft    vnew<CR>
nnoremap <leader>sw<right> :botright   vnew<CR>
nnoremap <leader>sw<up>    :topleft    new<CR>
nnoremap <leader>sw<down>  :botright   new<CR>
" buffer
nnoremap <leader>s<left>   :leftabove  vnew<CR>
nnoremap <leader>s<right>  :rightbelow vnew<CR>
nnoremap <leader>s<up>     :leftabove  new<CR>
nnoremap <leader>s<down>   :rightbelow new<CR>

" resize splits
nnoremap <c-right> 5<c-w>>
nnoremap <c-left>  5<c-w><
nnoremap <c-up>    5<c-w>+
nnoremap <c-down>  5<c-w>-
" stupid terminal key ququence for this
noremap  <esc>cr   5<c-w>>
noremap  <esc>cl   5<c-w><
noremap  <esc>cu   5<c-w>+
noremap  <esc>cd   5<c-w>-
inoremap <esc>cr   <esc>5<c-w>>a
inoremap <esc>cl   <esc>5<c-w><a
inoremap <esc>cu   <esc>5<c-w>+a
inoremap <esc>cd   <esc>5<c-w>-a

" mapping enter and shift enter to newline without insert mode
nnoremap <S-CR> O<Esc>
nnoremap <CR> o<Esc>
autocmd CmdwinEnter * unmap <buffer> <CR>

" nvim terminal mappings
if has('nvim')
  tnoremap <leader><esc> <C-\><C-n>
  autocmd TermOpen * nnoremap <buffer> <CR> a
endif

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

" \c compiles coffeescript
autocmd FileType coffeescript map <buffer> <leader>c :CoffeeCompile<CR>


" ==============================
"           FILETYPES
" ==============================

augroup Filetypes
  autocmd!
augroup END

" extension mappings
augroup Filetypes
  au BufNewFile,BufRead *.cljs setfiletype clojure
  au BufNewFile,BufRead *.wisp setfiletype clojure
  au BufNewFile,BufRead *.md   setlocal    ft=markdown
  au BufNewFile,BufRead *.less setfiletype css
augroup END

" ruby
augroup Filetypes
  au BufNewFile,BufRead *.ru setfiletype ruby
augroup END

" set 4-space indented languages
augroup Filetypes
  autocmd Filetype php      setlocal ts=4 sw=4 expandtab
  autocmd Filetype c        setlocal ts=4 sw=4 expandtab
  autocmd Filetype sh       setlocal ts=4 sw=4 expandtab
  autocmd Filetype markdown setlocal ts=4 sw=4 expandtab
augroup END

" markdown
augroup Filetypes
  autocmd Filetype markdown setlocal foldmethod=manual
  autocmd Filetype markdown setlocal wrap
  autocmd Filetype markdown setlocal linebreak
augroup END
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


" airline
let g:airline_powerline_fonts = 1
let g:airline_theme='powerlineish'

" autoreload buffers
let autoreadargs={'autoread':1,'quiet':1}
augroup WatchForChanges
  autocmd!
  au VimEnter * execute WatchForChanges("*",autoreadargs)
augroup END

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
let g:ctrlp_dotfiles = 1
nnoremap <leader>b :CtrlPBuffer<CR>
nnoremap <leader>r :CtrlPTag<CR>
nnoremap <leader>t :CtrlPBufTag<CR>
nnoremap <leader>T :CtrlPBufTagAll<CR>

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

" ycm + typescript autocomplete
if !exists("g:ycm_semantic_triggers")
  let g:ycm_semantic_triggers = {}
endif
let g:ycm_semantic_triggers['typescript'] = ['.']

" easy-align
vnoremap <leader>a :LiveEasyAlign<cr>
nmap <leader>a vii:LiveEasyAlign<cr>

" ack
nnoremap <leader>/ :Ack!<space>
let g:ackprg = "ack-git-ls-files"
"let g:ack_use_dispatch = 1
let g:ack_mappings = { "<CR>": "<CR>zz" }
let g:ack_default_options =
            \ " -s -H --nocolor --nogroup --column --smart-case"

" syntastic
let g:syntastic_objc_checkers    = ['ycm']
let g:syntastic_c_checkers       = ['ycm']
let g:syntastic_cpp_checkers     = ['ycm']
let g:syntastic_error_symbol     = '✗'
let g:syntastic_warning_symbol   = '!'
let g:syntastic_quiet_messages   = {'type': 'style'}
let g:syntastic_aggregate_errors = 1
let g:syntastic_check_on_open    = 1
let g:syntastic_ruby_checkers    = ['mri']
let g:syntastic_always_populate_loc_list = 1
let g:tsuquyomi_disable_quickfix = 1
let g:syntastic_typescript_checkers = ['tsuquyomi']
command! Syn call CustomSyn()
function! CustomSyn()
  let g:syntastic_ruby_checkers  = ['mri']
  let g:syntastic_quiet_messages = {'type': 'style'}
  :SyntasticCheck
endfunction
command! SynS call CustomSynS()
function! CustomSynS()
  let g:syntastic_ruby_checkers  = ['mri', 'rubocop']
  let g:syntastic_quiet_messages = {}
  :SyntasticCheck
endfunction
" unfortunately CJSX files are considered coffee and break syntastic
au BufEnter *.cjsx let b:syntastic_skip_checks = 1

" tagbar
nnoremap <leader>R :TagbarToggle<CR>

" json
autocmd InsertEnter *.json setlocal conceallevel=0
autocmd InsertLeave *.json setlocal conceallevel=2

" lexical
augroup lexical
  autocmd!
  autocmd FileType markdown call lexical#init()
  autocmd FileType textile  call lexical#init()
  autocmd FileType text     call lexical#init()
augroup END

" smart quotes
augroup textobj_quote
  autocmd!
  autocmd FileType markdown call textobj#quote#init()
  autocmd FileType textile  call textobj#quote#init()
  autocmd FileType text     call textobj#quote#init({'educate': 0})
augroup END

" sentence selection
augroup textobj_sentence
  autocmd!
  autocmd FileType markdown call textobj#sentence#init()
  autocmd FileType textile  call textobj#sentence#init()
augroup END

" indent-guide
let g:indent_guides_auto_colors = 0
hi clear IndentGuidesOdd
hi IndentGuidesEven ctermbg=235

" NOTE: temporarily disabled until fix:
" https://github.com/nathanaelkane/vim-indent-guides/issues/80
"autocmd FileType coffeescript :IndentGuidesEnable
"autocmd FileType sass         :IndentGuidesEnable
"autocmd FileType haml         :IndentGuidesEnable
"autocmd FileType python       :IndentGuidesEnable

" lexima
"call lexima#add_rule({'char': '<', 'input_after': '>'})
"call lexima#add_rule({'char': '>', 'at': '\%#>', 'leave': 1})
"call lexima#add_rule({'char': '<BS>', 'at': '\<\%#\>', 'delete': 1})

" closetag
autocmd BufEnter *.jsx,*.tsx let b:unaryTagsStack=''
let g:closetag_filenames = '*.html,*.jsx,*.tsx'

" ==============================
" =        END OF VIMRC        =
" ==============================
