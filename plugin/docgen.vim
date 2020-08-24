" ========================================================================///
" Description: plugin for code documentation, inspired by vim-doge
" File:        docgen.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     Thu 13 August 2020 03:01:30
" Modified:    Thu 13 August 2020 03:01:30
" ========================================================================///

" GUARD {{{1
if v:version < 800
  finish
endif

if exists('g:loaded_docgen')
  finish
endif
let g:loaded_docgen = 1

" COMMANDS AND MAPPINGS {{{1

if get(g:, 'docgen_mappings', 1)
  nnoremap <silent> ,d :<C-U>call docgen#func(0,v:count?v:count:'')<cr>@=<cr>
  nnoremap <silent> ,D :<C-u>DocFun! <C-r>=v:count?v:count:''<CR><cr>
  nnoremap <silent> ,x :<C-U>call docgen#box(0, v:count)<cr>@=<cr>
  nnoremap <silent> ,X :<C-U>call docgen#box(1, v:count)<cr>@=<cr>
endif

command! -count -bang DocFun call docgen#func(<bang>0, <count>)
command! -count -bang DocBox call docgen#box(<bang>0, <count>)

" vim: et sw=2 ts=2 sts=2 fdm=marker
