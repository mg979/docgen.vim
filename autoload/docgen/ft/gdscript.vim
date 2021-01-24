fun! docgen#ft#gdscript#get() "{{{1
    return s:gdscript
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:gdscript = {
      \ 'parsers': { -> ['^%sfunc\s%s%s%s'] },
      \ 'comment': { -> ['#', '#', '#', '-'] },
      \ 'custom': {},
      \}

let s:gdscript.custom.header = {'default': ['Func %s: %p']}

fun! s:gdscript.paramsNames() abort
  let params = substitute(self.parsed.params, '\s*\(:\|=\|:=\)[^,]\+', '', 'g')
  return split(params, ',')
endfun

fun! s:gdscript.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^end', 'nW'))
        \ ? self.templates.rtype : []
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"vim: ft=vim et sw=4 fd=marker
