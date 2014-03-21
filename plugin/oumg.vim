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
" ##Lang_Pickling_Unpickling
" ##Lang_Pickling_Unpickling@@python
" ##Lang_Pickling_Unpickling@@$MY_FCS/python/A/A_NOTE_python.txt

if exists("g:loaded_oumg") || &cp || v:version < 700
    finish
endif
let g:loaded_oumg = 1

" ~/amp/2014-03/smartgf.vim
" APPENDIX_Scripting_Function@$MY_DOC/DCC/Tool_Vi_Vim/A_NOTE_Vim.txt

function! oumg#mg(count)
    let def_str = expand('<cWORD>')

    " xxx@@yyy format: tag in some file
    let def_list = split(def_str, "@@")
    if(len(def_list) == 2)

	" try the converstion of xxx=$MY_FCS/xxx/A_NOTE_xxx.txt
        let fcs_file = '$MY_FCS/' . def_list[1] . '/A/A_NOTE_' . def_list[1] . '.txt'
	if(filereadable(expand(fcs_file)))
            execute 'silent edit +/^' . def_list[0] . ' ' . fcs_file
            return
        endif
        
        execute 'silent edit +/^' . def_list[0] . ' ' . def_list[1] 
        return
    endif

    " ##xxx format: tag in current file
    if match(def_str, "^##.*") >= 0
        let @/ = '^' . def_str
	normal n
        return
    endif

    " in the end, just try gf on it
    let filename = expand(expand('<cfile>'))
    execute 'edit ' . filename
endfunction

nnoremap <silent> mg     :<C-U>call oumg#mg(v:count)<CR>
