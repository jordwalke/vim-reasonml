" Language:     Reason
" Description:  Vim ftplugin file for Reason

if exists("b:finished_activating_buffer_successfully")
  finish
endif

if exists("b:doing_ftplugin")
  " Something had set ft=reason during the loading of this ftplugin/reason.vim
  " file! This happens if we lazily load plugins.
  finish
endif

let b:doing_ftplugin = 1
let b:did_warn_no_esy_yet = 0
let b:did_warn_cant_status = 0


" call ReasonEnsureShellPlugins()


" Still waiting to load an esy project. It's okay, you can retry again by
" resettig the fieltype=reason
let projectRoot = esy#FetchProjectRoot()
if projectRoot == []
  let b:doing_ftplugin =0
  finish
else
  call esy#TrySetGlobalEsyBinaryOrWarn()
  if empty(g:reasonml_esy_discovered_path)
    let b:doing_ftplugin =0
    finish
  endif
  let info = esy#FetchProjectInfoForProjectRoot(projectRoot)
  " For every new buffer we can perform the check again if necessary.
  if info == []
  else
    let status = esy#ProjectStatusOfProjectInfo(info)
    if status == 'no-esy-field'
      " Okay, maybe this is a BuckleScript, or OPAM package. We'll work with
      " the globally installed toolchain
      " Detect when an esy field is later added. We'll need to completely kill
      " merlin. We can only have one version of merlin loaded per Vim.
    else
      if status != 'built'
        call console#Info("Esy: " . status . ". IDE features will activate once esy project is installed, built. set ft=reason to refresh.")
        let b:doing_ftplugin =0
        finish
      endif
    endif
  endif
endif

let s:save_cpo = &cpo
set cpo&vim

let &cpo = s:save_cpo
unlet s:save_cpo

" vim-reason-loader code
" =============
" The following two "if executable" checks are the primary original code for
" this plugin. The majority of the remaining code is simply copied from
" Vim-Plug in order to reuse Vim-Plug's lazy loading code.


let b:thisProjectsMerlinPath = esy#EsyLocateBinary("ocamlmerlin")

" Calling into this function, actually ends up setting ft=reason so you get
" caught in a loop which is why we have a b:doing_ftplugin variable). If
" b:doing_ftplugin is 1, then it means we're in a "reentrant" ftplugin call
" and we know to bail, letting the original call succeed. Calling into here
" will also end up calling plugin/reason.vim's `MerlinSelectBinary()` if
" merlin was found at this project path and the merlin vim plugin was loaded.
if b:thisProjectsMerlinPath != -1
  call ReasonMaybeUseThisMerlinForAllProjects(b:thisProjectsMerlinPath)
endif

" ReasonMaybeUseThisMerlinForAllProjects should set
" g:reasonml_ocamlmerlin_path if it was able to.
if !empty(g:reasonml_ocamlmerlin_path)
  if exists('g:merlin')
    let res = merlin#Register()
  endif
  let b:finished_activating_buffer_successfully = 1
else
  " Do not set b:finished_activating_buffer_successfully. Could not find merlin.
  let res = console#Error("Could not find merlin support. Is it listed in your devDependencies?")
endif

let b:doing_ftplugin = 0
