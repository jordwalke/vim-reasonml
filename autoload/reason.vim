" http://vim.wikia.com/wiki/Get_shortened_messages_from_using_echomsg
function! reason#VimReasonShortMsg(msg)
  " regular :echomsg doesn't shorten messages with +T
  " but for some reason, with "norm echomsg", it does.
  " The same trick doesn't work for echoerr :(
  let saved=&shortmess
  set shortmess+=T
  exe "norm :echomsg a:msg\n"
  let &shortmess=saved
endfunction
