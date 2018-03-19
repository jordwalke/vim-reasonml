" Language:     Reason
" Description:  Vim ftplugin file for Reason

" Should be tracked per-buffer/project eventually.
if exists("b:did_ftplugin")
  finish
endif

" Still waiting to load an esy project. It's okay, you can retry again by
" resettig the fieltype=reason
let projectRoot = esy#FetchProjectRoot()
if projectRoot == []
  finish
else
  let info = esy#FetchProjectInfoForProjectRoot(projectRoot)
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
        call reason#VimReasonShortMsg("Esy Status: " . status . ". IDE features will activate once esy project is installed, built. set ft=reason to refresh.")
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
let b:thisProjectsMerlinPath = esy#ExecCached("which ocamlmerlin")
call ReasonMaybeUseThisMerlinForAllProjects(b:thisProjectsMerlinPath)

if !empty(g:vimreason_ocamlmerlin_path)
  let b:did_ftplugin = 1
else
  " Do not set b:did_ftplugin. Could not find merlin.
  let res = reason#VimReasonShortMsg("Could not find merlin support. Is it listed in your devDependencies?")
  finish
endif
