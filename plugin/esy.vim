if !exists('g:esy_environment_mode')
  let g:esy_environment_mode='json'
else
  if g:esy_environment_mode != 'json' && g:esy_environment_mode != 'command'
    let msg = "Your esy_environment_mode is set to " . g:esy_environment_mode . " - this makes no sense."
    call console#Error(msg)
  endif
endif

if !exists('g:vimreason_esy_path')
  let g:vimreason_esy_path=''
endif
" Where esy is found to be installed.
let g:vimreason_esy_discovered_path=''


let g:esyLogCacheMisses=0
"
let g:esyProjectRootCacheByBuffer = { }
let g:esyProjectInfoCacheByProjectRoot={}
let g:esyLocatedBinaryByProjectRootDir={}


let g:esyProjectManagerPluginLoaded=1



command! -nargs=0 EsyFetchProjectInfo :echo esy#CmdFetchProjectInfo()
command! -nargs=0 EsyResetEditorCache :echo esy#CmdResetEditorCache()
command! -nargs=1 EsyExec call esy#CmdEsyExec(<q-args>)
command! -nargs=0 EsyBuilds :echo esy#CmdBuilds()
command! -nargs=0 EsyLibs :echo esy#CmdEsyLibs()
command! -nargs=0 EsyModules :echo esy#CmdEsyModules()
command! -nargs=0 EsyHelp :echo esy#CmdEsyHelp()
command! -nargs=0 EsyRecentError call esy#CmdEsyRecentError()
