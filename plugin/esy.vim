let g:esyLogCacheMisses=0
"
let g:esyProjectRootCacheByBuffer = { }
let g:esyProjectInfoCacheByProjectRoot={}

let g:esyProjectManagerPluginLoaded=1



command -nargs=0 EsyFetchProjectInfo :echo esy#FetchProjectInfo()
command -nargs=0 EsyReset :echo esy#Reset()
command -nargs=1 EsyExec :echo esy#Exec(<q-args>)
command -nargs=0 EsyBuilds :echo esy#Builds()
command -nargs=0 EsyLibs :echo esy#Libs()
command -nargs=0 EsyModules :echo esy#Modules()
