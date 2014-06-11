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
" Pattern:
" ~<Title>@<File>	" '~' is optional, File could have relative path or file extension (default is '.txt')
"
" Test:
" python
" python2
" @python
" @py-lang/str.py
" @$MY_DCC/python/python.txt
" ~Lang_Pickling_Unpickling
" ~Lang_Pickling_Unpickling@python
" ~Lang_Pickling_Unpickling2@python2
" ~Lang_Pickling_Unpickling@$MY_DCC/python/python.txt
" $MY_DCC/python/python.txt
"
" TODO:
"	vim regex how to match non-Ascii: 
"		/[^\x00-\x7F]		# exclude "ASCII hex character range"
"		/[^\x00-\xFF]		# exclude "Extened ASCII hex character range"
"		\w			# Chinese will not match
"
"	Highlight
"		Title		OumnTitle			:syn match OumnTitle /^##.*/
"		File Ref	OumnLinkFile			# (source external file)
"		Title Ref	OumnLinkTitle			:syn match OumnLinkTitle /[xxx]/
"
"		File Path	note/xxx.txt, xxx/xxx.txt	# xxx.txt seems the simplest, dir name "note" makes it not so obvious to see but still not difficult to goto
"		Material Loc	<sub folder>

if exists("g:loaded_vim_oumg") || &cp || v:version < 700
	finish
endif
let g:loaded_vim_oumg = 1

function! oumg#find_candidate(str)
    " already a file path
    let file_candidate = expand(a:str)
    if(filereadable(file_candidate))
        return file_candidate
    endif

    " file in root paths 
    for root in ["$MY_DCC/note", "$MY_DCO/note", "$MY_DCD/project/note", "$MY_FCS/oumisc/oumisc-git"]
        let file_candidate = expand(root . '/' . a:str . '.txt')
        if(filereadable(file_candidate))
            return file_candidate
        endif
        let file_candidate = expand(root . '/' . a:str)
        if(filereadable(file_candidate))
            return file_candidate
        endif
    endfor

    return ""
endfunction

function! oumg#parse_file_title()
	let def_str = expand('<cWORD>')
	let def_list = split(def_str, "@")

	" 1st: title@file, formal format
	if len(def_list) == 2							
		return { "file" : oumg#find_candidate(def_list[1]), "title" : substitute(def_list[0], '^\~', '', '') }
	endif

	" 2nd: @file, only File
	if match(def_str, '^@') >= 0
		return { "file" : oumg#find_candidate(substitute(def_str, '^@', '', '')), "title" : "" }
	endif

	" 3rd: file, simple string, try File
	let file_candidate = oumg#find_candidate(def_str)
	if filereadable(file_candidate)
		return { "file" : file_candidate, "title" : "" }
	endif

	" 4th: special treatment for note collection
	let current_line = getline('.')
	if expand("$MY_ENV/zgen/collection/all_content.txt") == expand("%:p") && search("^@", 'bW') > 0
		let file = substitute(getline('.'), "^@", '', '')
		" use fake 'title' to get correct jump 
		let title_list = matchlist(current_line, '^\t*\([^[:blank:]]*\).*')
		return { "file" : file, "title" : title_list[1] }
	endif

	" 5th: ~title, only Title
	if match(def_str, '^\~') >= 0						
		return { "file" : expand("%"), "title" : substitute(def_list[0], '^\~', '', '') }
	endif

	" 6th: title, simple string, try Tile
	return { "file" : expand("%"), "title" : def_str }
endfunction

function! oumg#jump_file_title(location)
	if a:location["file"] == expand("%")
		if search("^\t*" . a:location["title"], 'cW') <= 0
			echo "ERROR: oumg#mg(), can not jump to title:" . a:location["title"]
		endif
		normal zz
	else
		execute 'silent edit +/^\\t*' . a:location["title"] . ' ' . a:location["file"]
		normal zz
	endif
endfunction

function! oumg#mg(count)
	let location = oumg#parse_file_title()
	call oumg#jump_file_title(location)
endfunction

nnoremap <silent> mg :<C-U>call oumg#mg(v:count)<CR>
