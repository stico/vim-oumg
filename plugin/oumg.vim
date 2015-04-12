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
    " OR: just keep [[:alnum:]] and $, / 
    let str_stripped = substitute(a:str, '^[@,\[\]\(\)[:space:]]*\|[@,\[\]\(\)[:space:]]*$', '', 'g')	

    let file_candidate = expand(str_stripped)
    if(filereadable(file_candidate))
        return file_candidate
    endif

    " file in root paths 
    for root in ["$MY_DCC/note", "$MY_DCO/note", "$MY_DCD/project/note", "$MY_FCS/oumisc/oumisc-git"]
        let file_candidate = expand(root . '/' . str_stripped . '.txt')
        if(filereadable(file_candidate))
            return file_candidate
        endif
        let file_candidate = expand(root . '/' . str_stripped)
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
		return { "file" : oumg#find_candidate(def_str), "title" : "" }
		"return { "file" : oumg#find_candidate(substitute(def_str, '^@', '', '')), "title" : "" }
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
		let @/ = "^\t*" . a:location["title"] . "\s*$"
	else
		"let file = readfile(expand("xxx")) " read file
		"for line in file
		"let match = matchstr(line, '.*shouldmatch') " regex match
		"if(!empty(match))
		"endif
		"endfor
		execute 'silent edit +/^\\t*' . a:location["title"] . ' ' . a:location["file"]
		normal zz
	endif
endfunction

function! oumg#mg(count)
	let location = oumg#parse_file_title()
	call oumg#jump_file_title(location)
endfunction

function! oumg#gen_title_pattern(level)
	"return "^\t*[^ \t]\+$"							" NOT work, why?
	"return "^\t*\S\+\s*$"							" NOT work, why?
	"return "^[[:space:]]*[-_\.[:alnum:]]\+[[:space:]]*$"			" NOT work, since vim not fully support POSIX regex syntax
	"return "^\t*[^ \t][^ \t]*$", flags) > 0				" works, but all Chinese becomes outline
	"return "^\t*[-_a-z0-9\/\.][-_a-z0-9\/\.]*[\t ]*$"			" works, but a bit strict, chinese all excluded
	"return '^\t*[^ \t\r\n\v\f]\{2,30}[ \t\r\n\v\f]*$'			" works, include chinese
	"return '^\t\{0,' . a:level . '}[^ \t\r\n\v\f]\{2,20}[ \t\r\n\v\f]*$'	" works, support levels, Chinese char also counts 1 (NOT 2)
	
	return '^\t\{0,' . a:level . '}[^ \t\r\n\v\f]\{2,20}[ \t\r\n\v\f]*$'
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
	let pattern = oumg#gen_title_pattern(level)
	while search(pattern, flags) > 0
		let flags = 'W'
		let title = substitute(getline('.'), '[ \t]*$', '', '')				" remove trailing blanks
		let titleToShow = substitute(title, '\t', '........', 'g')			" quickfix window removes any preceding blanks
		if titleToShow !~ "^\\." 
			let blank = printf('%s:%d:%s', file, line('.'), "  ")
			laddexpr blank
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

nnoremap <silent> mo :<C-U>call oumg#mo(v:count)<CR>
nnoremap <silent> mg :<C-U>call oumg#mg(v:count)<CR>

" Control the Quickfix window
" Works for "[Quickfix List]": keep cursor in quickfix window and show content above 
" Works for "[Location List]": jump to corresponding location (loc window closed). (how it works?)
au FileType qf nmap <buffer> <esc> :close<cr>
au FileType qf nmap <buffer> <cr> <cr>zz<c-w><c-p>
" Deprecated by above lines
""autocmd BufWinEnter quickfix silent! nnoremap <ESC> :q<CR>
""autocmd BufWinEnter quickfix silent! exec "unmap <CR>" | exec "nnoremap <CR> <CR>:bd ". g:qfix_win . "<CR>zt"	" seems not need delete the buffer anymore (because of what? vim updates? plugin updates?)
"autocmd BufWinEnter "Location List" let g:qfix_win = bufnr("$")
"autocmd BufWinEnter "Location List" silent! nnoremap <ESC> :exec "bd " . g:qfix_win<CR>
"autocmd BufWinEnter "Location List" silent! exec "unmap <CR>" | exec "nnoremap <CR> <CR>zt"
"autocmd BufLeave * if exists("g:qfix_win") && expand("<abuf>") == g:qfix_win | unlet! g:qfix_win | exec "unmap <ESC>" | exec "nnoremap <CR> o<Esc>" | endif
"autocmd BufWinLeave * if exists("g:qfix_win") && expand("<abuf>") == g:qfix_win | unlet! g:qfix_win | exec "unmap <ESC>" | exec "nnoremap <CR> o<Esc>" | endif	" use BufLeave, seems BufWinLeave NOT triggered when hit <Enter> in outline(quickfix) window

