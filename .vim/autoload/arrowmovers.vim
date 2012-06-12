function! DelEmptyLineAbove()
    if line(".") == 1
        return
    endif
    let l:line = getline(line(".") - 1)
    if l:line =~ '^\s*$'
        let l:colsave = col(".")
        .-1d
        silent normal! <c-y>
        call cursor(line("."), l:colsave)
    endif
endfunction

function! AddEmptyLineAbove()
    let l:scrolloffsave = &amp;scrolloff
    " Avoid jerky scrolling with ^E at top of window
    set scrolloff=0
    call append(line(".") - 1, "")
    if winline() != winheight(0)
        silent normal! <c-e>
    endif
    let &amp;scrolloff = l:scrolloffsave
endfunction

function! DelEmptyLineBelow()
    if line(".") == line("$")
        return
    endif
    let l:line = getline(line(".") + 1)
    if l:line =~ '^\s*$'
        let l:colsave = col(".")
        .+1d
        ''
        call cursor(line("."), l:colsave)
    endif
endfunction

function! AddEmptyLineBelow()
    call append(line("."), "")
endfunction

" Arrow key remapping: Up/Dn = move line up/dn; Left/Right = indent/unindent
function! SetArrowKeysAsTextShifters()
    " normal mode
    nmap <silent><left><right> &gt;&gt;
    nnoremap <silent><up><esc>:call DelEmptyLineAbove()<cr>
    nnoremap <silent><down><esc>:call AddEmptyLineAbove()<cr>
    nnoremap <silent><c-up><esc>:call DelEmptyLineBelow()<cr>
    nnoremap <silent><c-down><esc>:call AddEmptyLineBelow()<cr>

    " visual mode
    vmap <silent><left><right> &gt;
    vnoremap <silent><up><esc>:call DelEmptyLineAbove()<cr>gv
    vnoremap <silent><down><esc>:call AddEmptyLineAbove()<cr>gv
    vnoremap <silent><c-up><esc>:call DelEmptyLineBelow()<cr>gv
    vnoremap <silent><c-down><esc>:call AddEmptyLineBelow()<cr>gv

    " insert mode
    imap <silent><left><c-d>
    imap <silent><right><c-t>
    inoremap <silent><up><esc>:call DelEmptyLineAbove()<cr>a
    inoremap <silent><down><esc>:call AddEmptyLineAbove()<cr>a
    inoremap <silent><c-up><esc>:call DelEmptyLineBelow()<cr>a
    inoremap <silent><c-down><esc>:call AddEmptyLineBelow()<cr>a

    " disable modified versions we are not using
    nnoremap  <s-up><nop>
    nnoremap  <s-down><nop>
    nnoremap  <s-left><nop>
    nnoremap  <s-right><nop>
    vnoremap  <s-up><nop>
    vnoremap  <s-down><nop>
    vnoremap  <s-left><nop>
    vnoremap  <s-right><nop>
    inoremap  <s-up><nop>
    inoremap  <s-down><nop>
    inoremap  <s-left><nop>
    inoremap  <s-right><nop>
endfunction

call SetArrowKeysAsTextShifters()

