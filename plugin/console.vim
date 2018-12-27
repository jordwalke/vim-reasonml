" In case people don't like installing a new top level command.
if exists('g:reasonml_noConsoleCommands') && g:reasonml_noConsoleCommands
  " Fine then be that way.
else
  " Opens the console
  if (!exists(":Console"))
    command! -complete=expression -nargs=* Console call console#Console()
  endif
endif

" Customize these to something like:
" let g:console_message_token_format=[" INFO   ", " SUCCESS", " WARNING", " ERROR  "]
" let g:console_message_token_hl=["WildMenu", "WildMenu", "Error", "Error" ]

