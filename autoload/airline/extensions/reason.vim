" MIT License. Copyright (c) 2013-2018
" vim: et ts=2 sts=2 sw=2

scriptencoding utf-8

" Due to some potential rendering issues, the use of the `space` variable is
" recommended.

function! airline#extensions#reason#GetSyntasticErrors()
  let spc = g:airline_symbols.space
  " Trick: Warning prints one space, error prints two.
  let g:syntastic_stl_format = '%W{ }%E{  }'
  let errors = SyntasticStatuslineFlag()
  let len = strlen(errors)
  " 0, No errors no warning. customSyntasticOk will take up all the space, 1,
  if len == 0 || len == 1
    return ''
  endif
  " This must be a warning. Warning will take up all the space.
  if len == 1
    return ''
  endif
  " Only errors, no warnings.
  if len == 2
    return spc. spc. spc . spc . spc . g:vimBoxLinterErrorSymbol . spc
  endif
  " Both errors and warning. Errors and warnings must divide up space evenly.
  if len == 3
    return g:vimBoxLinterErrorSymbol . spc
  endif
  return ''
endfunction

function! airline#extensions#reason#GetSyntasticWarnings()
  let spc = g:airline_symbols.space
  let g:syntastic_stl_format = '%W{ }%E{  }'
  let errors = SyntasticStatuslineFlag()
  let len = strlen(errors)
  " No errors no warning. customSyntasticOk will take up all the space
  if len == 0
    return ''
  endif
  " This must be a warning. Warning will take up all the space.
  if len == 1
    return spc. spc. spc . spc . spc . g:vimBoxLinterWarningSymbol . spc
  endif
  " Only errors, no warnings.
  if len == 2
    return ''
  endif
  " Both errors and warning. Errors and warnings must divide up space evenly.
  if len == 3
    return g:vimBoxLinterWarningSymbol . spc
  endif
  return ''
endfunction

function! airline#extensions#reason#GetSyntasticOk()
  let spc = g:airline_symbols.space
  let g:syntastic_stl_format = '%W{ }%E{  }'
  let errors = SyntasticStatuslineFlag()
  let len = strlen(errors)
  " No errors no warning. customSyntasticOk will take up all the space
  if len == 0
    return spc . spc . spc . spc . spc . g:vimBoxLinterOkSymbol . spc . spc . spc . spc
  endif
  " This must be a warning. Warning will take up all the space.
  if len == 1
    return ''
  endif
  " Only errors, no warnings.
  if len == 2
    return ''
  endif
  " Both errors and warning. Errors and warnings must divide up space evenly.
  if len == 3
    return ''
  endif
  return ''
endfunction

" First we define an init function that will be invoked from extensions.vim
function! airline#extensions#reason#init(ext)

  let doSyntasticAirline = exists(':SyntasticCheck') && exists('g:reasonml_syntastic_airline') && g:reasonml_syntastic_airline==1
  if doSyntasticAirline
      " I think that using syntastic-err/warn instead of using the original
      " method of making a new part name, causes it to be truncated at < 80
      " chars.
    call airline#parts#define_function('syntastic-err', 'airline#extensions#reason#GetSyntasticErrors')
    call airline#parts#define_function('syntastic-warn', 'airline#extensions#reason#GetSyntasticWarnings')
    call airline#parts#define_function('customSyntasticOk', 'airline#extensions#reason#GetSyntasticOk')
    call airline#parts#define_minwidth('syntastic-err', 1)
    call airline#parts#define_minwidth('syntastic-warn', 1)
    " Might need to define a condition here?
    call airline#parts#define_minwidth('customSyntasticOk', 1)
  endif

  if doSyntasticAirline
    " Next up we add a funcref so that we can run some code prior to the
    " statusline getting modifed.
    call a:ext.add_statusline_func('airline#extensions#reason#apply')
  endif
endfunction

" This function will be invoked just prior to the statusline getting modified.
function! airline#extensions#reason#apply(...)
  let doSyntasticAirline = exists(':SyntasticCheck') && exists('g:reasonml_syntastic_airline') && g:reasonml_syntastic_airline==1
  if doSyntasticAirline
    " I have no idea why, but this is what the example.vim has for airline.
    " Appending to a w: variable. It's copied from the example.
    if doSyntasticAirline
      let w:airline_section_z = get(w:, 'airline_section_z', g:airline_section_z)
      let w:airline_section_z=w:airline_section_z .  airline#section#create(['customSyntasticOk'])
      " This is how you would normally implement a new extension if you weren't
      " overridding the existing syntastic ones like we are doing.
      " let w:airline_section_warning = get(w:, 'airline_section_warning', g:airline_section_warning)
      " let w:airline_section_error = get(w:, 'airline_section_error', g:airline_section_error)
      " let w:airline_section_warning=w:airline_section_warning . airline#section#create(['syntastic-warn'])
      " let w:airline_section_error=w:airline_section_error . airline#section#create(['syntastic-err'])
    endif
  endif
endfunction
