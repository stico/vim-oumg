" URL matching test
" usage: (in vim) :source %

" Note: 
" - k/v format: raw_str/expect_str
" - option ":set ignorecase" will effect matchstr
" - \u0027 is ' (single quote), since not find other way to escape
" - {url} still get {}, since need preserve json in url, will handle later
" - ')' actually leagal in URL@web, but here need deal url in markdown syntax 
" - 某些字母会有多个unicode，导致误匹配: 如 "k" ("\u212A") "i" ("\u0130")
" - vim某个版本开始 \u0131-\u2129 会匹配字母如: s/S (或者它只能运行在macvim/vim的某些版本里?)
" Case:
" - markdown style url
" - ensure all basic chars are tested
let url_dict = {
\ "https://zh.wikipedia.org/wiki/ISO_3166-1":"https://zh.wikipedia.org/wiki/ISO_3166-1",
\ "'https://zh.wikipedia.org/wiki/ISO_3166-1'":"https://zh.wikipedia.org/wiki/ISO_3166-1",
\ "\"https://zh.wikipedia.org/wiki/ISO_3166-1\"":"https://zh.wikipedia.org/wiki/ISO_3166-1",
\ "[https://zh.wikipedia.org/wiki/ISO_3166-1]":"https://zh.wikipedia.org/wiki/ISO_3166-1",
\ "(https://zh.wikipedia.org/wiki/ISO_3166-1)":"https://zh.wikipedia.org/wiki/ISO_3166-1",
\ "{https://zh.wikipedia.org/wiki/ISO_3166-1}":"{https://zh.wikipedia.org/wiki/ISO_3166-1}",
\ "http://a.b.c/defghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":"http://a.b.c/defghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
\ "http://ido.sysop.duowan.com/admin/faq/question/view.jsp?from=list&id=6020":"http://ido.sysop.duowan.com/admin/faq/question/view.jsp?from=list&id=6020", 
\ "http://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md":"http://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md", 
\ "https://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md":"https://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md", 
\ "[md link](http://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md)":"http://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md",
\ "访问http://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md，测试":"http://dev.yypm.com/web/?post=posts/standard/interfaces/yy_short_video/sv_soda.md", 
\ "https://docs.google.com/spreadsheets/d/1Xe3i-fZeki3GqXIOdJfhi0HgXQZK-z6kNC9_kaMFJT4/edit#gid=29158369":"https://docs.google.com/spreadsheets/d/1Xe3i-fZeki3GqXIOdJfhi0HgXQZK-z6kNC9_kaMFJT4/edit#gid=29158369", 
\ "https://docs.google.com/spreadsheets/d/1zZMPVfo0b_QkEBlj-p35KvDh6Nyjc0KFZN3rG2-WZ9E/edit#gid=974146624":"https://docs.google.com/spreadsheets/d/1zZMPVfo0b_QkEBlj-p35KvDh6Nyjc0KFZN3rG2-WZ9E/edit#gid=974146624", 
\ "http://monitor.sysop.duowan.com/statics/frontend/build/1.0.0/#/portal/metrics/server/{%22host%22%3A%22%22%2C%22idc%22%3A%22%22%2C%22isp%22%3A%22%22%2C%22version%22%3A%22%22%2C%22topic%22%3A%22%22%2C%22uri%22%3A%22http%2Fshare%2FgetShareRecommendList%22%2C%22tag%22%3A%22s%22%2C%22appName%22%3A%22biugo%22%2C%22serviceName%22%3A%22biugo-recommend%22%2C%22relation%22%3A%22package%22%2C%22quickTime%22%3A168%2C%22contrast%22%3A0%2C%22parentUri%22%3A%22http%2Fshare%2FgetShareRecommendList%22}": "http://monitor.sysop.duowan.com/statics/frontend/build/1.0.0/#/portal/metrics/server/{%22host%22%3A%22%22%2C%22idc%22%3A%22%22%2C%22isp%22%3A%22%22%2C%22version%22%3A%22%22%2C%22topic%22%3A%22%22%2C%22uri%22%3A%22http%2Fshare%2FgetShareRecommendList%22%2C%22tag%22%3A%22s%22%2C%22appName%22%3A%22biugo%22%2C%22serviceName%22%3A%22biugo-recommend%22%2C%22relation%22%3A%22package%22%2C%22quickTime%22%3A168%2C%22contrast%22%3A0%2C%22parentUri%22%3A%22http%2Fshare%2FgetShareRecommendList%22}",
\ } 

let res_all = 1

for [k,v] in items(url_dict)

	" - vim某个版本开始 \u0131-\u2129 会匹配字母如: s/S (或者它只能运行在macvim/vim的某些版本里?)		" 故下面3个之前可以用的都不行了
	" BACKUP1: 'http[s]\?:\/\/[^\u00FF-\u012F\u0131-\u2129\u212b-\uFFFF\t)[:space:]]*'			" BUT NOT excluding )]'"
	" BACKUP2: 'http[s]\?:\/\/[^\u0027\u00FF-\u012F\u0131-\u2129\u212b-\uFFFF\t)\]}"[:space:]]*'		" BUT excluded }, URL with json need this
	" BACKUP3: '{\?http[s]\?:\/\/[^\u0027\u00FF-\u012F\u0131-\u2129\u212b-\uFFFF\t)\]"[:space:]]*'		" include }, and including embracing {} (removed later on)
	
	let matched = matchstr(k, '{\?http[s]\?:\/\/[^\] \t\r\n\u0027)"\u00FF-\u012F\u212b-\uFFFF]*')
	let res_match = v == matched 

	if (!res_match)
		echo result ? "-------\tSUCCESS" : "xxxxxxx\tFAILED"
		echo "expect:\t" v
		echo "match:\t" matched
		g:res_all = 0
	endif
endfor

if (res_all) 
	echo "SUCCESS: all case passed!"
else
	echo "FAILED: some case failed, pls check!"
endif



" DEPRECATED
" echo matchstr("http://ido.sysop.duowan.com/admin/faq/question/view.jsp?from=list&id=6020", '{\?http[s]\?:\/\/[^\u0027\t)\]"[:space:]\u00FF-\u012F\u0131-\u2129\u212b-\uFFFF]*')
" echo matchstr("http://ido.sysop.duowan.com/admin/faq/question/view.jsp?from=list&id=6020", '{\?http[s]\?:\/\/[^\] \t\r\n\v\f\u0027)"\u00FF-\u012F\u0131-\u2129\u212b-\uFFFF]*')
"echo matchstr("http://ido.sysop.duowan.com/admin/faq/question/view.jsp?from=list&id=6020", '{\?http[s]\?:\/\/[^\] \t\r\n\u0027)"]*')

