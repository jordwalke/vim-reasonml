
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

let b:doing_ftplugin = 1
let b:merlin_env = {}

call esy#TrySetGlobalEsyBinaryOrWarn()

let b:finished_activating_merlin_for_buffer_successfully = reason#LoadBuffer()

" WARNING DO NOT EARLY RETURN
let b:doing_ftplugin = 0
