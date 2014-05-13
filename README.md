vim-addon-local-vimrc
======================

Configuration: these are the defaults:
```vim
let g:local_vimrc = {'names':['.vimrc'],'hash_fun':'LVRHashOfFile'}
```

Features:
- When Vim starts up, every directory from root to the directory of the file
  is traversed and special files such as .(local-)vimrc files are sourced

- Because you don't want to run untrusted code by accident, this plugin
  calculates a asks you before sourcing any given file, and optionally
  remembers your answer for the future.  Possible answers are (with the
  abbreviation captitalized):

    - `Yes`: Read the file this time, but do not remember the answer;
       you will be asked again next time

    - `No`: Don't read it, and don't remember the answer

    - `Always`: Read the file this time, and automatically do so from now on

    - `neVer`: Don't read it, and don't ask again in future
  
- It also remembers a hash of the file's contents, so that if the file
  changes, you'll be asked again.

  If you use vim to edit a local vimrc file, an answer of "Always" is
  automatically saved for (that version of) the file, on the theory
  that you trust any edits you yourself have made.

- if you change a directory and edit a file the local vimrc files are resourced

USAGE:
========
create a .vimrc in your project directory.
To make sure it's working, add: echo "this file is being sourced by vim"

Sample local .vimrc
===================

```vim
augroup LOCAL_SETUP
  " using vim-addon-sql providing alias aware SQL completion for .sql files and PHP:
  autocmd BufRead,BufNewFile *.sql,*.php call vim_addon_sql#Connect('mysql',{'database':'DATABASE', 'user':'USER', 'password' : 'PASSWORD'})

  " for php use tab as indentation character. Display a tab as 4 spaces:
  " autocmd BufRead,BufNewFile *.php set noexpandtab| set tabstop=4 | set sw=4
  autocmd FileType php setlocal noexpandtab| setlocal tabstop=4 | setlocal sw=4

  " hint: for indentation settings modelines can be an alternative as well as
  " various plugins trying to set vim's indentation based on file contents.
augroup end
```


KISS: If you need filetype support write au commands into the local vimrc.

Yes I know that there are already a couple of existing similar plugins.
But I they work for filetypes only (why?) and they don't verify file contents.


Alternatives
============
directory local .vimrc without walking up directory tree using vim builtin 'exrc' option:
  :h 'exrc'
  :h 'secure'
but 'secure' is not very secure, eg echo system('cat .vimrc') is executed
unless the file belongs to a different owner..

contributors
============
Thiago de Arruda (github.com/tarruba)