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

if !exists('g:reasonml_precise_parse_errors')
  let g:reasonml_precise_parse_errors=1
endif
if !exists('g:reasonml_extra_args_expr_reason')
  let g:reasonml_extra_args_expr_reason='""'
endif
if !exists('g:reasonml_project_airline')
  let g:reasonml_project_airline=1
endif
if !exists('g:reasonml_clean_project_airline')
  let g:reasonml_clean_project_airline=0
endif
if !exists('g:reasonml_syntastic_airline')
  let g:reasonml_syntastic_airline=1
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


let g:reasonml_did_ensure_shell_plugins=0
if !exists('g:reasonml_ocamlmerlin_path')
  let g:reasonml_ocamlmerlin_path=''
endif
" The binary path that was used to load the vim plugin lazily. If you load
" multiple projects, each having their own merlin version, you can end up with
" multiple different merlin binaries - but we can only use *one* of their vim
" plugins.
if !exists('g:reasonml_ocamlmerlin_path_used_to_load_merlin_vim_plugin')
  let g:reasonml_ocamlmerlin_path_used_to_load_merlin_vim_plugin=''
endif

" From auto-format plugin:
" https://github.com/Chiel92/vim-autoformat/blob/master/plugin/autoformat.vim

if !exists('g:reasonml_reason')
  let g:reasonml_reason = "refmt"
endif
let g:reasonml_args_expr_reason = '"--print re " .  (match(expand("%"), "\\.rei$") == -1 ? "--interface false " : "--interface true ")'

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
"   if g:reasonml_did_ensure_shell_plugins
"     return
"   endif
"   let g:reasonml_did_ensure_shell_plugins=1
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

function! ReasonMaybeUseThisMerlinVimPluginForAllProjects(thisProjectsMerlinPath)
  let thisProjectsMerlinPath = resolve(__ReasonUtilsTrimStr(a:thisProjectsMerlinPath))
  if empty(g:reasonml_ocamlmerlin_path_used_to_load_merlin_vim_plugin)
    " Set the global merlin to this project's merlin.
    let g:reasonml_ocamlmerlin_path_used_to_load_merlin_vim_plugin = thisProjectsMerlinPath

    let ocamlmerlin=substitute(thisProjectsMerlinPath,'ocamlmerlin\(\.exe\)\?$','','') . "../share/merlin/vim/"
    let ocamlmerlinRtp = __ReasonUtilsDirPath(ocamlmerlin)
    " syntastic. Enabled by default, no-op when syntastic isn't present
    let g:syntastic_ocaml_checkers=['merlin']
    let g:syntastic_reason_checkers=['merlin']
    let g:plugs_reasonPluginLoader={}
    let g:plugs_reasonPluginLoader['merlin'] = {'dir': (ocamlmerlinRtp)}
    call call(function("ReasonPluginLoaderLoad"), keys(g:plugs_reasonPluginLoader))
    " TODO: Make reasonPluginLoader do this rtp modification like VimPlug.
    execute "set rtp+=".ocamlmerlinRtp
  endif
endfunction

" This is how you customize merlin to allow you to create an environment
" b:merlin_environment, as well as select a specific binary which may be
" different from the one used to load plugin code.
" TODO: If some previous file's merlin binary had been used, and the current
" does not have an esy project, then use the previous binary/environment.
" This workflow is important for jumping to location into the standard library
" because it won't have a project. There's no way you can prevent .ml files
" from calling into this function and registering merlin (the stock merlin vim
" plugin does the registering!) So might as well use some ocamlmerlin binary
" instead of failing.
function! MerlinSelectBinary()
  let projectRoot = esy#FetchProjectRoot()
  if !empty(projectRoot)
    let env = esy#ProjectEnv(projectRoot)
    " For some reason that env is too large on Windows.
    " Copy over only the subset.
    let env = {
          \ 'CAML_LD_LIBRARY_PATH': has_key(env, 'CAML_LD_LIBRARY_PATH') ? env['CAML_LD_LIBRARY_PATH'] : '',
          \ 'HOMEPATH': has_key(env, 'HOMEPATH') ? env['HOMEPATH'] : '',
          \ 'OCAMLFIND_COMMANDS': has_key(env,'OCAMLFIND_COMMANDS') ? env['OCAMLFIND_COMMANDS'] : '',
          \ 'OCAMLFIND_DESTDIR': has_key(env, 'OCAMLFIND_DESTDIR') ? env['OCAMLFIND_DESTDIR'] : '',
          \ 'OCAMLFIND_LDCONF': has_key(env, 'OCAMLFIND_LDCONF') ? env['OCAMLFIND_LDCONF'] : '',
          \ 'OCAMLLIB': has_key(env, 'OCAMLLIB') ? env['OCAMLLIB'] : '',
          \ 'OCAMLPATH': has_key(env, 'OCAMLPATH') ? env['OCAMLPATH'] : '',
          \ 'OCAML_TOPLEVEL_PATH': has_key(env, 'OCAML_TOPLEVEL_PATH') ? env['OCAML_TOPLEVEL_PATH'] : '',
          \ 'PATH': has_key(env, 'PATH') ? env['PATH'] : ''
          \ }
    let b:merlin_env = env
    " call console#Warn('empty project root - this probably should not happen.')
    return g:reasonml_ocamlmerlin_path
  else
    " call console#Warn('empty project root - this probably should not happen.')
    return g:reasonml_ocamlmerlin_path
  endif
  return g:reasonml_ocamlmerlin_path
endfunction
