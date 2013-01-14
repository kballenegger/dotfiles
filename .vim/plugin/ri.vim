" Edits by Kenneth Ballenegger below to only load when available.
" Vim script to integrate ri Ruby documentation lookup with Vim
" Maintainer:	Daniel Choi <dhchoi@gmail.com>
" License: MIT License (c) 2011 Daniel Choi

let s:ri_vim_path = system("gem contents ri_vim | grep 'ri\\.vim$'")
if !exists("s:ri_vim_path")
  finish
endif

if exists("g:RIVimLoaded") || &cp || version < 700
  finish
endif
let g:ri_vim_tool = 'ri_vim '
exe "source " . s:ri_vim_path

