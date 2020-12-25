fun! docgen#ft#lua#get() "{{{1
    return s:lua
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:lua = {
      \ 'parsers': { -> ['^%sfunction\s%s%s%s', '^%s%s\s*=\s*function%s%s'] },
      \ 'typePat': { -> '\(local\)\?\s*' },
      \ 'comment': { -> ['----', '--', '----', '-'] }
      \}

fun! s:lua.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^end', 'nW'))
        \ ? self.templates.rtype : []
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"vim: ft=vim et sw=4 fd=marker
