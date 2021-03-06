
" Only source this once
if exists("*RmFromRLibList")
    if len(s:lists_to_load) > 0
        for s:lib in s:lists_to_load
            call SourceRFunList(s:lib)
        endfor
        unlet s:lib
    endif
    finish
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set global variables when this script is called for the first time
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Users may define the value of g:R_start_libs
if !exists("g:R_start_libs")
    let g:R_start_libs = "base,stats,graphics,grDevices,utils,methods"
endif

let s:lists_to_load = split(g:R_start_libs, ",")
let s:new_libs = 0
let g:rplugin_debug_lists = []
let g:rplugin_loaded_libs = []
let s:Rhelp_list = []
let g:rplugin_omni_lines = []

" syntax/r.vim may have being called before ftplugin/r.vim
if !exists("g:rplugin_compldir")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/setcompldir.vim"
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function for highlighting rFunction
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Must be run for each buffer
function SourceRFunList(lib)
    if isdirectory(g:rplugin_compldir)
        let fnf = split(globpath(g:rplugin_compldir, 'fun_' . a:lib . '_*'), "\n")
        if len(fnf) == 1 && (!exists("g:R_hi_fun") || g:R_hi_fun != 0)
            " Highlight R functions
            if !exists("g:R_hi_fun_paren") || g:R_hi_fun_paren == 0
                exe "source " . substitute(fnf[0], ' ', '\\ ', 'g')
            else
                let lines = readfile(fnf[0])
                for line in lines
                    let newline = substitute(line, "\\.", "\\\\.", "g")
                    if substitute(line, "syn keyword rFunction ", "", "") =~ "[ ']"
                        let newline = substitute(newline, "keyword rFunction ", "match rSpaceFun /`\\\\zs", "")
                        exe newline . "\\ze`\\s*(/ contained"
                    else
                        let newline = substitute(newline, "keyword rFunction ", "match rFunction /\\\\<", "")
                        exe newline . "\\s*\\ze(/"
                    endif
                endfor
            endif
        elseif len(fnf) == 0
            let g:rplugin_debug_lists += ['Function list for "' . a:lib . '" not found.']
        elseif len(fnf) > 1
            let g:rplugin_debug_lists += ['There is more than one function list for "' . a:lib . '".']
            for obl in fnf
                let g:rplugin_debug_lists += [obl]
            endfor
        endif
    endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Omnicompletion functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function RLisObjs(arglead, cmdline, curpos)
    let lob = []
    let rkeyword = '^' . a:arglead
    for xx in s:Rhelp_list
        if xx =~ rkeyword
            call add(lob, xx)
        endif
    endfor
    return lob
endfunction

function RmFromRLibList(lib)
    for idx in range(len(g:rplugin_loaded_libs))
        if g:rplugin_loaded_libs[idx] == a:lib
            call remove(g:rplugin_loaded_libs, idx)
            break
        endif
    endfor
    for idx in range(len(s:lists_to_load))
        if s:lists_to_load[idx] == a:lib
            call remove(s:lists_to_load, idx)
            break
        endif
    endfor
endfunction

function AddToRLibList(lib)
    if isdirectory(g:rplugin_compldir)
        let omf = split(globpath(g:rplugin_compldir, 'omnils_' . a:lib . '_*'), "\n")
        if len(omf) == 1
            let g:rplugin_loaded_libs += [a:lib]

            " List of objects for omni completion
            let olist = readfile(omf[0])

            " Library setwidth has no functions
            if len(olist) == 0 || (len(olist) == 1 && len(olist[0]) < 3)
                return
            endif

            let g:rplugin_omni_lines += olist

            " List of objects for :Rhelp completion
            for xx in olist
                let xxx = split(xx, "\x06")
                if len(xxx) > 0 && xxx[0] !~ '\$'
                    call add(s:Rhelp_list, xxx[0])
                endif
            endfor
        elseif len(omf) == 0
            let g:rplugin_debug_lists += ['Omnils list for "' . a:lib . '" not found.']
            call RmFromRLibList(a:lib)
            return
        elseif len(omf) > 1
            let g:rplugin_debug_lists += ['There is more than one omnils and function list for "' . a:lib . '".']
            for obl in omf
                let g:rplugin_debug_lists += [obl]
            endfor
            call RmFromRLibList(a:lib)
            return
        endif
    endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function called by nvimcom
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function FillRLibList()
    " Update the list of objects for omnicompletion
    if filereadable(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)
        let s:lists_to_load = readfile(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)
        for lib in s:lists_to_load
            let isloaded = 0
            for olib in g:rplugin_loaded_libs
                if lib == olib
                    let isloaded = 1
                    break
                endif
            endfor
            if isloaded == 0
                call AddToRLibList(lib)
            endif
        endfor
        call delete(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)
    endif
    " Now we need to update the syntax in all R files. There should be a
    " better solution than setting a flag to let other buffers know that they
    " also need to update the syntax on CursorMoved event:
    " https://github.com/neovim/neovim/issues/901
    if !exists("g:R_hi_fun") || g:R_hi_fun != 0
        let s:new_libs = len(g:rplugin_loaded_libs)
        silent exe 'set syntax=' . &syntax
        redraw
    endif
    let b:rplugin_new_libs = s:new_libs
    call CheckRGlobalEnv()
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Update the buffer syntax if necessary
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function RCheckLibList()
    if b:rplugin_new_libs == s:new_libs
        return
    endif
    if !exists("g:R_hi_fun") || g:R_hi_fun != 0
        silent exe 'set syntax=' . &syntax
        redraw
    endif
    let b:rplugin_new_libs = s:new_libs
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Source the Syntax scripts for the first time and Load omnilists
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

for s:lib in s:lists_to_load
    call SourceRFunList(s:lib)
    call AddToRLibList(s:lib)
endfor

unlet s:lib
