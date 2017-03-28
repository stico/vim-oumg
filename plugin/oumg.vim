" oumg.vim - a personal goto definition plugin
"
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
" 1) jump to definition: type "mg" (in normal mode) on text you want to jump
" 2) show doc outline: type "mo" (in normal mode)
"
" Note:
" this plugin will chnage some quickfix (qf) window behavior
" 1) <enter> will jump to target and close quickfix window
" 2) <esc> will close quickfix window without jump
"
" Pattern:
" ~<Title>@<File>	" '~' is optional, File could have relative path or file extension (default is '.txt')
"
" Sample:
" ../README.md		" relative path
" @../README.md		" relative path, with @
" 你好vimrc测试一下	" among Chinese
" @vimrc:		" heading/tailing special char, and with @
" (@vimrc)		" heading/tailing special char, inside bracket
" @~/.vimrc,		" heading/tailing special char, with ~tilde@bash
" (ss)vimrc)		" heading/tailing special char, ) in heading part
" @$MY_DCC/vim/vim.txt,	" heading/tailing special char, including env var
" @$HOME/.vimrc		" including env var
" python		" tag
" python21398		" not exist
"
" ~overview@http
" ~Lang_Pickling_Unpickling
" ~Lang_Pickling_Unpickling@python
" ~Lang_Pickling_Unpickling2@python2
" ~Lang_Pickling_Unpickling@$MY_DCC/python/python.txt
" overview@$MY_DCC/python/python.txt			" TODO: seems @ still NOT included in expand ('<cword>') after 'set iskeyword+=@'
"
" TODO_Highlight:
"Title		OumnTitle			:syn match OumnTitle /^##.*/
"File Ref	OumnLinkFile			# (source external file)
"Title Ref	OumnLinkTitle			:syn match OumnLinkTitle /[xxx]/
"File Path	note/xxx.txt, xxx/xxx.txt	# xxx.txt seems the simplest, dir name "note" makes it not so obvious to see but still not difficult to goto
"Material Loc	<sub folder>

" START: script starts here
if exists("g:loaded_vim_oumg") || &cp || v:version < 700
       finish
endif
let g:loaded_vim_oumg = 1
let g:oumg_temp_iskeyword_value=&iskeyword

" RETURN: readable file or empty string
function! oumg#find_file(str)
	let str_stripped = substitute(a:str, '^@', '', 'g')			" oumg#parse_file_title() did most strip, here only remove the leading ‘@' if exist
	let str_stripped = substitute(str_stripped, '[[:space:]]\+', ' ', 'g')	" merge multiple space into one for split
	let path_list = split(str_stripped, " ")

	" shortcut: check it is file in current dir
	if(len(path_list) == 1 && filereadable(expand(path_list[0])))
		return expand(path_list[0])
	endif
	
	" perform tag check against 1st arg
	let base_candidate = oumg#parse_tag(path_list[0])

	" shortcut: single item and is a file, use expand as need support env var
	if(len(path_list) == 1 && filereadable(expand(base_candidate)))
		return expand(base_candidate)
	endif

	" base should be a dir
	let base = isdirectory(base_candidate) ? base_candidate : getcwd()
	let path_list_real = isdirectory(base_candidate) ? path_list[1:] : path_list[0:]

	" safe check: base should NOT be / or $HOME
	let root_expanded = expand('/')
	let base_expanded = expand(base)
	let home_expanded = expand('$HOME')
	if ( base_expanded == home_expanded || base_expanded == root_expanded) 
		echo 'ERROR: base should NOT be $HOME (~/) or root (/)'
		return ""
	endif
	
	" create glob pattern
	let path_glob = '**'
	for item in path_list_real
		let path_glob = path_glob . '/*' . item . '*'
	endfor

	" just use the 1st readable file, seems already ignorecase
	let file_candidate_list = globpath(base, path_glob, 0, 1)	" 0 means NOT apply 'suffixes' and 'wildignore', 1 means return as list
	call sort(file_candidate_list, "Oumg_str_len_cmp")
	for file_candidate in file_candidate_list
		if filereadable(file_candidate)
			return file_candidate
		endif
	endfor

	" otherwise return empty string
	return ""
endfunction

function! Oumg_str_len_cmp(str1, str2)
	return strlen(a:str1) - strlen(a:str2)
endfunction

" RETURN: translated tag (file or dir), or itself
function! oumg#parse_tag(str)
	" try tag def files
	for tag_filename in ["$HOME/.myenv/conf/addi/tags", "$HOME/.myenv/zgen/tags_note"]
		for line in readfile(expand(tag_filename))

			if match(line, '^' . a:str . '=.*') < 0
				continue
			endif

			let path_candidate = expand(substitute(line, '[^=]\+=', '', ''))
			if(filereadable(path_candidate) || isdirectory(path_candidate))
				return path_candidate
			else
				echo 'ERROR: path candidate (=' . path_candidate . ') found, but FAILED to translate!'
			endif
		endfor
	endfor	

	" try file in pre-defined paths 
	for root in ["$MY_DCC/note", "$MY_DCO/note", "$MY_DCD/project/note", "$MY_FCS/oumisc/oumisc-git"]
	    let path_candidate = expand(root . '/' . a:str . '.txt')
	    if(filereadable(path_candidate) || isdirectory(path_candidate))
	        return path_candidate
	    endif
	    let path_candidate = expand(root . '/' . a:str)
	    if(filereadable(path_candidate) || isdirectory(path_candidate))
	        return path_candidate
	    endif
	endfor

	" otherwise just return tag itself
	return a:str
endfunction

" RETURN: a dict with keys: "title", "file"
function! oumg#parse_file_title(str)

	" Get_Valid_STR_Solution_I: use expand('<cword>'), but need set Get_Valid_STR_Solution_I_Keywords
	let def_str = substitute(a:str, '\~/', $HOME . '/', '')
	
	" Get_Valid_STR_Solution_II: (deprecated by Get_Valid_STR_Solution_I) use expand('<cWORD>') and remove useless char at the beginning/end
	" NOTE: "\." in heading part should NOT be removed, otherwise relative path to current/parent dir will fail
	" NOTE: to remove "<" and ">", should use "<" and "\>" in pattern
	"let def_str = substitute(a:str, '^<[,;:\[\]\(\)[:space:]]*\|[,;:\.\[\]\(\)\>[:space:]]*$', '', 'g')
	"handle confliction of ~/xxx (path) and ~xxx (title)
	"let def_str = substitute(def_str, '\~/', $HOME . '/', '')
	
	" extract tile and file part
	let def_list = split(def_str, "@")

	" 1st: title@file, formal format
	if len(def_list) == 2							
		return { "file" : oumg#find_file(def_list[1]), "title" : substitute(def_list[0], '^\~', '', '') }
	endif

	" 2nd: @file, only File
	if match(def_str, '^@') >= 0
		return { "file" : oumg#find_file(def_str), "title" : "" }
		"return { "file" : oumg#find_file(substitute(def_str, '^@', '', '')), "title" : "" }
	endif

	" 3rd: file (NOT ~xxx), simple string, try file. 
	if match(def_str, '^\~') < 0
		let file_candidate = oumg#find_file(def_str)
		if filereadable(file_candidate)
			return { "file" : file_candidate, "title" : "" }
		endif
	endif

	" 4th: special treatment for note collection
	let current_line = getline('.')
	if expand("$HOME/.myenv/zgen/collection/all_content.txt") == expand("%:p") && search("^@", 'bW') > 0
		let file = substitute(getline('.'), "^@", '', '')
		" use fake 'title' to get correct jump 
		let title_list = matchlist(current_line, '^\t*\([^[:space:]]*\).*')
		return { "file" : file, "title" : title_list[1] }
	endif

	" 5th: ~title, only Title
	if match(def_str, '^\~') >= 0						
		return { "file" : expand("%"), "title" : substitute(def_list[0], '^\~', '', '') }
	endif

	" 6th: title, simple string, try Tile
	return { "file" : expand("%"), "title" : def_str }
endfunction

function! oumg#restore_is_keyword()
	let &iskeyword=g:oumg_temp_iskeyword_value
endfunction

function! oumg#set_is_keyword()
	let g:oumg_temp_iskeyword_value=&iskeyword
	
	" TODO: if the <word> contains both EN & CN words, seems can NOT expand success
	" WORD: set and restore each time: Get_Valid_STR_Solution_I_Keywords: . (current dir), / (path sep), $ (shell var), ~ (oumg title & ~tilde@bash), _ (normal word), @ (oumg file, need use @-@ instead, see iskeyword@vim)
	set iskeyword+=.
	set iskeyword+=/
	set iskeyword+=$
	set iskeyword+=~
	set iskeyword+=_
	set iskeyword+=@-@
endfunction

function! oumg#jump_file_title(cmd, location)
	if(a:location["file"] == expand("%"))
		let title_pattern_loose = "^\\c\\t*" . a:location["title"]
		let title_pattern_strict = "^\\c\\t*" . a:location["title"] . "\\s*$"

		" add a entry jump list so could use jump histoy
		normal m'

		" find and goto title
		if search(title_pattern_strict, 'cw') > 0
			let @/ = title_pattern_strict
			"normal n	" NOT need, as search() already did
			normal zz
		elseif search(title_pattern_loose, 'cw') > 0
			let @/ = title_pattern_loose
			"normal n	" NOT need, as search() already did
			normal zz
		else
			echo "WARN: NO title pattern found: " . title_pattern_loose
		endif
	else
		"let file = readfile(expand("xxx")) " read file
		"for line in file
		"let match = matchstr(line, '.*shouldmatch') " regex match
		"if(!empty(match))
		"endif
		"endfor
		
		"execute a:cmd . ' +/\\c^\\t*' . a:location["title"] . ' ' . a:location["file"]
		
		" search pattern should not contain '/', otherwise gets error 'not an editor command', use '\V' (Very No Magin) also complains, since '/' means 'search'
		let search_pattern_loose = ' +/\\c^\\t*' . substitute(a:location["title"], '/', '.', 'g') 
		execute a:cmd . search_pattern_loose . ' ' . a:location["file"]
		normal zz
	endif
endfunction

function! oumg#gen_pattern_outline(level)
	"return "^\t*[^ \t]\+$"							" NOT work, why?
	"return "^\t*\S\+\s*$"							" NOT work, why?
	"return "^[[:space:]]*[-_\.[:alnum:]]\+[[:space:]]*$"			" NOT work, since vim not fully support POSIX regex syntax
	"return "^\t*[^ \t][^ \t]*$", flags) > 0				" works, but all Chinese becomes outline
	"return "^\t*[-_a-z0-9\/\.][-_a-z0-9\/\.]*[\t ]*$"			" works, but a bit strict, chinese all excluded
	"return '^\t*[^ \t\r\n\v\f]\{2,30}[ \t\r\n\v\f]*$'			" works, include chinese
	"return '^\t\{0,' . a:level . '}[^ \t\r\n\v\f]\{2,20}[ \t\r\n\v\f]*$'	" almost works, support levels, Chinese char also counts 1 (NOT 2), but some 1st level head can NOT be matched (e.g. overview), why?
	return '^\t\{0,' . a:level . '}[^[:space:]]\{2,20}[[:space:]]*$'
endfunction

function! oumg#mo(count)
	" safty check: to avoid long pause
	if line('$') >= 8000
		echo "WARN: too much line to handle, give up!"
		return
	endif

	" safty check: count should be valid
	if a:count <= 0 || a:count > 5
		let level = 1
	else
		let level = a:count - 1
	endif

	call setloclist(0, [])
	let save_cursor = getpos(".")

	call cursor(1, 1)
	let flags = 'cW'
	let file = expand('%')
	let pattern = oumg#gen_pattern_outline(level)
	while search(pattern, flags) > 0
		let flags = 'W'
		let title = substitute(getline('.'), '[[:space:]]*$', '', '')		" remove trailing spaces
		let titleToShow = substitute(title, '\t', '........', 'g')		" location list removes any preceding space, so use '.' instead
		if titleToShow !~ "^\\." 
			let blank_line = printf('%s:%d:%s', file, line('.'), "  ")
			laddexpr blank_line
		endif
		let msg = printf('%s:%d:%s', file, line('.'), titleToShow)
		laddexpr msg
	endwhile

	let lwidth = (20*(level+1))-(8*level)
	call setpos('.', save_cursor)
	vertical lopen
	execute "vertical resize " . lwidth

	" hide filename and line number in quickfix window, not sure how it works yet.
	set conceallevel=2 concealcursor=nc
	syntax match qfFileName /^.*| / transparent conceal
	"syntax match qfFileName /^[^|]*/ transparent conceal
endfunction

function! oumg#buffer_list_str()
	" return ':ls' output as string, call with ':silent' to suppress output in GUI
	let buffer_list = ''
	redir =>> buffer_list
	ls
	redir END
	return buffer_list
endfunction

function! oumg#on_qf_init()
	" check file type
	if &ft != 'qf'
		return
	endif

	" use buffer list to check, seem no better way after long investigation
	silent let buffer_list = oumg#buffer_list_str()
	let pattern = bufnr('%') . '.*"\[Quickfix List\]"'
	if match(buffer_list, pattern) < 0
		return
	endif

	setlocal wrap
	setlocal modifiable
	execute 'write! /tmp/vim-oumg-qf-' .  bufnr('%')
endfunction

function! oumg#on_qf_write()
	" check modify status
	if !&modified
		return
	endif

	" filter those deleted lines
	let entries = getqflist()		" qf entries (original, before edit)
	call filter(entries, 'match(getline(1,''$''), ''^'' . bufname(v:val.bufnr) . ''|'' . v:val.lnum . ''|.*$'' ) >= 0')

	" set backup to qf list
	call setqflist(entries, 'r')
	setlocal nomodified
	setlocal modifiable	" seems need set again, otherwise nomodifiable after 'write'
endfunction

" Control the Quickfix window. Just record here, should set in .vimrc
"au FileType qf nmap <buffer> <esc> :close<cr>
"au FileType qf nmap <buffer> <cr> <cr>zz<c-w><c-p>

" plugin entrance for quickfix init and write
augroup quickfix_reflector
	autocmd!
	autocmd BufWriteCmd vim-oumg-qf-* :call oumg#on_qf_write()
	autocmd BufReadPost quickfix nested :call oumg#on_qf_init()
augroup END

" Entrance I: outline
nnoremap <silent> mo :<C-U>call oumg#mo(v:count)<CR>

" Entrance II: my go, for more: see Get_Valid_STR_Solution_I and Get_Valid_STR_Solution_II
nnoremap <silent> mg :<C-U>call oumg#set_is_keyword() <bar>
		     \ call oumg#jump_file_title("silent edit", oumg#parse_file_title(expand('<cword>'))) <bar>
		     \ call oumg#restore_is_keyword() <CR>

" plugin entrance for command line mode
command! -nargs=* -complete=file E      :call oumg#jump_file_title("e"     , oumg#parse_file_title(<q-args>))
command! -nargs=* -complete=file New    :call oumg#jump_file_title("new"   , oumg#parse_file_title(<q-args>))
command! -nargs=* -complete=file Vnew   :call oumg#jump_file_title("vnew"  , oumg#parse_file_title(<q-args>))
command! -nargs=* -complete=file Tabnew :call oumg#jump_file_title("tabnew", oumg#parse_file_title(<q-args>))
command! -nargs=* -complete=file Vi     :call oumg#jump_file_title("tabnew", oumg#parse_file_title(<q-args>))

" *hack* buidlin command via command line abbr
:cabbrev e      <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'E'      : 'e'     )<CR>
:cabbrev new    <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'New'    : 'new'   )<CR>
:cabbrev vnew   <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'Vnew'   : 'vnew'  )<CR>
:cabbrev vi     <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'Vi'     : 'vi'    )<CR>
:cabbrev tabnew <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'Tabnew' : 'tabnew')<CR>



""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Deprecated 
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Deprecated by direct using oumg#parse_file_title() and oumg#jump_file_title() 
"command! -nargs=1 E :call oumg#tag_add_support("e", <f-args>)
"command! -nargs=1 Tabnew :call oumg#tag_add_support("tabnew", <f-args>)
"nnoremap <silent> mg :<C-U>call oumg#mg()<CR>
"function! oumg#mg()
"	let location = oumg#parse_file_title()
"	call oumg#jump_file_title("silent edit", location)
"endfunction

"Deprecated by oumg#parse_file_title() and oumg#jump_file_title()
"function! oumg#tag_add_support(cmd, tag)
"	let file_candidate=oumg#find_file(a:tag)
"	if filereadable(file_candidate)
"		execute a:cmd . " " . file_candidate
"	endif
"endfunction


"Deprecated by oumg#find_file()
"function! oumg#tag_get_value(tag)
"	" no translate for exist path
"	if filereadable(a:tag)
"		return a:tag
"	endif
"
"	" translate tag
"	for tag_filename in ["$HOME/.myenv/list/tags_addi", "$HOME/.myenv/zgen/tags_note"]	
"		for line in readfile(expand(tag_filename))
"			let match = matchstr(line, '^' . a:tag . '=.*')
"			if(!empty(match))
"				return substitute(match, '[^=]\+=', '', '')
"			endif
"		endfor
"	endfor	
"
"	" otherwise return same string
"	return a:tag
"endfunction

" Deprecated by "au FileType qf nmap ..."
""autocmd BufWinEnter quickfix silent! nnoremap <ESC> :q<CR>
""autocmd BufWinEnter quickfix silent! exec "unmap <CR>" | exec "nnoremap <CR> <CR>:bd ". g:qfix_win . "<CR>zt"	" seems not need delete the buffer anymore (because of what? vim updates? plugin updates?)
"autocmd BufWinEnter "Location List" let g:qfix_win = bufnr("$")
"autocmd BufWinEnter "Location List" silent! nnoremap <ESC> :exec "bd " . g:qfix_win<CR>
"autocmd BufWinEnter "Location List" silent! exec "unmap <CR>" | exec "nnoremap <CR> <CR>zt"
"autocmd BufLeave * if exists("g:qfix_win") && expand("<abuf>") == g:qfix_win | unlet! g:qfix_win | exec "unmap <ESC>" | exec "nnoremap <CR> o<Esc>" | endif
"autocmd BufWinLeave * if exists("g:qfix_win") && expand("<abuf>") == g:qfix_win | unlet! g:qfix_win | exec "unmap <ESC>" | exec "nnoremap <CR> o<Esc>" | endif	" use BufLeave, seems BufWinLeave NOT triggered when hit <Enter> in outline(quickfix) window
