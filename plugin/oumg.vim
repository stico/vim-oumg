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
" Developers:
" Basic usage is as follows:

if exists("g:loaded_oumg") || &cp || v:version < 700
    finish
endif
let g:loaded_oumg = 1

" ~/amp/2014-03/smartgf.vim
" APPENDIX_Scripting_Function@$MY_DOC/DCC/Tool_Vi_Vim/A_NOTE_Vim.txt

function! oumg#mg(count)
    let def_str = expand('<cWORD>')

    " xxx@yyy format
    let def_list = split(def_str, "@")
    if(len(def_list) == 2)
	" works
        "execute 'edit ' . def_list[1]
	"execute 'edit +/' . def_list[0] . ' ' . def_list[1] 
        "execute 'silent edit +/' . def_list[0] . ' ' . def_list[1] 

	" works, but sometimes need press a button
        "execute 'edit +/^' . def_list[0] . ' ' . def_list[1] 

        execute 'silent edit +/^' . def_list[0] . ' ' . def_list[1] 

	"Not work
        "execute 'edit ' . def_list[1] . ' +/' . def_list[0]
	return
    endif

    " in the end, try gf on it
    let filename = expand(expand('<cfile>'))
    execute 'edit ' . filename
endfunction

nnoremap <silent> mg     :<C-U>call oumg#mg(v:count)<CR>
