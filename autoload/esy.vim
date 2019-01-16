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

function! esy#FetchLocalEsyBinaryLoc(projectRoot)
  if a:projectRoot == []
    return -1
  endif
  let localEsyPath = resolve(a:projectRoot[0] . "/esy")
  let isExecutable = executable(localEsyPath)
  if isExecutable
    return localEsyPath
  else
    return -1
  endif
endfunction


" Checks a local esy version at least _once_. It's too slow to do this
" all the time, so hopefully once is enough.
function! esy#SetLocalEsyIfNecessary(projectRoot)
  if !exists('b:reasonml_local_esy_checked') || !b:reasonml_local_esy_checked
    " We'll retry the global binary just in case they upgraded / installed it
    " since last time they opened a buffer. We won't recheck again in the event
    " they downgrade to an invalid version though.
    let ret = esy#FetchLocalEsyBinaryLoc(a:projectRoot)
    if ret != -1
      let b:reasonml_esy_discovered_path = ret
      let b:reasonml_esy_discovered_version = esy#FetchVersion(ret)
    else
      let b:reasonml_esy_discovered_path = ''
      let b:reasonml_esy_discovered_version = {}
    endif
  endif
  let b:reasonml_local_esy_checked = 1
endfunction

function! esy#SetGlobalEsy()
  if empty(g:reasonml_esy_discovered_path) || !esy#IsVersionValidAndNewEnough(g:reasonml_esy_discovered_version)
    " We'll retry the global binary just in case they upgraded / installed it
    " since last time they opened a buffer. We won't recheck again in the event
    " they downgrade to an invalid version though.
    let ret = esy#FetchGlobalEsyBinaryLoc()
    if ret != -1
      let g:reasonml_esy_discovered_path = ret
      let g:reasonml_esy_discovered_version = esy#FetchVersion(ret)
    else
      let g:reasonml_esy_discovered_path = ''
      let g:reasonml_esy_discovered_version = {}
    endif
  endif
endfunction


" Used by other plugins to get the esy path. Do not break!
function! esy#getBestEsyPathForProject(projectRoot)
  call esy#SetLocalEsyIfNecessary(a:projectRoot)
  if !empty(b:reasonml_esy_discovered_path) && esy#IsVersionValidAndNewEnough(b:reasonml_esy_discovered_version)
    return b:reasonml_esy_discovered_path
  elseif !empty(g:reasonml_esy_discovered_path) && esy#IsVersionValidAndNewEnough(g:reasonml_esy_discovered_version)
    return g:reasonml_esy_discovered_path
  else
    return ""
  endif
endfunction

" Used by other plugins to get the esy path. Do not break!
" Returns the version that is new enough to be used with the vim plugin.
function! esy#getBestEsyVersionForProject(projectRoot)
  call esy#SetLocalEsyIfNecessary(a:projectRoot)
  if !empty(b:reasonml_esy_discovered_path) && esy#IsVersionValidAndNewEnough(b:reasonml_esy_discovered_version)
    return b:reasonml_esy_discovered_version
  elseif !empty(g:reasonml_esy_discovered_path) && esy#IsVersionValidAndNewEnough(g:reasonml_esy_discovered_version)
    return g:reasonml_esy_discovered_version
  else
    return ""
  endif
endfunction



function! esy#WarnAboutMissingEsy()
  if !g:did_warn_no_esy_yet
    if !empty(b:reasonml_esy_discovered_path) && !esy#IsVersionValidAndNewEnough(b:reasonml_esy_discovered_path)
      call console#Error("The local project's esy needs to be updated to the latest esy:" . b:reasonml_esy_discovered_version)
      let g:did_warn_no_esy_yet = 1
    elseif !empty(g:reasonml_esy_discovered_path) && !esy#IsVersionValidAndNewEnough(g:reasonml_esy_discovered_version)
      call console#Error("The global esy needs to be updated to the latest esy:" . g:reasonml_esy_discovered_path)
      let g:did_warn_no_esy_yet = 1
    endif
  endif
endfunction

" If returns false, it might still support it, we just don't know the version
" so can't even check.
function! esy#DefinitelySupportsExecCommand(version)
  " Actually on 0.4.9, command-exec isn't including the dev environment and
  " adjusting the envspec causes it to fail
  return 0
  if empty(a:version)
    return 0
  else
    return a:version['minor'] >= 5
  endif
endfunction

" Form of `esy my shell command` that does not ever trigger builds and doesn't
" require symlinks. Not for use with `esy status`/`esy build` etc.
function! esy#getBestEsyShellCommand(projectRoot, cmd)
  let esyPath = esy#getBestEsyPathForProject(a:projectRoot)
  let esyVersion = esy#getBestEsyVersionForProject(a:projectRoot)
  if esy#DefinitelySupportsExecCommand(esyVersion)
    return " esy exec-command --include-build-env --include-current-env --envspec 'dependencies(self)+devDependencies(self)' -p " . a:projectRoot[1] . " " . a:cmd
  else
    return " esy " . a:cmd
  endif
endfunction

"
" Allows defering of running commands the first time until built once. Don't
" start the merlin process until you've built it etc. Returns empty array for
" invalid projects, else returns an array with:
" [projectName, packageText, projectStatus, projectRoot].
" projectStatus is the result of esy status
"

" esy#FetchProjectInfoForProjectRoot allows projects to include a symlink to
" their prefered version of esy in their project root.
function! esy#FetchProjectInfoForProjectRoot(projectRoot)
  if a:projectRoot == []
    return []
  else
    let cmd = esy#cdCommand(a:projectRoot, esy#getBestEsyPathForProject(a:projectRoot) . " status")
    let ret = xolox#misc#os#exec({'command': cmd, 'check': 0})
    let statObj = s:jsonObjOr(ret, g:esy#errCantStatus)
    if esy#matchError(statObj, g:esy#errCantStatus)
      call esy#UpdateLastError(ret)
      if !exists('b:did_warn_cant_status') || !b:did_warn_cant_status
        " This entire windows branch can be removed when everyone has moved to
        " esy >= 0.5.1.
        if xolox#misc#os#is_win()
          let v = !empty(b:reasonml_esy_discovered_version) ? b:reasonml_esy_discovered_version : (!empty('g:reasonml_esy_discovered_version') ? g:reasonml_esy_discovered_version : '')
          " If pre 0.5.1 esy, you couldn't even do --version so we have no
          " version. Also, we had had to run editor commands in admin mode so
          " no version is a good sign you need to run in admin mode on
          " windows.
          if empty(v)
            call console#Error("Failed to esy status project. esy < 0.5.0 requires running your Windows editor in admin mode")
          else
            call console#Error("Failed to call esy status on project. ")
          endif
        else
          call console#Error("Failed to call esy status on project")
        endif
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
  let projectRoot = esy#FetchProjectRoot()
  let projectInfo = esy#FetchProjectInfoForProjectRoot(projectRoot)
  if esy#UserValidateIsReadyProject(projectRoot, projectInfo, "fetch project info")
    " Otherwise errors would have been logged already
    call console#Info(projectInfo)
  endif
endfunction

function! esy#UpdateLastError(ret)
  let g:esy_last_failed_stderr = join(a:ret['stderr'], "\n")
  let g:esy_last_failed_stdout = join(a:ret['stdout'], "\n")
  let g:esy_last_failed_cmd = a:ret['command']
endfunction

function! esy#ProjectEnv(projectRoot)
  if empty(a:projectRoot) || empty(g:reasonml_esy_discovered_path)
    call console#Error("Should not be calling ProjectEnv without an esy project and esy")
    return
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

function! esy#ProjectEnvCached(projectRoot)
  let l:cacheKey = esy#GetCacheKeyProjectRoot(a:projectRoot)
  if has_key(g:esyEnvCacheByProjectRoot, l:cacheKey)
    return g:esyEnvCacheByProjectRoot[l:cacheKey]
  else
    if g:esyLogCacheMisses
      call console#Info("Cache miss env " . l:cacheKey)
    endif
    let env = esy#ProjectEnv(a:projectRoot)
    let g:esyEnvCacheByProjectRoot[l:cacheKey] = env
    return env
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
      call console#Info("Cache miss project root " . l:cacheKey)
    endif
    let projectRoot = esy#FetchProjectRoot()
    " Always update an entry keyed by the project root dir. That way we know
    " project root dir always has the freshest result. It can be prefered even
    " any time you get a cache hit above. This means any time you open up a
    " new file in a project, you refresh all the other files' caches
    " in that project implicitly.
    if !empty(projectRoot)
      let g:esyProjectRootCacheByBuffer[l:cacheKey] = projectRoot
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
        call console#Info("Cache miss project info " . l:cacheKey)
      endif
      let info = esy#FetchProjectInfoForProjectRoot(a:projectRoot)
      let g:esyProjectInfoCacheByProjectRoot[l:cacheKey] = info
      return info
    endif
  endif
endfunction

function! esy#CmdResetCacheAndReloadBuffer()
  let g:esyProjectRootCacheByBuffer={}
  let g:esyProjectInfoCacheByProjectRoot={}
  let g:esyLocatedBinaryByProjectRoot={}
  let g:esyEnvCacheByProjectRoot={}
  if &filetype=="reason" || &filetype=="ocaml"
    call reason#LoadBuffer()
    call console#Info("Reset editor cache and reloaded current buffer")
  else
    call console#Info("Reset editor cache. Now reload individual buffers")
  endif
endfunction


" Execution:
" ======================================================================
" These functions are also slower, and will never use the cache, so only
" perform them every once in a while, on demand etc.
" ======================================================================

" Locates the esy binary. Uses the platform's default executable system (on
" windows, that's cmd.exe and `where`') within the current esy project if
" possible.  Returns g:esy#err codes as above.
function! esy#FetchGlobalEsyBinaryLoc()
  let binLoc = xolox#misc#os#exec({'command': s:platformLocatorCommand("esy"), 'check': 0})
  return s:resultFirstLineOr(binLoc, -1)
endfunction

function! esy#cdCommand(projectRoot, cmd)
  " We could try something like this to trigger elevated prompt: powershell -c start -verb runas notepad.exe
  let osChangeDir = s:is_win ? ('CD /D ' . a:projectRoot[0] . ' &') : ('cd ' . a:projectRoot[0] . ' &&')
  return osChangeDir.' '.a:cmd
endfunction

" Call from workflows initiated by user action (describe the action in
" a:verbDescription). For example, this is the validation you'd use if a user
" run `:EsyExec` or `:ReasonPrettyPrint` etc.
function! esy#UserValidateIsReadyProject(projectRoot, projectInfo, verbDescription)
  if empty(a:projectRoot) || empty(g:reasonml_esy_discovered_path)
    let msg = (a:projectRoot == []) ? 'Cannot ' . a:verbDescription . ' on non esy project. ' : 'Cannot ' . a:verbDescription . ' because '
    let msg = msg . (empty(g:reasonml_esy_discovered_path) ? 'esy does not appear to be installed on your system. Is it in your global PATH?' : '')
    call console#Error(msg)
    return 0
  endif
  if empty(a:projectInfo)
    call console#Error("Cannot " . a:verbDescription . " without a esy installed")
    return 0
  endif
  let projectStatus = esy#ProjectStatusOfProjectInfo(a:projectInfo)
  if empty(projectStatus) || !projectStatus['isProject']
    call console#Error("Cannot " . a:verbDescription . " - not a valid esy project at " . projectRoot[0])
    return 0
  endif
  if (!projectStatus['isProjectReadyForDev'])
    call console#Error("Cannot " . a:verbDescription . " until you run esy at " . a:projectRoot[0])
    return 0
  else
    return 1
  endif
endfunction

" Executes a shell command in a prepared project or fails if the project is
" not ready.
" Requires that all inputs already be valid and represent a known, prepared
" project.
function! esy#ProjectShellExecForReadyProject(projectRoot, projectInfo, cmd, input)
  let projectStatus = esy#ProjectStatusOfProjectInfo(a:projectInfo)
  " This should never happen. If so it's a bug in the plugin.
  if (!projectStatus['isProjectReadyForDev'])
    throw "called esy#FetchProjectInfoForProjectRoot on a project not installed and built " . a:projectRoot[0]
  else
    let ret = xolox#misc#os#exec({'command': esy#cdCommand(a:projectRoot, esy#getBestEsyShellCommand(a:projectRoot, a:cmd)), 'stdin': a:input, 'check': 0})
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

" Built in esy commands such as esy ls-builds that we expose as `:EsyFoo` use
" this. These commands don't require that the project be completely ready.
function! esy#ProjectBuiltInCommandForProjectRoot(projectRoot, cmd)
  let esyPath = esy#getBestEsyPathForProject(a:projectRoot)
  if empty(esyPath)
    call console#Error("esy doesn't appear to be installed on your system. Is it in your global PATH?")
    return
  endif
  if a:projectRoot == []
    call console#Error("You are not in an esy project. Open a file in an esy project, or cd to one.")
    return
  endif
  let cmd = esy#cdCommand(a:projectRoot, esyPath . ' ' . a:cmd)
  let res = xolox#misc#os#exec({'command': cmd, 'check': 0})
  if res['exit_code'] == 0
    call console#Info(esy#__FilterTermCodes(join(res['stdout'], "\n")))
  else
    call esy#UpdateLastError(res)
    if has_key(res, 'command') && type(res) == g:v_t_list
      let g:esy_last_failed_cmd = join(res['command'], "\n")
    else
      if has_key(res, 'command') && type(res) == g:v_t_string
        let g:esy_last_failed_cmd = res['command']
      else
        let g:esy_last_failed_cmd = 'not-recorded'
      endif
    endif
    call console#Error("Command failed: " . a:cmd . " - Troubleshoot :EsyRecentError")
  endif
endfunction

function! s:platformLocatorCommand(name)
  return s:is_win ? ('where ' . a:name) : ('which ' . a:name)
endfunction

" Error codes:
" =============
" For checking result of esy global binary.
let g:esy#errNoEsyBinary={'thisIsAnError': 1, 'code': 1}
let g:esy#errVersionTooOld={'thisIsAnError': 1, 'code': 2}
let g:esy#errCantStatus={'thisIsAnError': 1, 'code': 3}

" Project loading/updating states.

function! esy#isError(ret)
  return type(a:ret) == g:v_t_dict && has_key(a:ret, 'thisIsAnError')
endfunction

function! esy#matchError(ret, err)
  return type(a:err) == g:v_t_dict && has_key(a:err, 'thisIsAnError') && type(a:ret) == g:v_t_dict && has_key(a:ret, 'thisIsAnError') && a:ret['code'] == a:err['code']
endfunction

function! esy#IsVersionValidAndNewEnough(version)
  if empty(a:version)
    return 0
  endif
  " The esy status command was added in 0.4.4.
  if a:version['major'] >=0 && ((a:version['minor'] == 4 && a:version['patch'] >= 4) || a:version['minor'] > 4)
    return 1
  else
    return 0
  endif
endfunction

function! esy#FetchVersion(pathToEsy)
  let versionRes = xolox#misc#os#exec({'command': a:pathToEsy . " --version", 'check': 0})
  let versionRes = s:resultFirstLineOr(versionRes, {})
  " Can't invoke --version for some reason.
  if empty(versionRes)
    return versionRes
  endif
  let matches = matchlist(versionRes, "\\([0-9]\\+\\)\\.\\([0-9]\\+\\)\\.\\([0-9]\\+\\)")
  if empty(matches)
    return {}
  endif
  let major = matches[1]
  let minor = matches[2]
  let patch = matches[3]
  return {'major': major, 'minor': minor, 'patch': patch}
endfunction



" Locates a binary by name, for the platform's default executable system (on
" windows, that's cmd.exe and `where`') within the current esy project if
" possible.
" This should probably be added to xolox's shell libary.
" Returns -1 if missing because people would misuse a return value of zero.
" Note: Requires that the project be "ready" for development.
function! esy#EsyLocateBinaryForReadyProject(name, projectRoot, projectInfo)
  let cmd = s:platformLocatorCommand(a:name)
  let res = esy#ProjectShellExecForReadyProject(a:projectRoot, a:projectInfo, cmd, '')
  return s:resultFirstLineOr(res, -1)
endfunction

" Not only uses cache to cache the project root/project info, but also stores
" the cached located binary by project root dir.  One problem is that if it
" was in the global environment, it will be picked up when queried from an
" unbuilt project, then once the project is built, it isn't refetched.
" Something should reset all caches when a project transitions from unbuilt to
" built.
" Note: Requires that the project be "ready" for development.
function! esy#EsyLocateBinaryForReadyProjectCached(name, projectRoot, projectInfo)
  let key = esy#GetCacheKeyProjectRoot(a:projectRoot)
  if has_key(g:esyLocatedBinaryByProjectRoot, key)
    let binCache = g:esyLocatedBinaryByProjectRoot[key]
  else
    let binCache = {}
    let g:esyLocatedBinaryByProjectRoot[key] = binCache
  endif
  if has_key(binCache, key)
    return binCache[key]
  else
    if g:esyLogCacheMisses
      call console#Info("Cache miss locate binary (" . a:name . ") " . key)
    endif
    let ret = esy#EsyLocateBinaryForReadyProject(a:name, a:projectRoot, a:projectInfo)
    let binCache[key] = ret
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
  let projectInfo = esy#FetchProjectInfoForProjectRoot(projectRoot)
  if esy#UserValidateIsReadyProject(projectRoot, projectInfo, "execute command")
    let res = esy#ProjectShellExecForReadyProject(projectRoot, projectInfo, a:cmd, '')
    if res['exit_code'] == 0
      call console#Info(join(res['stdout'], "\n"))
    else
      call console#Error(join(res['stderr'], "\n"))
    endif
  endif
endfunction

function! esy#CmdEsyPleaseShowMostRecentError()
  let str = [
        \ "[stderr]: " . g:esy_last_failed_stderr,
        \ "[stdout]: " . g:esy_last_failed_stdout,
        \ "[command]: " . g:esy_last_failed_cmd
        \ ]
  call console#Info(join(str, " "))
endfunction

" Built in esy commands such as esy ls-builds
function! esy#CmdEsyLibs()
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectBuiltInCommandForProjectRoot(projectRoot, "ls-libs")
endfunction

" Built in esy commands such as esy ls-builds
function! esy#CmdBuilds()
  let projectRoot = esy#FetchProjectRoot()
  call esy#ProjectBuiltInCommandForProjectRoot(projectRoot, "ls-builds")
endfunction

" Built in esy commands such as esy ls-builds
function! esy#CmdStatus()
  let projectRoot = esy#FetchProjectRoot()
  call esy#ProjectBuiltInCommandForProjectRoot(projectRoot, "status")
endfunction


function! esy#CmdEsyModules()
  let projectRoot = esy#FetchProjectRoot()
  call esy#ProjectBuiltInCommandForProjectRoot(projectRoot, "ls-modules")
endfunction


" Should render dynamic help based on the current project
" settings/config/state.
function! esy#CmdEsyHelp()
  call console#Info("Run :help vim-reasonml for help using esy from within vim")
endfunction
