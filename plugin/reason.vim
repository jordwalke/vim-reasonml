" Vim syntastic plugin helper
" Language:     Reason
" Maintainer:   Jordan Walke <jordojw@gmail.com>
" Portions Copyright (c) 2015-present, Facebook, Inc. All rights reserved.


" For an overview of plugin directory structure in Vim see:
" https://gist.github.com/nelstrom/1056049

if exists("g:loaded_vimreason")
  finish
endif
let g:loaded_vimreason = 1


" User Customizable Config Variables:

if !exists('g:vimreason_extra_args_expr_reason')
  let g:vimreason_extra_args_expr_reason=''
endif
if !exists('g:vimreason_project_airline')
  let g:vimreason_project_airline=1
endif
if !exists('g:vimreason_clean_project_airline')
  let g:vimreason_clean_project_airline=0
endif
if !exists('g:vimreason_syntastic_airline')
  let g:vimreason_syntastic_airline=1
endif


" User Customizable Lint And Error Symbols:
if !exists('g:vimBoxLinterErrorSymbol')
  let g:vimBoxLinterErrorSymbol="⮿"
endif
if !exists('g:vimBoxLinterWarningSymbol')
  let g:vimBoxLinterWarningSymbol="⮿"
endif
if !exists('g:vimBoxLinterOkSymbol')
  let g:vimBoxLinterOkSymbol="☻"
endif


let g:vimreason_ocamlmerlin_path=''

" From auto-format plugin:
" https://github.com/Chiel92/vim-autoformat/blob/master/plugin/autoformat.vim
if !exists('g:vimreason_reason')
  let g:vimreason_reason = "refmt"
endif
let g:vimreason_args_expr_reason = '"--print re --interface " .  (match(expand("%"), "\\.rei$") == -1 ? "false " : "true ") . " --parse " . (expand("%:e") == "" ? "re" : expand("%:e"))'

let s:save_cpo = &cpo
set cpo&vim

" Tell Syntastic about Reason filetype/enables tab completion 'SyntasticInfo'
" command. Doesn't actually register the checker.
if exists('g:syntastic_extra_filetypes')
  call add(g:syntastic_extra_filetypes, 'reason')
else
  let g:syntastic_extra_filetypes = ['reason']
endif


function! DoReasonPrettyPrint()
    let _s=@/
    let l = line(".")
    let c = col(".")
    if call('refmt#Refmt', a:000)
        if exists ('g:SyntasticChecker')
          execute 'SyntasticReset'
          " Can't do this till you save!
          " execute 'SyntasticCheck reasonc'
        endif
    endif
    let @/=_s
    call cursor(l, c)
endfunction


command -nargs=* ReasonPrettyPrint :call DoReasonPrettyPrint(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

" For some reason this was needed when the binaries ocamlmerlin/refmt were
" symlinks.
function! s:trimStr(string)
  return substitute(a:string, '\n\+$', '', '')
endfunction


" Utility functions copy/pasted from reasonPluginLoader.vim
let s:is_win = has('win32') || has('win64')
if s:is_win
  function! s:rtp(spec)
    return s:path(a:spec.dir . get(a:spec, 'rtp', ''))
  endfunction

  function! s:path(path)
    return s:trim(substitute(a:path, '/', '\', 'g'))
  endfunction

  function! s:dirpath(path)
    return s:path(a:path) . '\'
  endfunction
else
  function! s:rtp(spec)
    return s:dirpath(a:spec.dir . get(a:spec, 'rtp', ''))
  endfunction

  function! s:path(path)
    return s:trim(a:path)
  endfunction

  function! s:dirpath(path)
    return substitute(a:path, '[/\\]*$', '/', '')
  endfunction
endif

function! ReasonMaybeUseThisMerlinForAllProjects(thisProjectsMerlinPath)
  if !empty(a:thisProjectsMerlinPath)
    let thisProjectsMerlinPath = resolve(s:trimStr(a:thisProjectsMerlinPath))
    if empty(g:vimreason_ocamlmerlin_path)
      " Set the global merlin to this project's merlin.
      let g:vimreason_ocamlmerlin_path = thisProjectsMerlinPath
      " If installed through an esy sandboxed npm release prebuilt binaries find
      " the real location.
      if g:vimreason_ocamlmerlin_path =~ "reason-cli"
        let g:vimreason_ocamlmerlin_path = s:trimStr(system('ocamlmerlin ----where'))
      endif

      let ocamlmerlin=substitute(g:vimreason_ocamlmerlin_path,'ocamlmerlin$','','') . "../share/merlin/vim/"
      " syntastic. Enabled by default, no-op when syntastic isn't present
      let g:syntastic_ocaml_checkers=['merlin']
      let g:syntastic_reason_checkers=['merlin']
      let g:plugs_reasonPluginLoader['merlin'] = {'dir': (s:dirpath(ocamlmerlin))}
      call call(function("ReasonPluginLoaderLoad"), keys(g:plugs_reasonPluginLoader))
      " TODO: Make reasonPluginLoader do this rtp modification like VimPlug.
      execute "set rtp+=".ocamlmerlin
    else
      if thisProjectsMerlinPath != g:vimreason_ocamlmerlin_path
        let res = reason#VimReasonShortMsg("Warning: Starting merlin for new project, using a previously loaded merlin which differs. This might cause issues. See g:vimreason_ocamlmerlin_path and b:thisProjectsMerlinPath")
      endif
    endif
  endif
endfunction
" This is how you customize merlin to allow you to create an environment
" b:merlin_environment, as well as select a specific binary which may be
" different from the one used to load plugin code.
function! MerlinSelectBinary()
  let b:merlin_env = esy#FetchEnvCached()
  return g:vimreason_ocamlmerlin_path
endfunction
