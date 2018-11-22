" Vim syntax file
" Language:	JSON (esy json extensions)
" Maintainer:	Jordan Walke

" Separated into a match and region because a region by itself is always greedy
" Not sure if that's actually important - coppied pattern from the json vim
syn match   jsonEsyDslMatch /#{\([^}]\)\+}/ contains=jsonEsyDsl
syn match   jsonEsyDslEnvVar /\$[[:alpha:]_][[:alnum:]_]*/ contained
syn match   jsonEsyDslPathSeparators /[/:]/ contained
syn region  jsonEsyDsl oneline matchgroup=jsonEsyDslGroup start=/#{/   end=/}/ contains=jsonEsyDslString,jsonEsyDslPkgVar,jsonEsyDslEnvVar,jsonEsyDslPathSeparators contained
" syn match   jsonEsyDslPkgVar  "\(@[[:alpha:]_-][[:alnum:]_-]*/\)\?[[:alpha:]_-][[:alnum:]_-]*\.[[:alnum:]_-]"me=e-1 contained
syn match   jsonEsyDslPkgVar  "\(@[[:alpha:]_-][[:alnum:]_-]*/\)\?[[:alpha:]_-][[:alnum:]_-]*\.[[:alnum:]_-]\+" contained
syn region  jsonEsyDslString oneline matchgroup=jsonEsyDslStringQuote start=/'/  skip=/\\\\\|\\'/  end=/'/ contains=jsonEscape contained
" Overwrite the original vim string highlighting
if has('conceal')
	syn region  jsonString oneline matchgroup=jsonQuote start=/"/  skip=/\\\\\|\\"/  end=/"/ concealends contains=jsonEscape,jsonEsyDsl contained
else
	syn region  jsonString oneline matchgroup=jsonQuote start=/"/  skip=/\\\\\|\\"/  end=/"/ contains=jsonEscape contained
endif

hi def link jsonEsyDsl               Normal
hi def link jsonEsyDslString         jsonString
hi def link jsonEsyDslStringQuote    jsonQuote
hi def link jsonEsyDslPkgVar         Function
hi def link jsonEsyDslGroup          Label
hi def link jsonEsyDslEnvVar         Operator
hi def link jsonEsyDslPathSeparators Number
