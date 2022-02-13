fun! docgen#ft#lua#get() "{{{1
    return s:lua
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:lua = {
      \ 'parsers': { -> ['^%sfunction\s%s%s%s', '^%s%s\s*=\s*function%s%s'] },
      \ 'typePat': { -> '\(local\)\?\s*' },
      \ 'custom':  {
          \ 'header': { 'simple': ['%p'] },
          \ 'params': { 'simple': ['@param %s %p'] },
          \ 'rtype': { 'simple': ['@return %p'] },
          \},
      \}

fun! s:lua.drawFrame()
    return !self.style.is_docstring || self.style.get_style() !~ 'simple\|minimal'
endfun

fun! s:lua.comment()
    return self.style.is_docstring ? ['---', '---', '---', '-'] : ['----', '--', '----', '-']
endfun

fun! s:lua.alignParameters()
    return self.style.get_style() !~ 'simple\|minimal'
endfun

fun! s:lua.retLines() abort
  return search('return\s*[[:alnum:]_#([{''"]', 'nW', search('^end', 'nW'))
        \ ? self.templates.rtype : []
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"vim: ft=vim et sw=4 fd=marker
