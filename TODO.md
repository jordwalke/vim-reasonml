
**Install Esy In Command Line While Open**
1. User installs `vim-reasonml`.
2. User clones a Reason project, and opens it.
3. User gets error that esy is not installed.
4. User installs `npm install -g esy`.
5. User refocuses a Reason file or any file in a reason project directory, and
   vim checks again if esy installed globally. It is, so it automatically loads
   all the IDE support.

**Install Esy From Vim's Terminal While Open**
1. The same workflow as above, except upgrading a version of esy.

**Bump Esy Version While Open**
1. The same workflow as above, except upgrading a version of esy.

**Install Esy While Open**
1. Installing esy directly from the Vim plugin asynchronously!
  - Using xolox's async support.
  - Need to build a workflow for surfacing/killing/monitoring async jobs like
    long installs.
  - Needs the same kind of global check for npm that we do for esy.

In-editor workflows:

- See if we can store the airline status in some universally
  recognized project name var like `b:projectName`. Other airline
  extensions might already recognize this.
- Have a "Refresh" command that will cause some env var to be bumped.
- Have a help doc describing how to use the refresh command and others.
- Make sure the reason/merlin errors section works well with no Syntastic, and
  maybe make it work well with ALE.
