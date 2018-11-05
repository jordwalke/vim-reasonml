" trim excess whitespace
function! s:trim(txt)
  return substitute(a:txt, '^\n*\s*\(.\{-}\)\n*\s*$', '\1', '')
endfunction
let g:esy_last_failed_stderr = ""
let g:esy_last_failed_cmd = ""
let g:esy_last_cmd_prefix = ""

" Will log the stderr to g:esy_last_failed_stderr for debugging/inspecting.
function! s:resultStdoutOr(res, orThis)
  if a:res['exit_code'] == 0
    return join(a:res['stdout'], "\n")
  else
    return a:orThis
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

" TODO:
" - Keep track of buffer local variables, invalidated with buffer file path
"   changes.
"   - b:esyProjectType:
"     if package.json but no esy field then "npm"
"     if esy.json or pacakge.json with esy field: "esy"
"     else "other"
"   Everything Else Only Applies to esyProjectType="esy"
"   ---------------------------------------------------
"   - b:esyProjectStatus: "uninitialized" => "installed" => "dependencies-built"
"       exists(node_modules) && !exists(node_modules/.cache/_esy/build/bin/command-env) => "[not built]"
"       !exists(node_modules) => "[not installed]"
"   - b:esyProjectName: project-name
"   - b:esyProjectPath: /path/to/project
"   - b:esyProjectConfigName: esy.json/package.json
"   - b:lastFilePath (in case you move the file in the buffer).
"   - b:esyLastTimeCheckedProjectName
"   - b:esyLastTimeCheckedEsyEnvFile
"   - b:esyEnvContents

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
    echoms "Someone is passing empty info to GetProjectStatus"
    return ''
  else
    return a:info[0]
  endif
endfunction

function! esy#ProjectStatusOfProjectInfo(info)
  if a:info == []
    echoms "Someone is passing empty info to GetProjectStatus - returning invalid project status"
    return 'invalid'
  else
    return a:info[2]
  endif
endfunction



" Fetching Commands:
" ======================================================================
" Expensive, Only Do Once In While. Always up to date.
" ======================================================================

" Returns env object with esy project environment.
" function! esy#FetchEnv_(useCache)
"   let singleQuote="'"
"   " from:
"   " substitute(substitute(string,"'","''","g"),'^.*$','''\0''')
"   let replaceSingleQuotesInVar = "substitute(submatch(2),\"'\",\"''\",\"g\")"
"   let l:envResult = ''
"   if a:useCache
"     let l:envResult = s:resultStdoutOr(esy#Exec("env"), '')
"   else
"     let l:envResult = s:resultStdoutOr(esy#ExecCached("env"), '')
"   endif

"   let rows = substitute(
"     \ l:envResult,
"     \ '\([a-zA-Z0-9_!:\(\)]\+\)=\([^\n]*\)',
"     \ '\=singleQuote . submatch(1) . singleQuote . ":" . singleQuote . ' . replaceSingleQuotesInVar . ' . singleQuote . ","',
"     \ 'g'
"     \ )
"   " If evaling, need to remove newlines
"   let rowsOneLine = substitute(rows, "\n", " ", "g")
"   let object = '{' . rowsOneLine . '}'
"   " echo 'returning dict:' . object
"   return eval(object)
" endfunction

" function! esy#FetchEnv()
"   return esy#FetchEnv_(0)
" endfunction
" function! esy#FetchEnvCached()
"   return esy#FetchEnv_(1)
" endfunction


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

"
" Allows defering of running commands the first time until built once. Don't
" start the merlin process until you've built it etc. Returns empty array for
" invalid projects, else returns an array with:
" [projectName, packageText, projectStatus, projectRoot].
" projectStatus is either 'invalid', 'no-esy-field', 'uninitialized', 'installed', 'built' for
" projectStatus (`no-esy-field` means it's not an esy enabled package.json project,
" but it is a package.json project.)
"
" If it is 'no-esy-field', then it should be treated like a non-esy project.
function! esy#FetchProjectInfoForProjectRoot(projectRoot)
  if a:projectRoot == []
    return []
  else
    let l:jsonPath = resolve(a:projectRoot[0] . '/' . a:projectRoot[1])
    let l:jsonPathReadable = filereadable(l:jsonPath)
    if l:jsonPathReadable
      let l:packageText = join(readfile(l:jsonPath), "\n")

      let l:status = 'invalid' " Default to None
      let l:hasEsyFieldInPackageText = esy#HasEsyField(l:packageText)
      if l:hasEsyFieldInPackageText
        if isdirectory(a:projectRoot[0] . '/node_modules')
          let l:commandEnv=a:projectRoot[0] . '/node_modules/.cache/_esy/build/bin/command-env'
          if filereadable(l:commandEnv)
            let l:status = "built"
          else
            let l:status = "installed"
          endif
        else
          let l:status = "uninitialized"
        endif

      else
        let l:status = 'no-esy-field'
      endif
      return [esy#ProjectNameOfPackageText(l:packageText), l:packageText, l:status, a:projectRoot]
    else
      return []
    endif
  endif
endfunction

" Only Use For Debugging!
function! esy#FetchProjectInfo()
  return esy#FetchProjectInfoForProjectRoot(esy#FetchProjectRoot())
endfunction

" Cached Versions Of Fetching Calls:
" ======================================================================
" Cached Versions Which Can Be Used From StatusLines And Airlines.
" ======================================================================
function! esy#ProjectEnv(projectRoot)
  if empty(a:projectRoot) || a:projectRoot == []
    return 0
  endif
  let l:commandEnv=a:projectRoot[0] . '/node_modules/.cache/_esy/build/bin/command-env'
  if filereadable(l:commandEnv)
    let lines = readfile(l:commandEnv)
    let i = 0
    let vars = []
    while i < len(lines)
      let line = lines[i]
      let matchesAssign = match(line, 'export [a-zA-Z_]\+=".*"')
      if matchesAssign == 0
        let name = substitute(line, 'export \([a-zA-Z_]\+\)=".*"', '\1', 'g')
        let val = substitute(line, 'export [a-zA-Z_]\+="\(.*\)"', '\1', 'g')
        call extend(vars, [{'name': name, 'val': val}])
      endif
      let i = i+1
    endwhile
    let varDict = {}
    let i = 0
    while i < len(vars)
      let name = vars[i]['name']
      let val = vars[i]['val']
      let val = substitute(val, '$' . name, has_key(varDict, name) ? varDict[name] : s:platformVarName(name), 'g')
      let varDict[name] = val
      let i = i + 1
    endwhile
    return varDict
  else
    return {}
  endif
endfunction

" TODO: Allow supplying an arbitrary buffer nr.
function! esy#FetchProjectRootCached()
  let l:cacheKey = esy#GetCacheKeyCurrentBuffer()
  if exists('g:esyProjectRootCacheByBuffer["' . l:cacheKey . '"]')
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
      if exists('g:esyProjectInfoCacheByProjectRoot["' . projectRoot[0] . '"]')
        unlet g:esyProjectInfoCacheByProjectRoot[projectRoot[0]]
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
    let l:cacheKey = a:projectRoot[0]
    if exists('g:esyProjectInfoCacheByProjectRoot["' . l:cacheKey . '"]')
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

function! esy#Reset()
  let g:esyProjectRootCacheByBuffer={}
  let g:esyProjectInfoCacheByProjectRoot={}
endfunction

" If the path was gotten from `which` from a mingw system, map it back to a
" regular windows location. Converts from mingw's view of the disk to windows'
" Mingw understands windows as well so it would be nice if everything in mingw
" was in terms of windows, but it's not (when it comes to output)
" Converts from /c/users/foo to C:/users/foo
function! esy#mingwPathToWin(path)
  return substitute(a:path, '\/\([a-zA-Z]\)\/\(.*\)', '\u\1:/\2', '')
endfunction


" Execution:
" ======================================================================
" These functions are also slower, and will never use the cache, so only
" perform them every once in a while, on demand etc.
" ======================================================================

function! s:platformVarName(nm)
  return (s:is_win ? ('%' . a:nm . '%') : ('$' . a:nm))
endfunction

function! esy#ProjectRootCommandPrefix(projectRoot)
  let varDict = esy#ProjectEnv(a:projectRoot)

  let ks = keys(varDict)
  let cmdPrefix = []
  if s:is_win
    call extend(cmdPrefix, ["@echo off"])
  endif
  let i = 0
  while i < len(ks)
    let name = ks[i]
    let val = varDict[name]
    if s:is_win
      call extend(cmdPrefix, ['set "' . name . '=' . val . '"'])
    else
      call extend(cmdPrefix, ['export ' . name . '="' . val . '" '])
    endif
    let i = i + 1
  endwhile
  return cmdPrefix
endfunction


function! esy#ProjectExecForProjectRoot(projectRoot, cmd, mandateEsy, input)
  if a:projectRoot == []
    if a:mandateEsy
      throw "called esy#ProjectExecForProjectRoot on a non-esy project"
    else
      " Check:0 means it won't throw on non-zero return code.
      let ret = xolox#misc#os#exec({'command': a:cmd, 'input': a:input, 'check': 0})
    endif
  else
    " let l:commandEnv='C:/Users/jwalke/Desktop/command-env.bat'
    let l:commandEnv=a:projectRoot[0] . '/node_modules/.cache/_esy/build/bin/command-env'
    if a:mandateEsy && (esy#FetchProjectInfoForProjectRoot(a:projectRoot)[2] != 'built' || !filereadable(l:commandEnv))
      throw "called esy#FetchProjectInfoForProjectRoot on a project not installed and built " . a:projectRoot[0]
    else
      if s:is_win
        let tmp = tempname() . ".bat"
        let cmdPrefix = esy#ProjectRootCommandPrefix(a:projectRoot)
        call extend(cmdPrefix, [a:cmd])
        call writefile(cmdPrefix, tmp)
        let g:esy_last_cmd_prefix = cmdPrefix
        let ret = xolox#misc#os#exec({'command': tmp, 'stdin': a:input, 'check': 0})
      else
        " no need to create intermediate files for non-win
        let g:esy_last_cmd_prefix = ''
        let ret = xolox#misc#os#exec({'command': l:commandEnv . a:cmd, 'stdin': a:input, 'check': 0})
      endif
    endif
  endif
  if ret['exit_code'] != 0
    let g:esy_last_failed_stderr = join(ret['stderr'], "\n")
    let g:esy_last_failed_cmd = ret['command']
  endif
  return ret
endfunction

" Built in esy commands such as esy ls-builds
function! esy#ProjectCommandForProjectRoot(projectRoot, cmd)
  if a:projectRoot == []
    return "You are not in an esy project. Open a file in an esy project, or cd to one."
  else
    let ret = xolox#misc#os#exec({'command': 'esy ' . a:cmd, 'stdin': a:input, 'check': 0})
    if res['exit_code'] == 0
      return join(res['stdout'], "\n")
    else
      let g:esy_last_failed_stderr = join(res['stderr'], "\n")
    let g:esy_last_failed_cmd = join(res['command'], "\n")
      return "Command failed: " . a:cmd . " - Troubleshoot :echo g:esy_last_failed_stderr"
    endif
  endif
endfunction

" Built in esy commands such as esy ls-builds
function! esy#Libs()
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectCommandForProjectRoot(projectRoot, "ls-libs")
endfunction

" Built in esy commands such as esy ls-builds
function! esy#Builds()
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectCommandForProjectRoot(projectRoot, "ls-builds")
endfunction

function! esy#Modules()
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectCommandForProjectRoot(projectRoot, "ls-modules")
endfunction

function! esy#EnvDictFor(projectRoot,file)
endfunction

" TOOD: Clean up a lot of this stuff with optional args:
" https://vi.stackexchange.com/a/11548
function! esy#ProjectExec(cmd)
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectExecForProjectRoot(projectRoot, a:cmd, 1, '')
endfunction

function! esy#ProjectExecWithStdIn(cmd, input)
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectExecForProjectRoot(projectRoot, a:cmd, 1, a:input)
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

" Loose form - doesn't require esy project. Also avoids perf hit without
" needing cached call. No need to look up project info.
function! esy#Exec_(cmd, useCache)
  if a:useCache
    let projectRoot = esy#FetchProjectRootCached()
    return esy#ProjectExecForProjectRoot(projectRoot, a:cmd, 0, '')
  else
    let projectRoot = esy#FetchProjectRoot()
    return esy#ProjectExecForProjectRoot(projectRoot, a:cmd, 0, '')
  endif
endfunction

" Loose form - doesn't require esy project.
function! esy#Exec(cmd)
  return esy#Exec_(a:cmd, 0)
endfunction

" Loose form - doesn't require esy project.
function! esy#ExecCached(cmd)
  return esy#Exec_(a:cmd, 1)
endfunction

function! s:platformLocatorCommand(name)
  return s:is_win ? ('where ' . a:name) : ('which ' . a:name)
endfunction

" Locates a binary by name, for the platform's default executable system (on
" windows, that's cmd.exe and `where`')
" This should probably be added to xolox's shell libary.
" Returns -1 if missing because people would misuse a return value of zero.
function! esy#PlatformLocateBinary(name)
  let res = esy#Exec(s:platformLocatorCommand(a:name))
  return s:resultFirstLineOr(res, -1)
endfunction

" Loose form - doesn't require esy project.
function! esy#PlatformLocateBinaryCached(name)
  let res = esy#ExecCached(s:platformLocatorCommand(a:name))
  return s:resultFirstLineOr(res, -1)
endfunction

"
" Loose form - doesn't require esy project.
function! esy#ExecWithStdIn(cmd, input)
  let projectRoot = esy#FetchProjectRoot()
  return esy#ProjectExecForProjectRoot(projectRoot, a:cmd, 0, a:input)
endfunction


" Should render dynamic help based on the current project
" settings/config/state.
function! esy#HelpMe()

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
