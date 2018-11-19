- See if we can store the airline status in some universally
  recognized project name var like `b:projectName`. Other airline
  extensions might already recognize this.
- Have a "Refresh" command that will cause some env var to be bumped.
- Have a help doc describing how to use the refresh command and others.
- Make sure the reason/merlin errors section works well with no Syntastic, and
  maybe make it work well with ALE.
- Move variable names to be `g:reason_foo` instead of
  `g:vimreason_foo` - this follows the config convention in the vim
  world. We'll have to support both simultaneously for a while.
