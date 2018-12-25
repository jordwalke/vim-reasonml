
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
let b:did_warn_cant_status = 0

call esy#TrySetGlobalEsyBinaryOrWarn()

" Already would have wared in esy#TrySetGlobalEsyBinaryOrWarn.
if empty(g:reasonml_esy_discovered_path)
  let b:doing_ftplugin = 0
  finish
endif

let projectInfo = {}
let projectRoot = esy#FetchProjectRoot()
if projectRoot == []
  " Still waiting to load an esy project. It's okay, you can retry again by
  " resetting the filetype=reason
  call console#Info("Cannot determine project root. No package.json/esy.json file.")
  let b:doing_ftplugin =0
  finish
else
  if empty(g:reasonml_esy_discovered_path)
    let b:doing_ftplugin =0
    finish
  endif
  let projectInfo = esy#FetchProjectInfoForProjectRoot(projectRoot)
  " For every new buffer we can perform the check again if necessary.
  if empty(projectInfo)
    call console#Error("Problem determining status of project")
    let b:doing_ftplugin =0
    finish
  else
    let status = esy#ProjectStatusOfProjectInfo(projectInfo)
    if empty(status) || !status['isProject']
      " Okay, maybe this is a BuckleScript, or OPAM package. We'll work with
      " the globally installed toolchain
      " Detect when an esy field is later added. We'll need to completely kill
      " merlin. We can only have one version of merlin loaded per Vim.
      call console#Warn("Project at " . projectRoot[0] . " doesn't seem to be a valid esy project")
      let b:doing_ftplugin =0
      finish
    else
      if !status['isProjectReadyForDev']
        let msg = status['isProjectFetched'] ? 'Project installed but not built. Run esy build from project root.' : 'Project not installed and not built. Run esy from the root directory.'
        call console#Info(msg)
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

if !empty(g:reasonml_force_ocamlmerlin_path)
  let b:reasonml_thisProjectsMerlinPath = g:reasonml_force_ocamlmerlin_path
else
  let b:reasonml_thisProjectsMerlinPath = esy#EsyLocateBinary("ocamlmerlin", projectRoot, projectInfo)
endif

if b:reasonml_thisProjectsMerlinPath != -1 && !empty(b:reasonml_thisProjectsMerlinPath)
  if empty(g:reasonml_most_recent_ocamlmerlin_path)
    " Set the global merlin to this project's merlin.
    let g:reasonml_most_recent_ocamlmerlin_path = b:reasonml_thisProjectsMerlinPath
  endif
  " Load merlin vim plugin if necessary/possible.
  " Calling into this function, actually ends up setting ft=reason so you
  " get caught in a loop which is why we have a b:doing_ftplugin variable).
  " If b:doing_ftplugin is 1, then it means we're in a "reentrant" ftplugin
  " call and we know to bail, letting the original call succeed. Calling
  " into here will also end up calling plugin/reason.vim's
  " `MerlinSelectBinary()` if merlin was found at this project path and the
  " merlin vim plugin was loaded.  TODO: We shouldn't ever have a globally
  " registered merlin path. It should always be tracked per project sandbox
  " per file.
  call ReasonMaybeUseThisMerlinVimPluginForAllProjects(b:reasonml_thisProjectsMerlinPath)
  " g:merlin was provided by merlin
  if exists('g:merlin')
    " Registers this buffer with merlin.
    let res = merlin#Register()
  endif
  let b:finished_activating_buffer_successfully = 1
else
  " Do not set b:finished_activating_buffer_successfully. Could not find merlin.
  let res = console#Warn("Could not find merlin support. Is it listed in your devDependencies?")
endif

let b:doing_ftplugin = 0
