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
" TestCase: 
" File: unit_test.vim
" python								" file: tag
" @python								" @file: tag
" overview@http								" title@file: use tag, without ~
" ~overview@http							" title@file: use tag
" overview@$MY_DCC/python/python.txt					" title@file: use path, without ~
" ~overview@$MY_DCC/python/python.txt					" title@file: use path
" ~overview								" title NOT exist
"
" @$HOME/.vimrc								" including env var
" ../README.md								" relative path
" @../README.md								" relative path, with @
"
" ~overview@python2							" file NOT exist
" @python21398								" @file: NOT exist
" ~overview2@python2							" both title and file NOT exist
"
" @vimrc:								" heading/tailing special char, and with @
" (@vimrc)								" heading/tailing special char, inside bracket
" (ss)vimrc)								" heading/tailing special char, ) in heading part
" @~/.vimrc,								" heading/tailing special char, with ~tilde@bash
" @$MY_DCC/vim/vim.txt,							" heading/tailing special char, including env var
" $MY_DCD/biugo/budget_cost/2020-04_月度费用与预算校对/overview.txt
"
": 表情@tv,aaa								" title contains CN
"：表情@tv，aaa								" title contains CN, boundary are also CN char
"：topic-话题@tv,aaa							" title contains CN & EN
":~1801_zaodian_播放入口@tv						" title contains CN & EN & NUM
" 你好vimrc测试一下							" among CN chars
":~表情@tv,aaa								" with EN boundary
"：~1801_zaodian_播放入口@tv，你好					" with CN boundary
"
" TODO: support layered syntax like: ~limit~performance@mysql 
" TODO: [URL@web](http://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md)	" should open URL@web when cursor is there
"
" TODO_Highlight:
"Title		OumnTitle			:syn match OumnTitle /^##.*/
"File Ref	OumnLinkFile			# (source external file)
"Title Ref	OumnLinkTitle			:syn match OumnLinkTitle /[xxx]/
"File Path	note/xxx.txt, xxx/xxx.txt	# xxx.txt seems the simplest, dir name "note" makes it not so obvious to see but still not difficult to goto
"Material Loc	<sub folder>

" START: script starts here
if exists("g:oumg_plugin_loaded") || &cp || v:version < 700
	finish
endif
let g:oumg_plugin_loaded = 1
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
	call oumg#echo_debug_info("value after parse_tag: " . base_candidate)

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
	if (base_expanded == home_expanded || base_expanded == root_expanded) 
		echo 'ERROR: base should NOT be $HOME (~/) or root (/)'
		return ""
	endif
	
	" create glob pattern
	let path_glob = '**'
	for item in path_list_real
		let path_glob = path_glob . '/*' . item . '*'
	endfor

	" try best effort (1st suitable file, seems already ignorecase)
	let file_candidate_list = globpath(base, path_glob, 0, 1)	" 0 means NOT apply 'suffixes' and 'wildignore', 1 means return as list
	call sort(file_candidate_list, "Oumg_str_len_cmp")
	for file_candidate in file_candidate_list
		if (filereadable(file_candidate) && oumg#is_vim_editable(file_candidate))
			return file_candidate
		endif
	endfor

	" otherwise return empty string. SHOULD NOT echo WARN here, since here is just a 'try'
	return ""
endfunction

function! oumg#is_vim_editable(file_path)
	let f_mime_type = system('file --mime --brief ' . a:file_path)
	call oumg#echo_debug_info("file mime type: " . f_mime_type)

	if match(f_mime_type, '^\(text/\|application/zip;\)') >= 0
		return v:true
	endif
	return v:false
endfunction

function! Oumg_str_len_cmp(str1, str2)
	return strlen(a:str1) - strlen(a:str2)
endfunction

function! oumg#echo_debug_info(str)
	let tmp = substitute(expand('<sfile>'), '\.\.oumg#echo_debug_info', '', '')
	let caller_name = substitute(tmp, '^.*\.\.', '', '')
	if exists("g:oumg_plugin_debug")
		echo caller_name . ": " . a:str
	endif
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
				echo 'ERROR: tag path (=' . path_candidate . ') found, but FILE NOT EXIST!'
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

function! oumg#restore_iskeyword()
	let &iskeyword=g:oumg_temp_iskeyword_value
endfunction

function! oumg#set_iskeyword()
	let g:oumg_temp_iskeyword_value=&iskeyword
	
	" TODO: if the <word> contains both EN & CN words, seems can NOT expand success
	" WORD: set and restore each time: Get_Valid_STR_Solution_I_Keywords: . (current dir), / (path sep), $ (shell var), ~ (oumg title & ~tilde@bash), _ (normal word), @ (oumg file, need use @-@ instead, see iskeyword@vim)
	"set iskeyword+=~	" NOT need to set as keyword, and better auto tag complete when not set
	set iskeyword+=.
	set iskeyword+=/
	set iskeyword+=$
	set iskeyword+=_
	set iskeyword+=@-@
endfunction

"TODO: 有一个URL pattern值得参考: https://github.com/itchyny/vim-highlighturl/
"function! highlighturl#default_pattern() abort
"  return  '\v\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%('
"        \.'[&:#*@~%_\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%_\-=?!+/0-9a-z]+|:\d+|'
"        \.',%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|'
"        \.'\([&:#*@~%_\-=?!+;/.0-9a-z]*\)|\[[&:#*@~%_\-=?!+;/.0-9a-z]*\]|'
"        \.'\{%([&:#*@~%_\-=?!+;/.0-9a-z]*|\{[&:#*@~%_\-=?!+;/.0-9a-z]*\})\})+'
"endfunction
function! oumg#match_http_addr()

	" REF: 匹配相关的注释见: test/unit_test.vim
	
	let matched_str = matchstr(getline("."), '{\?http[s]\?:\/\/[^\u0027\t)\]"[:space:]\u00FF-\u012F\u212b-\uFFFF]*')

	" special case: url in brace, the matchstr() need include {}, because
	" url with json might end with }, which need preserve, so only remove
	" if the whole url is in {}
	if match(matched_str, '^{.*}$') >= 0
		let matched_str = matched_str[1:-2]
	endif
		
	return matched_str 
endfunction

function! oumg#match_file_path()
	let cur_WORD = expand('<cWORD>')
	call oumg#echo_debug_info("get cWORD: " . cur_WORD)
	let cur_path = expand(cur_WORD)
	call oumg#echo_debug_info("expand to path: " . cur_path)

	" check is readable
	if !filereadable(cur_path)
		if isdirectory(cur_path)
			echo "vim-oumg warn: it is a directory!"
		endif

		call oumg#echo_debug_info("file un-readable, skip")
		return {}
	end

	if oumg#is_vim_editable(cur_path)
		call oumg#echo_debug_info("text or text-zip file, skip")
		return { "text_file" : cur_path }
	endif

	call oumg#echo_debug_info("it is binary file, return: " . cur_path)
	return { "binary_file" : cur_path }
endfunction

function! oumg#match_oumg_addr()
	let cur_WORD = expand('<cWORD>')

	" 1. format: ~<title>@<file> 
	"    sample1: ~表情@tv,aaa
	"    sample2:~1801_zaodian_播放入口@tv
	"    sample3：~1801_zaodian_播放入口@tv
	"    sample4：~1801_zaodian_播放入口@$MY_DCD/tinyvideo/tinyvideo.txt		" need '/','\.','\$'
	"    sample4：~1801_zaodian_播放入口@~/documents/DCD/tinyvideo/tinyvideo.txt	" need '/','\.','~'
	let matched_addr = matchstr(cur_WORD, '\~.*@[[:alnum:]~/-_\.\$]*')
	if (!empty(matched_addr))
		return matched_addr
	endif
	
	" 2. format: <title>@<file> 
	"    sample1: 表情@tv,aaa		" title contains CN
	"    sample2：表情@tv，aaa		" title contains CN, boundary are also CN char
	"    sample3：topic-话题@tv,aaa		" title contains CN & EN
	let matched_addr = matchstr(cur_WORD, '[^[:space:]：，。]*@[[:alnum:]@~/-_\.]*')
	if (!empty(matched_addr))
		return matched_addr
	endif
	
	" 3. format: ~<title>
	"    sample1: (need goto @db) (~cross_join)
	"    sample2: (need goto @tv) ~1801_zaodian_播放入口
	let matched_addr = matchstr(cur_WORD, '\~[^[:space:]：，。)>\],\.]*')
	if (!empty(matched_addr))
		return matched_addr
	endif

	" (last): use the old/simple '<cword>'
	call oumg#set_iskeyword()		" need set keyword to get the wanted string
	"let c_word = expand('<cword>')		" this could avoid includes useless extra chars, but also excluded CN chars
	let c_word = expand('<cWORD>')		" use WORD to include CN chars
	call oumg#restore_iskeyword()		" restore the original
	return c_word

endfunction

function! oumg#mg()
	
	" NOTE: 'netrw-gx' can NOT support url with char like ?/#, so not really useful, here handles http url to support those chars
	
	" Find target addresses
	let matched_http_addr = oumg#match_http_addr()
	let matched_oumg_addr = oumg#match_oumg_addr()
	let matched_file_path = oumg#match_file_path()

	" Open as http url if <cword> is NOT a oumg link, and it is a http url
	if (!empty(matched_http_addr) && match(matched_oumg_addr, '[~@]') < 0)	

		" 'open' might cause encoding and special char problems
		let open_cmd = "/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome"
		call oumg#echo_debug_info("open as http url: " . matched_http_addr)

		"silent exec "!".open_cmd." ".shellescape(matched_http_addr)		" NOT work for url with # (will be removed by sheel), { (will be encoded), % (will replace with filename)
		"silent exec "!".open_cmd." ".matched_http_addr				" NOT work for url with # (will be removed by shell), { (will be encoded), % (will replace with filename)
		"silent exec "!".open_cmd." ".matched_http_addr				" # vanished, % replaced with filename
		"silent exec "!".open_cmd." '".matched_http_addr."'"			" # vanished, % replaced with filename
		"silent exec "!".open_cmd." '".shellescape(matched_http_addr, 1)."'"	" NOT work, the url actually quoted twice like ''url''

		" should NO comment on exec line
		silent exec "!".open_cmd." ".shellescape(matched_http_addr, 1)
		return
	endif

	" Open as non-text file, which need call system 'open'
	let matched_binary_file = get(matched_file_path, "binary_file", "")
	if( !empty(matched_binary_file ) )	
		call oumg#echo_debug_info("open as binary file: " . matched_binary_file)
		call system('open ' . matched_binary_file)
		return
	endif
	
	let matched_text_file = get(matched_file_path, "text_file", "")
	if(!empty(matched_text_file))	
		call oumg#echo_debug_info("open as text or text-zip file: " . matched_text_file)
		execute "silent edit " . matched_text_file
		return
	endif

	" Open as oumg addr
	call oumg#jump_file_title("silent edit", matched_oumg_addr)
endfunction

function! oumg#jump_file_title(cmd, file_title_str)
	let location = oumg#parse_file_title(a:file_title_str)

	" Jump inside current file
	if(location["file"] == expand("%"))
		call oumg#jump_title(location["title"])

	" jump in another file
	else
		" Check file existence
		if ! filereadable(location["file"])
			echo "WARN: file NOT found for: " . substitute(a:file_title_str, '.*@', '', 'g') 
			return
		endif
		
		execute a:cmd . ' ' . location["file"]
		if (!empty(location["title"]))
			call oumg#jump_title(location["title"])
		endif
		normal zz
	endif
endfunction

function! oumg#jump_title(title)
	" Solution I: jump with simple patter
	" search pattern should not contain '/', otherwise gets error 'not an editor command', use '\V' (Very No Magin) also complains, since '/' means 'search'
	"let search_pattern_loose = ' +/\\c^\\t*' . substitute(location["title"], '/', '.', 'g') 
	"execute a:cmd . search_pattern_loose . ' ' . location["file"]
	
	" Solution II: find real title first, then simple a starting heading
	let title_pattern_loose = "^\\c\\t*" . a:title
	let title_pattern_strict = "^\\c\\t*" . a:title . "\\s*$"

	" add a entry jump list so could use jump histoy
	normal m'

	" find and goto title, in strict way
	let target_line = search(title_pattern_strict, 'cw')
	if target_line > 0
		call cursor(target_line, 1)
		"let @/ = title_pattern_strict		" Deprecated this, since poluted the search history
		"normal n				" NOT need, as search() already did
		normal zz
		return
	endif

	" find and goto title, in loose way
	let target_line = search(title_pattern_loose, 'cw')
	if target_line  > 0
		call cursor(target_line, 1)
		"let @/ = title_pattern_loose		" Deprecated this, since poluted the search history
		"normal n				" NOT need, as search() already did
		normal zz
		return
	endif

	" not title found, give a warn
	echo "WARN: NO title pattern found: " . title_pattern_loose
endfunction

function! oumg#outline_pattern(level)
	"return "^\t*[^ \t]\+$"							" NOT work, why?
	"return "^\t*\S\+\s*$"							" NOT work, why?
	"return "^[[:space:]]*[-_\.[:alnum:]]\+[[:space:]]*$"			" NOT work, since vim not fully support POSIX regex syntax
	"return "^\t*[^ \t][^ \t]*$", flags) > 0				" works, but all Chinese becomes outline
	"return "^\t*[-_a-z0-9\/\.][-_a-z0-9\/\.]*[\t ]*$"			" works, but a bit strict, chinese all excluded
	"return '^\t*[^ \t\r\n\v\f]\{2,30}[ \t\r\n\v\f]*$'			" works, include chinese
	"return '^\t\{0,' . a:level . '}[^ \t\r\n\v\f]\{2,25}[ \t\r\n\v\f]*$'	" almost works, support levels, Chinese char also counts 1 (NOT 2), but some 1st level head can NOT be matched (e.g. overview), why?
	return '^\t\{0,' . a:level . '}[^[:space:]]\{2,35}[[:space:]]*$'
endfunction

function! oumg#mo_common(level)
	let flags = 'cW'
	let lwidth = 25
	let file = expand('%')
	let pattern = oumg#outline_pattern(a:level)

	while search(pattern, flags) > 0
		let flags = 'W'
		let title = substitute(getline('.'), '[[:space:]]*$', '', '')		" remove trailing spaces, since need replace space to '.' below
		let titleToShow = substitute(title, '\t', '........', 'g')		" location list removes any preceding space, so use '.' instead
		if titleToShow !~ "^\\." 
			laddexpr printf('%s:%d:%s', file, line('.'), "  ")
		endif
		laddexpr printf('%s:%d:%s', file, line('.'), titleToShow)

		let tmplen = strlen(iconv(titleToShow, 'UTF-8', 'latin1'))		" more close to real width if contains Chinese
		let lwidth = tmplen > lwidth ? tmplen : lwidth
	endwhile

	return lwidth + 8
endfunction

function! oumg#mo_python()
	let flags = 'cW'
	let lwidth = 25
	let file = expand('%')
	let pattern = '^[[:blank:]]*\(def \|class \|@\)'

	while search(pattern, flags) > 0
		let flags = 'W'
		let title_tmp1 = substitute(getline('.'), '[[:space:]]*$', '', '')	" remove trailing spaces, since need replace space to '.' below

		let suffix = substitute(title_tmp1, '^[[:space:]]*', '', '')		" only need suffix part here
		let pftmp1 = substitute(title_tmp1, '^\([[:space:]]*\).*', '\1','g')	" location list removes any preceding space, so use '.' instead
		let pftmp2 = substitute(pftmp1, ' ', '.','g')
		let prefix = substitute(pftmp2, '\t', '....','g')

		if suffix =~ "^\\.*@" 							" for python annotation, merge next def line
			while search(pattern, flags) > 0				" all annotation should be merged
				let suffix_add = substitute(getline('.'), '^[[:space:]]*\|[[:space:]]*$', '', '')
				let suffix = suffix . " " . suffix_add
				if suffix_add !~ "^@" 
					break
				endif
			endwhile
		endif
		
		let titleToShow = prefix . suffix
		if titleToShow !~ "^\\."
			laddexpr printf('%s:%d:%s', file, line('.'), "  ")
		endif
		laddexpr printf('%s:%d:%s', file, line('.'), titleToShow)

		let tmplen = strlen(iconv(titleToShow, 'UTF-8', 'latin1'))		" more close to real width if contains Chinese
		let lwidth = tmplen > lwidth ? tmplen : lwidth
	endwhile

	return lwidth + 8
endfunction

function! oumg#mo_sh()
	let flags = 'cW'
	let lwidth = 25
	let file = expand('%')

	" matchs: function, #*80#comment#*80,
	let pattern = '^#\{80\}\n#.*\n#\{80\}$\|^[[:alnum:]_]*[[:blank:]]*()[[:blank:]]*{.*$\|^function[[:blank:]].*$'

	while search(pattern, flags) > 0
		let flags = 'W'
		if getline('.') =~ '^#\{80\}'
			let category = getline(line('.') + 1)
			laddexpr printf('%s:%d:%s', file, line('.'), "  ")
			laddexpr printf('%s:%d:%s', file, line('.') + 1, category)
			let tmplen = strlen(iconv(category, 'UTF-8', 'latin1'))			" more close to real width if contains Chinese
		else
			" only reserves funtion name
			let fname = substitute(getline('.'), '[[:blank:]]*(.*\|[[:blank:]]*{.*$', '', '')	
			laddexpr printf('%s:%d:%s', file, line('.'), fname)
			let tmplen = strlen(iconv(fname, 'UTF-8', 'latin1'))			" more close to real width if contains Chinese
		endif

		let lwidth = tmplen > lwidth ? tmplen : lwidth
	endwhile

	return lwidth + 8
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
	if "sh" == &filetype
		let lwidth = oumg#mo_sh()
	elseif "python" == &filetype
		let lwidth = oumg#mo_python()
	else
		let lwidth = oumg#mo_common(level)
	endif

	"let lwidth = (25*(level+1))-(8*level)
	call setpos('.', save_cursor)
	vertical lopen
	execute "vertical resize " . lwidth
	execute "set nowrap"

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

	" use buffer list to check, seem no better way after long investigation: location_VS_quickfix@vim
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

	" filter those deleted lines. 
	" NOTE: 
	"	expand('#' . v:val.bufnr) is just the file path shows in :cw window: A) filename or relative path if file is under current ROOT. B) otherwise absolute path
	" DESC:
	"	getline(1, '$')		return lines as list ([x, y, z, ...]) of current buffer (NOT content on disk, so un-writen deleted lines is NOT listed)
	"	getqflist()		return dictionary of items (keys like file/line/column/etc, :h getqflist() for detail)
	"	bufname()		will get what you see in :ls, which is fullpath
	let entries = getqflist()	" qf entries (original, before edit)
	"call filter(entries, 'match(getline(1,''$''), ''^'' . bufname(v:val.bufnr) . ''|'' . v:val.lnum . ''|.*$'' ) >= 0')		" too strict since used '^'
	"call filter(entries, 'match(getline(1,''$''), expand(''#'' . v:val.bufnr . '':t'') . ''|'' . v:val.lnum . ''|.*$'' ) >= 0')	" Only use filename, NOT accurate enough: if diff file with same name (in diff path), the delete will NOT reserved
	call filter(entries, 'match(getline(1,''$''), expand(''#'' . v:val.bufnr) . ''|'' . v:val.lnum . ''|.*$'' ) >= 0')		" WORKS perfectly

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

" plugin entrance for command line mode
command! -nargs=* -complete=file E      :call oumg#jump_file_title("e"     , <q-args>)
command! -nargs=* -complete=file New    :call oumg#jump_file_title("new"   , <q-args>)
command! -nargs=* -complete=file Vnew   :call oumg#jump_file_title("vnew"  , <q-args>)
command! -nargs=* -complete=file Tabnew :call oumg#jump_file_title("tabnew", <q-args>)
command! -nargs=* -complete=file Vi     :call oumg#jump_file_title("tabnew", <q-args>)

" *hack* buidlin command via command line abbr
:cabbrev e      <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'E'      : 'e'     )<CR>
:cabbrev new    <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'New'    : 'new'   )<CR>
:cabbrev vnew   <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'Vnew'   : 'vnew'  )<CR>
:cabbrev vi     <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'Vi'     : 'vi'    )<CR>
:cabbrev tabnew <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'Tabnew' : 'tabnew')<CR>

" Entrance I: outline
nnoremap <silent> mo :<C-U>call oumg#mo(v:count)<CR>/

" Entrance II: my go, for more: see Get_Valid_STR_Solution_I and Get_Valid_STR_Solution_II
nnoremap <silent> mg :<C-U> call oumg#mg() <CR>


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
