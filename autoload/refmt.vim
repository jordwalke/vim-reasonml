
function! refmt#Strip(input_string)
  return substitute(a:input_string, '\s*$', '\1', '')
endfunction

function! refmt#extractCompilerSyntaxErr(text)
  let lines = split(a:text, )
  let matchedSyntaxError = matchlist(a:text, 'File "[^"]*", line \([0-9]\+\), characters \([0-9]\+\)-\([0-9]\+\)\(:\)\?\(.*\)')
  if empty(matchedSyntaxError)
    return {}
  else
    let extra =  matchedSyntaxError[5]
    let extra = substitute(extra, 'File "[^"]*",', '  ', 'g')
    return {'line': matchedSyntaxError[1], 'col': matchedSyntaxError[2] + 1, 'extra': extra}
  endif
endfunction

function! refmt#callRefmtProgram(inLines, ext)
  let pathTo = esy#EsyLocateBinarySuperCached(g:vimreason_reason)
  if pathTo == -1
    let res = console#Error("ReasonPrettyPrint: refmt not found. Open a .re file in a built esy project.")
    return {}
  endif
  let s:vimreason_args = ""
  if exists("g:vimreason_args_expr_reason")
    let s:vimreason_args = eval(g:vimreason_args_expr_reason)
  elseif exists("g:vimreason_args_reason")
    let s:vimreason_args =  g:vimreason_args_reason
  endif
  let s:vimreason_extra_args = ""
  if exists("g:vimreason_extra_args_expr_reason")
    let s:vimreason_extra_args = eval(g:vimreason_extra_args_expr_reason)
  endif
  let tempin = tempname() . a:ext
  call writefile(a:inLines, tempin)
  let totalCommand = pathTo." ".s:vimreason_extra_args." ".s:vimreason_args." ".xolox#misc#escape#shell(tempin)

  " For some reason using 'input' hangs on windows, so we have to make our
  " own temp file.
  let out = xolox#misc#os#exec({'command': totalCommand, 'check': 0})
  return out
endfunction

function! refmt#Refmt(...)
  let inLines = getline(1,'$')
  let ext = match(expand("%"), "\\.rei$") == -1 ? ".re" : ".rei"
  let out = refmt#callRefmtProgram(inLines, ext)
  " Already handled refmt being gone
  if empty(out)
    return 0
  endif
  if out['exit_code'] != 0
    let compilerSyntaxError = refmt#extractCompilerSyntaxErr(join(out['stderr'], "    "))
    if !empty(compilerSyntaxError)
      call console#Error("Syntax Error line:" . compilerSyntaxError['line'] . " col:" . compilerSyntaxError['col'] . ' ' . compilerSyntaxError['extra'])
    else
      " Grab the original output.
      let out = join(out['stderr'], " ")
      let originalOut = substitute(out, "\001", '', 'g')
      let originalOut = substitute(originalOut, '\m\s\{2,}', ' ', 'g')
      let originalOut = substitute(originalOut, '\m^\s\+', '', '')
      let originalOut = substitute(originalOut, '\m\s\+$', '', '')
      " Now we'll go see if it was actually due to refmt not being in the
      " path. We didn't want to do this before trying to refmt because it
      " slows down refmts to *valid* installs. This way, we'll only pay the
      " which refmt delay to check the path when there was some error.
      call console#Error(originalOut)
    endif
    return 0
  else
    let numModifications = 0
    let outLines = out['stdout']
    let i = 0
    while i < len(outLines)
      if i < len(inLines)
        let outLine = refmt#Strip(outLines[i])
        let inLine = inLines[i]
        if outLine != inLine
          let numModifications = numModifications + 1
          call setline(i + 1, outLine)
        endif
      else
        let outLine = refmt#Strip(outLines[i])
        " Notice no + 1
        call append(i, outLine)
        let numModifications = numModifications + 1
      endif
      let i = i + 1
    endwhile
    let stopDeletingAt = i
    let i = len(inLines) - 1
    while i >= stopDeletingAt
      execute ((i + 1) . " delete")
      let numModifications = numModifications + 1
      let i = i - 1
    endwhile
    if numModifications == 0
      let res = console#Info("Refmt: Already Formatted")
    else
      let res = console#Info("Formatted")
    endif
    return 1
  endif
endfunction
