" needed by vimrunner
function! VimrunnerPyEvaluateCommandOutput(command)
  redir => output
    silent exe a:command
  redir END
  return output
endfunction

set runtimepath=$VIMRUNTIME
set packpath=
set nocompatible
set runtimepath^=..

filetype on             " Enable file type detection
filetype plugin on      " Enable loading the plugin files for specific file types
filetype indent on      " Load indent files for specific file types
syntax enable

source ../plugin/docgen.vim
