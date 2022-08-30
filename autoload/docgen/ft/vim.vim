fun! docgen#ft#vim#get() "{{{1
    return s:vim
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:vim = {
      \ 'parsers': { -> ['^fu\k*!\?\s%s%s%s%s'] },
      \ 'comment': { -> search('^vim9script', 'n') ? ['#', '#', '#', '='] : ['""', '"', '""', '='] },
      \ 'fmt': {'rtype': {'default': ['Returns: %p'], 'boxed': ['Returns: %p']}}
      \}

fun! s:vim.frameChar() abort
  return self.style.is_docstring || search('^vim9script', 'n') ? '-' : '"'
endfun

fun! s:vim.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^endf', 'nW'))
        \ ? self.templates.rtype : []
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
