" Allow to be overridden by g:reasonml_esy_path.
" We will still check the version.
if !exists('g:reasonml_esy_path')
  let g:reasonml_esy_path=''
endif

" Standard Polyfill
" The v:t_number form was only recently added in Vim. This is a universal
" polyfill you can put in any plugin (multiple times without harm)
" There is no false/true/none/null for older vim versions.  If you know you
" are on vim-8, then I don't know why you'd need these g: variables you could
" just use v:t_boolean, but at least this way it's consistent.' There's
" probably some earlier 7.x version/patch that would be a better check.'
" Interesting: v:none==0 and v:null==0 but v:none != v:null and type(v:none)
" != type(0) and type(v:null) != type(0) This gives you a way to distinguish 0
" from none/null and none from null.
if !exists('g:polyfilled_v_type')
  let g:polyfilled_v_type=1
  let g:v_t_number = type(0)
  let g:v_t_string = type("")
  let g:v_t_func = type(function("tr")) 
  let g:v_t_list = type([]) 
  let g:v_t_dict = type({}) 
  let g:v_t_float = type(0.0) 
  if has("patch-8.0.0")
    let g:v_t_bool = type(v:false) 
    let g:v_t_none = type(v:none) 
  endif
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
