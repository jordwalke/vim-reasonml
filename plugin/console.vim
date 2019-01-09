" In case people don't like installing a new top level command.
if exists('g:reasonml_noConsoleCommands') && g:reasonml_noConsoleCommands
  " Fine then be that way.
else
  " Opens the console
  if (!exists(":Console"))
    command! -complete=expression -nargs=* Console call console#Console()
  endif
endif

" Standard Polyfill
" The v:t_number form was only recently added in Vim. This is a universal
" polyfill you can put in any plugin (multiple times without harm)
" There is no false/true/none/null for older vim versions.  If you know you
" are on vim-8, then I don't know why you'd need these g: variables you could
" just use v:t_boolean, but at least this way it's consistent.' There's
" probably some earlier 7.x version/patch that would be a better check.'
" Interesting: v:none==0 and v:null==0 but v:none != v:null and type(v:none)
" != type(0) and type(v:null) != type(0) This gives you a way to distinguish 0
" from none/null and none from null.
if !exists('g:polyfilled_v_type')
  let g:polyfilled_v_type=1
  let g:v_t_number = type(0)
  let g:v_t_string = type("")
  let g:v_t_func = type(function("tr")) 
  let g:v_t_list = type([]) 
  let g:v_t_dict = type({}) 
  let g:v_t_float = type(0.0) 
  if has("patch-8.0.0")
    let g:v_t_bool = type(v:false) 
    let g:v_t_none = type(v:none) 
  endif
endif


" Customize these to something like:
" let g:console_message_token_format=[" INFO   ", " SUCCESS", " WARNING", " ERROR  "]
" let g:console_message_token_hl=["WildMenu", "WildMenu", "Error", "Error" ]

