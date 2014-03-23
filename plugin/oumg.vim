" oumg.vim - a personal goto definition plugin
" Maintainer:   ouyzhu
" Version:      0.1

" Installation:
" Place in either ~/.vim/plugin/oumg.vim (to load at start up) or
" ~/.vim/autoload/oumg.vim (to load automatically as needed).
"
" License:
" Copyright (c) Ouyzhu.  Distributed under the same terms as Vim itself.
" See :help license
"
" Usage:
" type "mg" on the text you want to jump
"
" Test:
" python
" python2
" @@python
" @@$MY_DCC/python/A_NOTE_python.txt
" ##Lang_Pickling_Unpickling
" ##Lang_Pickling_Unpickling@@python
" ##Lang_Pickling_Unpickling@@python2
" ##Lang_Pickling_Unpickling@@$MY_DCC/python/A_NOTE_python.txt
" $MY_DCC/python/A_NOTE_python.txt

if exists("g:loaded_oumg") || &cp || v:version < 700
    finish
endif
let g:loaded_oumg = 1

function! oumg#find_candidate(str)
    " already a file path
    let file_candidate = expand(a:str)
    if(filereadable(file_candidate))
        return file_candidate
    endif

    " file in root paths
    for root in ["$MY_DCC/", "$MY_DCO/"]
        let file_candidate = expand(root . a:str . '/A_NOTE_' . a:str . '.txt')
        if(filereadable(file_candidate))
            return file_candidate
        endif
    endfor

    return ""
endfunction

function! oumg#mg(count)
    " find out file_path and search_str
    let def_str = expand('<cWORD>')
    let file_candidate = oumg#find_candidate(def_str)
    if match(def_str, '^@@.*') >= 0
        " @@xxx format: just the file name prefixed with @@
        let def_list = split(def_str, "@@")
        let file_path = expand(def_list[0])
	let search_str = ""
    elseif match(def_str, '@@') >= 0
        " xxx@@yyy format: tag in the file
        let def_list = split(def_str, "@@")
        let file_path = expand(def_list[1])
	let search_str = def_list[0]
    elseif match(def_str, '^##.*') >= 0
        " seems the oumg#find_candidate('##xxx') will return current file
	" name, why? so we have to treat it this way here
        let file_path = expand("%")
	let search_str = def_str
    elseif filereadable(file_candidate)
        " xxx format: just the file name
        let file_path = file_candidate
	let search_str = ""
    else
        " otherwise try it as a search_str
        let file_path = expand("%")
	let search_str = def_str
    endif

    " find out file_candidate and add prefix for search_str
    let file_candidate = oumg#find_candidate(file_path)
    if len(search_str) == 0
        let search_str_real = ""
    else
        let search_str_real = '+/^' . search_str
    endif

    " perform the jumping
    if(file_candidate == expand("%"))
        let @/ = search_str_real
	normal n 
    elseif(filereadable(file_candidate))
        execute 'silent edit ' . search_str_real . ' ' . file_candidate
    else
        echo "ERROR: '" . file_candidate . "' NOT exist in any candidate path!"
    endif

    "echo "ERROR: Can NOT resolve as (" . def_str . ") or (" . def_list . ")"
    "let filename = expand(expand('<cfile>'))
    "execute 'edit ' . filename
endfunction

nnoremap <silent> mg     :<C-U>call oumg#mg(v:count)<CR>
