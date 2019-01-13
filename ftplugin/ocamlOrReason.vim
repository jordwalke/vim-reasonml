
" Language:     Reason
" Description:  Vim ftplugin file for Reason

if exists("b:finished_activating_merlin_for_buffer_successfully")
  finish
endif

if exists("b:doing_ftplugin")
  " Something had set ft=reason during the loading of this ftplugin/reason.vim
  " file! This happens if we lazily load plugins.
  finish
endif


" Where esy is found to be installed in the local project as a ./esy
" (This is not a typical use case.)
let b:reasonml_local_esy_discovered_path=''
" The discovered version of that binary. Empty object means not valid.
let b:reasonml_local_esy_discovered_version={}
" We'll check at most one time per local project - too expensive otherwise.
let b:reasonml_local_esy_checked=0

" Sets the g: version of those variables.
call esy#SetGlobalEsy()
" We won't warn for missing global esy/old versions because maybe the local
" project has it.


let b:doing_ftplugin = 1
let b:merlin_env = {}

let b:finished_activating_merlin_for_buffer_successfully = reason#LoadBuffer()

" WARNING DO NOT EARLY RETURN
let b:doing_ftplugin = 0
