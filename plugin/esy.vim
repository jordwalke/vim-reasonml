" Allow to be overridden by g:reasonml_esy_path.
" We will still check the version.
if !exists('g:reasonml_esy_path')
  let g:reasonml_esy_path=''
endif
" Where esy is found to be installed.
let g:reasonml_esy_discovered_path=g:reasonml_esy_path
" Esy version installed.
let g:reasonml_esy_discovered_ver=''


let g:esyLogCacheMisses=0

" Tracks the project root on file system by buffer.
" Each "project root" is a tuple [directory, json config]
" Let's assume this never changes.
let g:esyProjectRootCacheByBuffer = {}
" Most recently discovered project status `esy status` and config by
" projectRoot.directory + projectRoot.config
let g:esyProjectInfoCacheByProjectRoot={}
let g:esyLocatedBinaryByProjectRoot={}
let g:esyEnvCacheByProjectRoot={}


command! -nargs=0 EsyFetchProjectInfo :call esy#CmdFetchProjectInfo()
command! -nargs=0 EsyReset :call esy#CmdResetCacheAndReloadBuffer()
command! -nargs=1 EsyExec :call esy#CmdEsyExec(<q-args>)
command! -nargs=0 EsyBuilds :call esy#CmdBuilds()
command! -nargs=0 EsyStatus :call esy#CmdStatus()
command! -nargs=0 EsyLibs :call esy#CmdEsyLibs()
command! -nargs=0 EsyModules :call esy#CmdEsyModules()
command! -nargs=0 EsyHelp :call esy#CmdEsyHelp()
" Name this funny to prevent it polluting autocomple.
command! -nargs=0 EsyPleaseShowMostRecentError :call esy#CmdEsyPleaseShowMostRecentError()
