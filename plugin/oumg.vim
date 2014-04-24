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
"	auto gen outline?
"	open source? (make configurable: prefix, finding path, filename pattern, etc)
"
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
    for root in ["$MY_DCC/A_NOTE", "$MY_DCO/A_NOTE", "$MY_FCS/oumisc/oumisc-git"]
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

function! oumg#mg(count)
	let def_str = expand('<cWORD>')
	let def_list = split(def_str, "@")

	" Step 1: find out Title and File
	if len(def_list) == 2						
		let title_str = substitute(def_list[0], '^\~', '', '')
		let file_path = oumg#find_candidate(def_list[1])
	elseif match(def_str, '^@') >= 0						" only File
		let title_str = ""
		let file_path = oumg#find_candidate(substitute(def_str, '^@', '', ''))
	elseif match(def_str, '^\~') >= 0						" only Title
		let title_str = substitute(def_list[0], '^\~', '', '')
		let file_path = expand("%")
	else										" need further detect
		let file_candidate = oumg#find_candidate(def_str)
		if filereadable(file_candidate)						" only File
			let title_str = ""
			let file_path = file_candidate
		else									" only Title
			let title_str = def_str
			let file_path = expand("%")
		endif
	endif

	" Step 2: perform the jumping
	if file_path == expand("%")
		"let @/ = (len(title_str) == 0) ? "" : "^\t*" . title_str		" works, but unnecessary since messup the search history 
		"normal n
		"normal zt
		
		if search("^\t*" . title_str, 'cW') > 0
			normal zt
		else
			echo "ERROR: oumg#mg(), can not jump to title:" . title_str
		endif
	else
		execute 'silent edit +/^\\t*' . title_str . ' ' . file_path
		"execute 'let @/="\t*' . title_str . '"'				" works, but unnecessary since messup the search history
		normal zt
	endif
endfunction

nnoremap <silent> mg :<C-U>call oumg#mg(v:count)<CR>
