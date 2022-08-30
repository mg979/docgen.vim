fun! docgen#ft#sh#get() "{{{1
    return s:sh
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:sh = {
      \ 'parsers': { -> ['^\s*function\s*%s\n\?\s*{', '^\s*%s()\n\?\s*{'] },
      \ 'order':    { -> ['name'] },
      \ 'comment': { -> ['#', '#', '#', '-'] }
      \}

fun! s:sh.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^\s*}', 'nW'))
        \ ? self.templates.rtype : []
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
