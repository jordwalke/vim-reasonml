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

" Get symlink resolved path to current script. Has to be done at top level
" scope, not in function.
let s:currentFilePath = resolve(expand('<sfile>:p'))
let s:vimReasonPluginRoot = fnamemodify(fnamemodify(s:currentFilePath, ':h'), ':h')

" User Customizable Config Variables:

if !exists('g:vimreason_precise_parse_errors')
  let g:vimreason_precise_parse_errors=1
endif
if !exists('g:vimreason_extra_args_expr_reason')
  let g:vimreason_extra_args_expr_reason='""'
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


let g:vimreason_did_ensure_shell_plugins=0
let g:vimreason_ocamlmerlin_path=''

" From auto-format plugin:
" https://github.com/Chiel92/vim-autoformat/blob/master/plugin/autoformat.vim

if !exists('g:vimreason_reason')
  let g:vimreason_reason = "refmt"
endif
let g:vimreason_args_expr_reason = '"--print re " .  (match(expand("%"), "\\.rei$") == -1 ? "--interface false " : "--interface true ")'

let s:save_cpo = &cpo
set cpo&vim

" Tell Syntastic about Reason filetype/enables tab completion 'SyntasticInfo'
" command. Doesn't actually register the checker.
if exists('g:syntastic_extra_filetypes')
  call add(g:syntastic_extra_filetypes, 'reason')
else
  let g:syntastic_extra_filetypes = ['reason']
endif

" Utilities: functions copy/pasted from reasonPluginLoader.vim Prefixed with
" __ so they don't show up in autocompletion in command line etc.
" TODO: These should go into a xolox/misc fork.

" For some reason this was needed when the binaries ocamlmerlin/refmt were
" symlinks.
function! __ReasonUtilsTrimStr(string)
  return substitute(a:string, '\n\+$', '', '')
endfunction

let s:is_win = has('win32') || has('win64')
if s:is_win
  function! __ReasonUtilsPath(path)
    return __ReasonUtilsTrimStr(substitute(a:path, '/', '\', 'g'))
  endfunction

  function! __ReasonUtilsDirPath(path)
    return __ReasonUtilsPath(a:path) . '\'
  endfunction
else
  function! __ReasonUtilsPath(path)
    return __ReasonUtilsTrimStr(a:path)
  endfunction

  function! __ReasonUtilsDirPath(path)
    return substitute(a:path, '[/\\]*$', '/', '')
  endfunction
endif



" " No longer necessary as we interleave the vendoring into the plugin tree.
" " We just need to hope two coppies of the same xolox plugins installed won't
" " colide.
" function! ReasonEnsureShellPlugins()
"   echomsg "TRYING TO ENSURE "
"   if g:vimreason_did_ensure_shell_plugins
"     return
"   endif
"   let g:vimreason_did_ensure_shell_plugins=1
"   " Setup Shell Utilities:
"   " If they don't already have good shell integration installed, load the plugin
"   " dynamically.
"   if (!exists("*xolox#misc#os#exec"))
"     echomsg "misc.os doesnt exist"
"     let vimMiscDir = __ReasonUtilsDirPath(s:vimReasonPluginRoot . '/vendor/vim-misc')
"     let vimShellDir = __ReasonUtilsDirPath(s:vimReasonPluginRoot . '/vendor/vim-shell')
"     let g:plugs_reasonPluginLoader={}
"     let g:plugs_reasonPluginLoader['vim-misc'] = {'dir': vimMiscDir}
"     echomsg "loading " . vimMiscDir . " and " . vimShellDir
"     " TODO: Make reasonPluginLoader do this rtp modification like VimPlug.
"     call call(function("ReasonPluginLoaderLoad"), ['vim-misc'])
"     execute "set rtp+=".vimMiscDir
"     let g:plugs_reasonPluginLoader={}
"     let g:plugs_reasonPluginLoader['vim-shell'] = {'dir': vimShellDir}
"     call call(function("ReasonPluginLoaderLoad"), ['vim-shell'])
"     execute "set rtp+=".vimShellDir
"   endif
" endfunction


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

" Wat the following is true:
"   "asdf" == 0
function! s:isZero(a)
  return type(a:a) == v:t_string ? 0 : (type(a:a) == v:t_number ? (a:a == 0) : 0)
endfunction

function! ReasonMaybeUseThisMerlinForAllProjects(thisProjectsMerlinPath)
  if !empty(a:thisProjectsMerlinPath)
    let thisProjectsMerlinPath = resolve(__ReasonUtilsTrimStr(a:thisProjectsMerlinPath))
    if empty(g:vimreason_ocamlmerlin_path)
      " Set the global merlin to this project's merlin.
      let g:vimreason_ocamlmerlin_path = thisProjectsMerlinPath
      " If installed through an esy sandboxed npm release prebuilt binaries find
      " the real location.
      if g:vimreason_ocamlmerlin_path =~ "reason-cli"
        let g:vimreason_ocamlmerlin_path = __ReasonUtilsTrimStr(system('ocamlmerlin ----where'))
      endif

      let ocamlmerlin=substitute(g:vimreason_ocamlmerlin_path,'ocamlmerlin\(\.exe\)\?$','','') . "../share/merlin/vim/"
      let ocamlmerlinRtp = __ReasonUtilsDirPath(ocamlmerlin)
      " syntastic. Enabled by default, no-op when syntastic isn't present
      let g:syntastic_ocaml_checkers=['merlin']
      let g:plugs_reasonPluginLoader={}
      let g:plugs_reasonPluginLoader['merlin'] = {'dir': (ocamlmerlinRtp)}
      call call(function("ReasonPluginLoaderLoad"), keys(g:plugs_reasonPluginLoader))
      " TODO: Make reasonPluginLoader do this rtp modification like VimPlug.
      execute "set rtp+=".ocamlmerlinRtp
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
  let projectRoot = esy#FetchProjectRoot()
  let env = esy#ProjectEnv(projectRoot)
  if !empty(projectRoot)
    let b:merlin_env = env
  endif
  return g:vimreason_ocamlmerlin_path
endfunction
