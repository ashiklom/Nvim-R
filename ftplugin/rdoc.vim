" Vim filetype plugin file
" Language: R Documentation (generated by the Nvim-R)
" Maintainer: Jakson Alves de Aquino <jalvesaq@gmail.com>


" Only do this when not yet done for this buffer
if exists("b:did_rdoc_ftplugin") || !has("nvim")
    finish
endif

" Don't load another plugin for this buffer
let b:did_rdoc_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" Source scripts common to R, Rnoweb, Rhelp and rdoc files:
runtime ftplugin/R/common_global.vim

" Some buffer variables common to R, Rnoweb, Rhelp and rdoc file need be
" defined after the global ones:
runtime ftplugin/R/common_buffer.vim

setlocal iskeyword=@,48-57,_,.

" Prepare R documentation output to be displayed by Vim
function! FixRdoc()
    let lnr = line("$")
    for ii in range(1, lnr)
        call setline(ii, substitute(getline(ii), "_\010", "", "g"))
    endfor

    " Mark the end of Examples
    let ii = search("^Examples:$", "nw")
    if ii
        if getline("$") !~ "^###$"
            let lnr = line("$") + 1
            call setline(lnr, '###')
        endif
    endif

    " Add a tab character at the end of the Arguments section to mark its end.
    let ii = search("^Arguments:$", "nw")
    if ii
        " A space after 'Arguments:' is necessary for correct syntax highlight
        " of the first argument
        call setline(ii, "Arguments: ")
        let doclength = line("$")
        let ii += 2
        let lin = getline(ii)
        while lin !~ "^[A-Z].*:$" && ii < doclength
            let ii += 1
            let lin = getline(ii)
        endwhile
        if ii < doclength
            let ii -= 1
            if getline(ii) =~ "^$"
                call setline(ii, "\t")
            endif
        endif
    endif

    " Add a tab character at the end of the Usage section to mark its end.
    let ii = search("^Usage:$", "nw")
    if ii
        let doclength = line("$")
        let ii += 2
        let lin = getline(ii)
        while lin !~ "^[A-Z].*:" && ii < doclength
            let ii += 1
            let lin = getline(ii)
        endwhile
        if ii < doclength
            let ii -= 1
            if getline(ii) =~ "^ *$"
                call setline(ii, "\t")
            endif
        endif
    endif

    normal! gg

    " Clear undo history
    let old_undolevels = &undolevels
    set undolevels=-1
    exe "normal a \<BS>\<Esc>"
    let &undolevels = old_undolevels
    unlet old_undolevels
endfunction

function! RdocIsInRCode(vrb)
    let exline = search("^Examples:$", "bncW")
    if exline > 0 && line(".") > exline
        return 1
    else
        if a:vrb
            call RWarningMsg('Not in the "Examples" section.')
        endif
        return 0
    endif
endfunction

let b:IsInRCode = function("RdocIsInRCode")
let b:SourceLines = function("RSourceLines")

"==========================================================================
" Key bindings and menu items

call RCreateSendMaps()
call RControlMaps()

" Menu R
if has("gui_running")
    runtime ftplugin/R/gui_running.vim
    call MakeRMenu()
endif

call RSourceOtherScripts()

function! RDocExSection()
    let ii = search("^Examples:$", "nW")
    if ii == 0
        call RWarningMsg("No example section below.")
        return
    else
        call cursor(ii+1, 1)
    endif
endfunction

nmap <buffer><silent> ge :call RDocExSection()<CR>
nmap <buffer><silent> q :q<CR>

setlocal bufhidden=wipe
setlocal noswapfile
set buftype=nofile
autocmd VimResized <buffer> let g:R_newsize = 1
call FixRdoc()
autocmd FileType rdoc call FixRdoc()

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=4
