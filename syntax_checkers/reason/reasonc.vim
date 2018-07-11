" Vim syntastic plugin
" Language:     Reason
" Maintainer:   Jordan Walke <jordojw@gmail.com>
"Portions Copyright (c) 2015-present, Facebook, Inc. All rights reserved.
"
" See for details on how to add an external Syntastic checker:
" https://github.com/scrooloose/syntastic/wiki/Syntax-Checker-Guide#external
" Based on the OCaml syntastic plugin.
" Portions Copyright (c) 2015-present, Facebook, Inc. All rights reserved

function! SyntaxCheckers_reason_merlin_IsAvailable()
  if !exists("*merlin#SelectBinary")
    return 0
  endif
  let l:path = ""
  try
    if !exists("b:merlin_binary")
      let l:path = merlin#SelectBinary()
    else
      let l:path = b:merlin_binary
    endif
  catch
    return 0
  endtry
  if exists("b:merlin_path")
    let l:path = b:merlin_path
  endif
  return executable(l:path)
endfunction

function! SyntaxCheckers_reason_merlin_GetLocList()
  let merlinErrList = merlin#ErrorLocList()
  if empty(merlinErrList) || !g:vimreason_precise_parse_errors
    return merlinErrList
  else
    " try
      let numOriginalErrors = len(merlinErrList)
      let j = 0
      let appearsToHaveSyntaxErr = 0
      while j < numOriginalErrors
        let err = merlinErrList[j]
        if empty(appearsToHaveSyntaxErr) &&
              \ (!empty(matchstr(err['text'],'\csyntax')) || !empty(matchstr(err['text'],'invalidCharacter.orComment.orString')))
           let appearsToHaveSyntaxErr = err
        endif
        let j = j + 1
      endwhile
      if empty(appearsToHaveSyntaxErr)
        return merlinErrList
      else
        let bufnr = bufnr('%')
        let totalCommand = g:vimreason_reason." ".eval(g:vimreason_args_expr_reason)
        let inLines = getline(1,'$')
        let buffContents = join(inLines, "\n")
        let out = esy#ExecWithStdIn(totalCommand, buffContents)
        if v:shell_error
          let matchedSyntaxError = matchlist(out, 'File "[^\\"]*", line \([0-9]\+\), characters \([0-9]\+\)')
          if empty(matchedSyntaxError)
            return merlinErrList
          else
            let line = matchedSyntaxError[1]
            let col = matchedSyntaxError[2] + 1
            if appearsToHaveSyntaxErr['lnum'] == line && appearsToHaveSyntaxErr['col'] == col
              " Okay, this is just the same syntax error. No use returning it
              " again, the original one likely has a better error message
              " anyways.
              return merlinErrList
            else
              " Add one error to the front, and shift the nr down for remaining.
              let syntaxError = {
                    \ 'bufnr':bufnr,
                    \ 'lnum':line,
                    \ 'col':col,
                    \ 'end_lnum':line,
                    \ 'end_col':col,
                    \ 'vcol':0,
                    \ 'nr':0,
                    \ 'pattern':'',
                    \ 'text': 'Syntax Error - Exact Location',
                    \ 'type':'E',
                    \ 'valid':1
                    \ }
              let newMerlinErrList = []
              call add(newMerlinErrList, syntaxError)
              let i = 0
              while i < numOriginalErrors
                let err = merlinErrList[i]
                let adjustedErr = {
                    \ 'bufnr':err['bufnr'],
                    \ 'lnum':err['lnum'],
                    \ 'col':err['col'],
                    \ 'end_lnum':err['end_lnum'],
                    \ 'end_col':err['end_col'],
                    \ 'vcol':err['vcol'],
                    \ 'nr':err['nr'] + 1,
                    \ 'pattern':err['pattern'],
                    \ 'text':err['text'],
                    \ 'type':err['type'],
                    \ 'valid':err['valid']
                    \ }
                let i = i + 1
                call add(newMerlinErrList, adjustedErr)
              endwhile
            endif
          endif
        else
          "Maybe we didn't really have a syntax error? Weird.
          return merlinErrList
        endif
        return newMerlinErrList
      endif
    " catch
    "   return merlinErrList
    " endtry
  endif
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'reason',
    \ 'name': 'merlin'})
