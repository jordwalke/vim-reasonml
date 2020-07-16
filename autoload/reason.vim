" For some reason that env is too large on Windows. Copy over only the subset.
function! reason#MerlinEnvFromProjectEnv(envArg)
  " old vims don't let you rename variables to newly typed values.
  let env = a:envArg
  let newEnv = {
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
  return newEnv
endfunction

" Performs any sandbox/environment switching/reloading/cache-invalidation.
" Exposes descriptoin of result so that callers can customize the UI to the
" specific flow.
" TODO: Avoid invalidating caches unless the new projectInfo is actually
" actionable, but invalidate caches on correct builds. It could be in an
" intermediate state during development. Keep the last working environment in
" tact.
function! reason#RegisterMerlinOnEnvironmentChangedForReadyProject(projectRoot, projectInfo)
  let forcedMerlin = g:reasonml_force_ocamlmerlin_path
  let merlinPath = !empty(forcedMerlin) ? forcedMerlin : esy#EsyLocateBinaryForReadyProject("ocamlmerlin", a:projectRoot, a:projectInfo)
  if merlinPath != -1 && !empty(merlinPath)
    " Load merlin vim plugin if necessary/possible. Calling into this
    " function, actually ends up setting ft=reason so you get caught in a loop
    " which is why we have a b:doing_ftplugin variable). If b:doing_ftplugin
    " is 1, then it means we're in a "reentrant" ftplugin call and we know to
    " bail, letting the original call succeed. Calling into here will also end
    " up calling plugin/reason.vim's `MerlinSelectBinary()` if merlin was
    " found at this project path and the merlin vim plugin was loaded. TODO:
    " We shouldn't ever have a globally registered merlin path. It should
    " always be tracked per project sandbox per file.
    call ReasonMaybeUseThisMerlinVimPluginForAllProjects(merlinPath)
    " g:merlin was provided by merlin loaded plugin.
    if exists('g:merlin')
      let projectEnv = esy#ProjectEnvCached(a:projectRoot)
      let env = reason#MerlinEnvFromProjectEnv(projectEnv)
      " Merlin looks for them under these names.
      let b:merlin_path = merlinPath
      let b:merlin_env = env
      " Set the most recent merlin env/path in case we need some backup later.
      let g:reasonml_most_recent_ocamlmerlin_path = merlinPath
      let g:reasonml_most_recent_merlin_env = b:merlin_env
      " Registers this buffer with merlin, will trigger the MerlinSelectBinary call.
      try
        call merlin#Register()
      catch
        call console#Warn(v:exception)
        call console#Warn("Could not load merlin merlin support. The environment might not be setup correctly - see :messages for exception")
      endtry
    endif
    return 1
  else
    return 0
  endif
endfunction


function! reason#LoadBuffer()
  let projectRoot = esy#FetchProjectRootCached()
  let esyPath = esy#getBestEsyPathForProject(projectRoot)
  if empty(esyPath)
    call esy#WarnAboutMissingEsy()
    return 0
  endif
  let projectInfo = esy#FetchProjectInfoForProjectRootCached(projectRoot)
  if !esy#UserValidateIsReadyProject(projectRoot, projectInfo, "load reasonml support")
    return 0
  endif
  " For every new buffer we can perform the check again if necessary.
  let res = reason#RegisterMerlinOnEnvironmentChangedForReadyProject(projectRoot, projectInfo)
  if res == -1
    call console#Warn("Could not find merlin support. Is it listed in your devDependencies?")
    return 0
  endif
  return res
endfunction
