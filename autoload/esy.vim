" trim excess whitespace
function! esy#Trim(txt)
  return substitute(a:txt, '^\n*\s*\(.\{-}\)\n*\s*$', '\1', '')
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



" Utilities:
" ======================================================================
" Operates on data structrues returned from more expensive calls.
" ======================================================================
function! esy#HasEsyField(packageText)
  return a:packageText =~ "\"esy\""
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
function! esy#FetchEnv_(useCache)
  let singleQuote="'"
  " from:
  " substitute(substitute(string,"'","''","g"),'^.*$','''\0''')
  let replaceSingleQuotesInVar = "substitute(submatch(2),\"'\",\"''\",\"g\")"
  let l:envResult = ''
  if a:useCache
    let l:envResult = esy#Exec("env")
  else
    let l:envResult = esy#ExecCached("env")
  endif

  let rows = substitute(
    \ l:envResult,
    \ '\([a-zA-Z0-9_]\+\)=\([^\n]*\)',
    \ '\=singleQuote . submatch(1) . singleQuote . ":" . singleQuote . ' . replaceSingleQuotesInVar . ' . singleQuote . ","',
    \ 'g'
    \ )
  " If evaling, need to remove newlines
  let rowsOneLine = substitute(rows, "\n", " ", "g")
  let object = '{' . rowsOneLine . '}'
  " echo 'returning dict:' . object
  return eval(object)
endfunction

function! esy#FetchEnv()
  return esy#FetchEnv_(0)
endfunction
function! esy#FetchEnvCached()
  return esy#FetchEnv_(1)
endfunction


" Returns empty list if not a valid esy project.
function! esy#FetchProjectRoot()
  let l:isUnnamed=expand("%") == ''
	let l:cwd = expand("%:p:h")
	let l:rp = fnamemodify('/', ':p')
	let l:hp = fnamemodify($HOME, ':p')
	while l:cwd != l:hp && l:cwd != l:rp
    let l:esyJsonPath = resolve(l:cwd . '/esy.json')
    if filereadable(l:esyJsonPath)
      return [l:cwd, 'esy.json']
    else
      let packageJsonPath = resolve(l:cwd . '/package.json')
      if filereadable(packageJsonPath)
        return [l:cwd, 'package.json']
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


" Execution:
" ======================================================================
" These functions are also slower, and will never use the cache, so only
" perform them every once in a while, on demand etc.
" ======================================================================

function! esy#ProjectExecForProjectRoot(projecRoot, cmd, mandateEsy, input)
  if a:projecRoot == []
    if a:mandateEsy
      throw "called esy#ProjectExecForProjectRoot on a non-esy project"
    else
      let ret = esy#Trim(system(a:cmd, a:input))
      return ret
    endif
  else
    let l:commandEnv=a:projecRoot[0] . '/node_modules/.cache/_esy/build/bin/command-env'
    if a:mandateEsy && (esy#FetchProjectInfoForProjectRoot(a:projecRoot)[2] != 'built' || !filereadable(l:commandEnv))
      throw "called esy#FetchProjectInfoForProjectRoot on a project not installed and built " . a:projecRoot[0]
    else
      if filereadable(l:commandEnv)
        let ret = esy#Trim(system('source ' . l:commandEnv . ' && ' . ' ' . a:cmd, a:input))
        return ret
      else
        let ret = esy#Trim(system(a:cmd, a:input))
        return ret
      endif
    endif
  endif
endfunction

" Built in esy commands such as esy ls-builds
function! esy#ProjectCommandForProjectRoot(projecRoot, cmd)
  if a:projecRoot == []
    return "You are not in an esy project. Open a file in an esy project, or cd to one."
  else
    let ret = esy#Trim(system("esy " . a:cmd))
    return ret
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

function! esy#EnvDictFor(projecRoot,file)
endfunction

function! esy#ProjectExec(cmd)
  let projecRoot = esy#FetchProjectRoot()
  return esy#ProjectExecForProjectRoot(projecRoot, a:cmd, 1, '')
endfunction

function! esy#ProjectExecWithStdIn(cmd, input)
  let projecRoot = esy#FetchProjectRoot()
  return esy#ProjectExecForProjectRoot(projecRoot, a:cmd, 1, a:input)
endfunction

function! esy#EnvDict()
  let projecRoot = esy#FetchProjectRoot()
  return esy#EnvDictFor(projecRoot)
endfunction

" Return empty string if not a valid esy project (malformed JSON etc). Returns
" "unnamed" if not named. Else the project name.
function! esy#ProjectName()
  let projecRoot = esy#FetchProjectRoot()
  if projecRoot == []
  else
    let projectInfo= esy#FetchProjectInfoForProjectRoot(projecRoot)
    return esy#ProjectNameOfProjectInfo(projectInfo)
  endif
endfunction

" Loose form - doesn't require esy project. Also avoids perf hit without
" needing cached call. No need to look up project info.
function! esy#Exec_(cmd, useCache)
  if a:useCache
    let projecRoot = esy#FetchProjectRootCached()
    return esy#ProjectExecForProjectRoot(projecRoot, a:cmd, 0, '')
  else
    let projecRoot = esy#FetchProjectRoot()
    return esy#ProjectExecForProjectRoot(projecRoot, a:cmd, 0, '')
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
"
" Loose form - doesn't require esy project.
function! esy#ExecWithStdIn(cmd, input)
  let projecRoot = esy#FetchProjectRoot()
  return esy#ProjectExecForProjectRoot(projecRoot, a:cmd, 0, a:input)
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
