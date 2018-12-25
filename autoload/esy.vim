" trim excess whitespace
function! s:trim(txt)
  return substitute(a:txt, '^\n*\s*\(.\{-}\)\n*\s*$', '\1', '')
endfunction
let g:esy_last_failed_stderr = ""
let g:esy_last_failed_stdout = ""
let g:esy_last_failed_cmd = ""

function! esy#trunc(s, len)
  if len(a:s) < a:len || len(a:s) == a:len
    return a:s
  else
    return strpart(a:s, 0, a:len-2) . '..'
  endif
endfunction

" Will log the stderr to g:esy_last_failed_stderr for debugging/inspecting.
function! s:resultFirstLineOr(res, orThis)
  if a:res['exit_code'] == 0
    return '' . (a:res['stdout'][0])
  else
    return a:orThis
  endif
endfunction

function! s:jsonObjOr(res, orThis)
  if a:res['exit_code'] == 0
    let str = '' . join(a:res['stdout'], "") " Empty string is required to match correctly on null}
    return eval('' . substitute(substitute(substitute(str, "true,", "1,", "g"), "false,", "0,", "g"), "null\\([,\\}]\\)", "''\\1", "g"))
  else
    return a:orThis
  endif
endfunction

let s:is_win = has('win16') || has('win32') || has('win64')

" Utilities:
" ======================================================================
" Operates on data structrues returned from more expensive calls.
" ======================================================================
function! esy#HasEsyField(packageText)
  return a:packageText =~ "\"esy\""
endfunction

" We support the ability for a `bsconfig.json` file to include a
" "packageRoot": "./relPath" field so that the actual esy root can exist
" somewhere different than the bsconfig.json.
" This allows your dev tools to exist somewhere other than your bsconfig,
" which means one esy project can power the dev tools of multiple bsconfigs.
function! esy#BSConfigPackageRoot(packageConfigStr)
  let res = matchlist(a:packageConfigStr, '"packageRoot":[^"]*"\([^"]*\)"')
  if empty(res)
    return ''
  else
    return res[1]
  endif
endfunction

function! esy#ProjectNameOfPackageText(packageConfigStr)
  let res = matchlist(a:packageConfigStr, '"name":[^"]*"\([^"]*\)"')
  if empty(res)
    return 'unnamed'
  else
    return res[1]
  endif
endfunction

function! esy#ProjectNameOfProjectInfo(info)
  if a:info == []
    echoms "Someone is passing empty info to esy#ProjectNameOfProjectInfo"
    return ''
  else
    return a:info[0]
  endif
endfunction

function! esy#ProjectStatusOfProjectInfo(info)
  if a:info == []
    call console#Error("Someone is passing empty info to esy#ProjectStatusOfProjectInfo - returning invalid project status")
    " let's let the empty object represent "invalid" status.
    return {}
  else
    return a:info[2]
  endif
endfunction



" Fetching Commands:
" ======================================================================
" Expensive, Only Do Once In While. Always up to date.
" ======================================================================


" Returns empty list if not a valid esy project.
function! esy#FetchProjectRoot()
  let l:isUnnamed=expand("%") == ''
  let l:cwd = expand("%:p:h")
  let l:rp = fnamemodify('/', ':p')
  let l:hp = fnamemodify($HOME, ':p')
  while l:cwd != l:hp && l:cwd != l:rp
    let esyJsonPath = resolve(l:cwd . '/esy.json')
    if filereadable(esyJsonPath)
      return [l:cwd, 'esy.json']
    endif
    let packageJsonPath = resolve(l:cwd . '/package.json')
    if filereadable(packageJsonPath)
      return [l:cwd, 'package.json']
    endif
    let bsConfigJsonPath = resolve(l:cwd . '/bsconfig.json')
    if filereadable(bsConfigJsonPath)
      " It is unfortunate that we need to read the file just to tell if it has
      " the designator, but at least it's only for bsconfig.json, and if the
      " other files weren't present.
      let packageText = join(readfile(bsConfigJsonPath), "\n")
      let relativePackageRoot = esy#BSConfigPackageRoot(packageText)
      if !empty(relativePackageRoot)
        let alegedProjectRoot = resolve(l:cwd . '/' . relativePackageRoot)
        let redirectedEsyJsonPath = resolve(alegedProjectRoot . '/esy.json')
        if filereadable(redirectedEsyJsonPath)
          return [alegedProjectRoot, 'esy.json']
        endif
        let redirectedPackageJsonPath = resolve(alegedProjectRoot . '/package.json')
        if filereadable(redirectedPackageJsonPath)
          return [alegedProjectRoot, 'package.json']
        endif
      endif
    endif
    let l:cwd = resolve(l:cwd . '/..')
  endwhile
  return []
endfunction

" Used by other plugins to get the esy path. Do not break!
function! esy#getEsyPath()
  return empty(g:reasonml_esy_discovered_path) ? "esy" : g:reasonml_esy_discovered_path
endfunction

"
" Allows defering of running commands the first time until built once. Don't
" start the merlin process until you've built it etc. Returns empty array for
" invalid projects, else returns an array with:
" [projectName, packageText, projectStatus, projectRoot].
" projectStatus is the result of esy status
"
function! esy#FetchProjectInfoForProjectRoot(projectRoot)
  if a:projectRoot == []
    return []
  else
    let cmd = esy#cdCommand(a:projectRoot, esy#getEsyPath() . ' status')
    let ret = xolox#misc#os#exec({'command': cmd, 'check': 0})
    let statObj = s:jsonObjOr(ret, g:esy#errCantStatus)
    if esy#matchError(statObj, g:esy#errCantStatus)
      if !b:did_warn_cant_status
        call console#Error("Failed to call esy status on project")
        let b:did_warn_cant_status = 1
        return []
      endif
    endif
    if !statObj['isProject']
      return []
    else
      if statObj['isProjectReadyForDev']
        let l:status = 'built'
      else
        if statObj['isProjectFetched']
          let l:status = 'installed'
        else
          let l:status = 'uninitialized'
        endif
      endif
      let l:jsonPath = resolve(a:projectRoot[0] . '/' . a:projectRoot[1])
      let l:jsonPathReadable = filereadable(l:jsonPath)
      if l:jsonPathReadable
        let l:packageText = join(readfile(l:jsonPath), "\n")
      else
        let l:packageText = ""
      endif
      return [esy#ProjectNameOfPackageText(l:packageText), l:packageText, statObj, a:projectRoot]
    endif
  endif
endfunction

" Only Use For Debugging!
function! esy#CmdFetchProjectInfo()
  return esy#FetchProjectInfoForProjectRoot(esy#FetchProjectRoot())
endfunction

function! esy#UpdateLastError(ret)
  let g:esy_last_failed_stderr = join(a:ret['stderr'], "\n")
  let g:esy_last_failed_stdout = join(a:ret['stdout'], "\n")
  let g:esy_last_failed_cmd = a:ret['command']
endfunction

function! esy#ProjectEnv(projectRoot)
  if empty(a:projectRoot) || empty(g:reasonml_esy_discovered_path)
    return {}
  endif
  let ret = xolox#misc#os#exec({'command': 'cd ' . a:projectRoot[0] . ' && esy command-env --json', 'check': 0})
  if ret['exit_code'] != 0
    call esy#UpdateLastError(ret)
    return -1
  else
    " Relying on the fact that our JSON we output is largely valid vimscript!
    let lines = join(ret['stdout'], " ")
    let jsonParse = eval(lines)
    return jsonParse
  endif
endfunction

" TODO: Allow supplying an arbitrary buffer nr.
function! esy#FetchProjectRootCached()
  let l:cacheKey = esy#GetCacheKeyCurrentBuffer()
  if has_key(g:esyProjectRootCacheByBuffer, l:cacheKey)
    let projectRoot = g:esyProjectRootCacheByBuffer[l:cacheKey]
    if !empty(projectRoot)
      return projectRoot
    else
      return []
    endif
  else
    if g:esyLogCacheMisses
      echomsg "Cache miss locate " . l:cacheKey
    endif
    let projectRoot = esy#FetchProjectRoot()
    " Always update an entry keyed by the project root dir. That way we know
    " project root dir always has the freshest result. It can be prefered even
    " any time you get a cache hit above. This means any time you open up a
    " new file in a project, you refresh all the other files' caches
    " in that project implicitly.
    if !empty(projectRoot)
      let g:esyProjectRootCacheByBuffer[l:cacheKey] = projectRoot
      " Let's also remove any entry in the cache for project status when new
      " files' locateds are discovered. Just as a convenient time to purge -
      " open a new untracked buffer in your project to refresh it. Close and
      " reopen one etc.
      let key = esy#GetCacheKeyProjectRoot(projectRoot)
      if has_key(g:esyProjectInfoCacheByProjectRoot, key)
        unlet g:esyProjectInfoCacheByProjectRoot[key]
      endif
      return projectRoot
    else
      let g:esyProjectRootCacheByBuffer[l:cacheKey] = projectRoot
      return projectRoot
    endif
  endif
endfunction

" Allows deferring of running commands the first time until built once. Don't
" start the merlin process until you've built it etc. Returns empty array for
" invalid projects. Returns either 'no-esy-field', 'uninitialized',
" 'installed', 'built'.
function! esy#FetchProjectInfoForProjectRootCached(projectRoot)
  if a:projectRoot == []
    return []
  else
    let l:cacheKey = esy#GetCacheKeyProjectRoot(a:projectRoot)
    if has_key(g:esyProjectInfoCacheByProjectRoot, l:cacheKey)
      return g:esyProjectInfoCacheByProjectRoot[l:cacheKey]
    else
      if g:esyLogCacheMisses
        echomsg "Cache miss project info " . l:cacheKey
      endif
      let info = esy#FetchProjectInfoForProjectRoot(a:projectRoot)
      let g:esyProjectInfoCacheByProjectRoot[l:cacheKey] = info
      return info
    endif
  endif
endfunction

function! esy#CmdResetEditorCache()
  let g:esyProjectRootCacheByBuffer={}
  let g:esyProjectInfoCacheByProjectRoot={}
  let g:esyLocatedBinaryByProjectRoot={}
  return "Reset editor cache"
endfunction


" Execution:
" ======================================================================
" These functions are also slower, and will never use the cache, so only
" perform them every once in a while, on demand etc.
" ======================================================================

function! esy#TrySetGlobalEsyBinaryOrWarn()
  if empty(g:reasonml_esy_discovered_path)
    let res = esy#LocateEsyBinary(g:reasonml_esy_path)
    if esy#isError(res)
      if !b:did_warn_no_esy_yet
        let msg = esy#matchError(res, g:esy#errVersionTooOld) ? 'Your esy version is too old. Upgrade to the latest esy.' : 'Cannot locate globally installed esy binary - install with npm install -g esy.'
        let b:did_warn_no_esy_yet = 1
        call console#Warn(msg)
      endif
      let g:reasonml_esy_discovered_path=""
    else
      let g:reasonml_esy_discovered_path = res
    endif
  endif
endfunction

function! esy#cdCommand(projectRoot, cmd)
  let osChangeDir = s:is_win ? ('CD /D ' . a:projectRoot[0] . ' &') : ('cd ' . a:projectRoot[0] . ' &&')
  return osChangeDir.' '.a:cmd
endfunction

" TODO: Make all dependencies explicit inputs to this so we don't have to
" constantly recheck arguments everywhere. (g:esy#EsyLocateBinary)
function! esy#ProjectExecForProjectRoot(projectRoot, cmd, input)
  if a:projectRoot == [] || empty(g:reasonml_esy_discovered_path)
    let msg = (a:projectRoot == []) ? 'Attempting to invoke Esy project command on non esy project. ' : ''
    let msg = msg . (empty(g:reasonml_esy_discovered_path) ? 'esy does not appear to be installed on your system. It is not on your global PATH perhaps' : '')
    call console#Error(msg)
    return -1
  else
    if empty(g:reasonml_esy_discovered_path)
      call console#Error("Running command " . a:cmd . " without an esy")
    endif
    let projectInfo = esy#FetchProjectInfoForProjectRoot(a:projectRoot)
    let projectStatus = esy#ProjectStatusOfProjectInfo(projectInfo)
    if (!projectStatus['isProjectReadyForDev'])
      throw "called esy#FetchProjectInfoForProjectRoot on a project not installed and built " . a:projectRoot[0]
    else
      let ret = xolox#misc#os#exec({'command': esy#cdCommand(a:projectRoot, g:reasonml_esy_discovered_path.' '.a:cmd), 'stdin': a:input, 'check': 0})
    endif
  endif
  if ret['exit_code'] != 0
    call esy#UpdateLastError(ret)
  endif
  return ret
endfunction

" Built in esy commands such as esy ls-builds
function! esy#__FilterTermCodes(str)
  return substitute(a:str, "[[0-9]*m", "", "g")
endfunction

" Built in esy commands such as esy ls-builds
function! esy#ProjectCommandForProjectRoot(projectRoot, cmd)
  if a:projectRoot == []
    return "You are not in an esy project. Open a file in an esy project, or cd to one."
  endif
  if empty(g:reasonml_esy_discovered_path)
    return "esy doesn't appear to be installed on your system. It's not in your global PATH probably."
  endif
  let res = xolox#misc#os#exec({'command': 'esy ' . a:cmd, 'check': 0})
  if res['exit_code'] == 0
    return esy#__FilterTermCodes(join(res['stdout'], "\n"))
  else
    call esy#UpdateLastError(res)
    if has_key(res, 'command') && type(res) == v:t_list
      let g:esy_last_failed_cmd = join(res['command'], "\n")
    else
      if has_key(res, 'command') && type(res) == v:t_string
        let g:esy_last_failed_cmd = res['command']
      else
        let g:esy_last_failed_cmd = 'not-recorded'
      endif
    endif
    return "Command failed: " . a:cmd . " - Troubleshoot :EsyRecentError"
  endif
endfunction

function! esy#EnvDictFor(projectRoot,file)
endfunction

function! esy#EnvDict()
  let projectRoot = esy#FetchProjectRoot()
  return esy#EnvDictFor(projectRoot)
endfunction

" Return empty string if not a valid esy project (malformed JSON etc). Returns
" "unnamed" if not named. Else the project name.
function! esy#ProjectName()
  let projectRoot = esy#FetchProjectRoot()
  if projectRoot == []
  else
    let projectInfo= esy#FetchProjectInfoForProjectRoot(projectRoot)
    return esy#ProjectNameOfProjectInfo(projectInfo)
  endif
endfunction

" TOOD: Clean up a lot of this stuff with optional args:
" https://vi.stackexchange.com/a/11548
function! esy#ProjectExec(cmd)
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectExecForProjectRoot(projectRoot, a:cmd, '')
endfunction

function! s:platformLocatorCommand(name)
  return s:is_win ? ('where ' . a:name) : ('which ' . a:name)
endfunction

" Error codes - all negative numbers.
let g:esy#errNoEsyBinary={'thisIsAnError': 1, 'code': 1}
let g:esy#errVersionTooOld={'thisIsAnError': 1, 'code': 2}
let g:esy#errCantStatus={'thisIsAnError': 1, 'code': 3}
function! esy#isError(ret)
  return type(a:ret) == v:t_dict && has_key(a:ret, 'thisIsAnError')
endfunction

function! esy#matchError(ret, err)
  return type(a:err) == v:t_dict && has_key(a:err, 'thisIsAnError') && type(a:ret) == v:t_dict && has_key(a:ret, 'thisIsAnError') && a:ret['code'] == a:err['code']
endfunction

" Locates the esy binary with optional user override. Uses the platform's
" default executable system (on windows, that's cmd.exe and `where`') within
" the current esy project if possible.
" Returns g:esy#err codes as above.
function! esy#LocateEsyBinary(override)
  if empty(a:override)
    let binLoc = xolox#misc#os#exec({'command': s:platformLocatorCommand("esy"), 'check': 0})
    let binLoc = s:resultFirstLineOr(binLoc, g:esy#errNoEsyBinary)
    if esy#matchError(binLoc, g:esy#errNoEsyBinary)
      return g:esy#errNoEsyBinary
    endif
  else
    let binLoc = a:override
  endif
  let versionRes = xolox#misc#os#exec({'command': binLoc . " --version", 'check': 0})
  let versionRes = s:resultFirstLineOr(versionRes, g:esy#errNoEsyBinary)
  " Can't invoke --version for some reason.
  if esy#matchError(versionRes, g:esy#errNoEsyBinary)
    return g:esy#errNoEsyBinary
  else
    let matches = matchlist(versionRes, "\\([0-9]\\+\\)\\.\\([0-9]\\+\\)\\.\\([0-9]\\+\\)")
    if empty(matches)
      return g:esy#errNoEsyBinary
    endif
    let major = matches[1]
    let minor = matches[2]
    let patch = matches[3]
    " The esy status command was added in 0.4.4.
    if major >=0 && ((minor == 4 && patch >= 4) || minor > 4)
      return binLoc
    else
      return g:esy#errVersionTooOld
    endif
  endif
endfunction

" Locates a binary by name, for the platform's default executable system (on
" windows, that's cmd.exe and `where`') within the current esy project if
" possible.
" This should probably be added to xolox's shell libary.
" Returns -1 if missing because people would misuse a return value of zero.
function! esy#EsyLocateBinary(name, projectRoot, projectInfo)
  let cmd = s:platformLocatorCommand(a:name)
  let res = esy#ProjectExecForProjectRoot(a:projectRoot, cmd, '')
  return s:resultFirstLineOr(res, -1)
endfunction

" Not only uses cache to cache the project root/project info, but also stores
" the cached located binary by project root dir.  One problem is that if it
" was in the global environment, it will be picked up when queried from an
" unbuilt project, then once the project is built, it isn't refetched.
" Something should reset all caches when a project transitions from unbuilt to
" built.
function! esy#EsyLocateBinarySuperCached(name, projectRoot, projectInfo)
  let key = esy#GetCacheKeyProjectRoot(a:projectRoot)
  if has_key(g:esyLocatedBinaryByProjectRoot, key)
    return g:esyLocatedBinaryByProjectRoot[key]
  else
    let cmd = s:platformLocatorCommand(a:name)
    let res = esy#ProjectExecForProjectRoot(a:projectRoot, cmd, '')
    let ret = s:resultFirstLineOr(res, -1)
    if ret != -1 && [] != a:projectRoot
      let g:esyLocatedBinaryByProjectRoot[key] = ret
    endif
    return ret
  endif
endfunction

function! esy#GetCacheKeyCurrentBuffer()
  let l:isUnnamed=expand("%") == ''
  if l:isUnnamed
    " Expand to the current directory
    return expand("%:p:h")
  else
    return expand("%:p")
  endif
endfunction

function! esy#GetCacheKeyProjectRoot(projectRoot)
  return a:projectRoot[0] . '-' . a:projectRoot[1]
endfunction


" The commands exposed as :EsyCommandName args


" Loose form - doesn't require esy project.  Problem is this doesn't use the
" cache, whereas other commands will. Might be misleading.
" #choppingblock
function! esy#CmdEsyExec(cmd)
  let projectRoot = esy#FetchProjectRoot()
  let res = esy#ProjectExecForProjectRoot(projectRoot, a:cmd, '')
  return esy#ProjectExecForProjectRoot(projectRoot, a:cmd, '')
  if res['exit_code'] == 0
    call console#Info(join(res['stdout'], "\n"))
  else
    call console#Error(join(res['stderr'], "\n"))
  endif
endfunction

function! esy#CmdEsyRecentError()
  let str = [
        \ "[stderr]: " . g:esy_last_failed_stderr,
        \ "[stdout]: " . g:esy_last_failed_stdout,
        \ "[command]: " . g:esy_last_failed_cmd
        \ ]
  echomsg join(str, " ")
endfunction

" Built in esy commands such as esy ls-builds
function! esy#CmdEsyLibs()
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectCommandForProjectRoot(projectRoot, "ls-libs")
endfunction

" Built in esy commands such as esy ls-builds
function! esy#CmdBuilds()
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectCommandForProjectRoot(projectRoot, "ls-builds")
endfunction

function! esy#CmdEsyModules()
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectCommandForProjectRoot(projectRoot, "ls-modules")
endfunction


" Should render dynamic help based on the current project
" settings/config/state.
function! esy#CmdEsyHelp()
  return "Run :help vim-reason for help using esy from within vim"
endfunction
