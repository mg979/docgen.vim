fun! docgen#ft#vim#get() "{{{1
    return s:vim
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:vim = {
      \ 'parsers': { -> ['^fu\k*!\?\s%s%s%s%s'] },
      \ 'comment': { -> ['""', '"', '""', '='] },
      \ 'fmt': {'rtype': {'default': ['Returns: %p'], 'boxed': ['Returns: %p']}}
      \}

fun! s:vim.frameChar() abort
  return self.style.is_docstring ? '=' : '"'
endfun

fun! s:vim.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^endf', 'nW'))
        \ ? self.templates.rtype : []
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"vim: ft=vim et sw=4 fd=marker
