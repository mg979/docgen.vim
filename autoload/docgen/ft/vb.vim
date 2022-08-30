fun! docgen#ft#vb#get() "{{{1
    return s:vb
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:vb = {
      \ 'parsers': { -> ['^%sfunction\s%s%s%s', '^%ssub\s%s%s%s'] },
      \ 'comment': { -> ["''", "''", "''", "'"] },
      \ 'paramsPat': { -> '\s*(\(.\{-}\))' },
      \ 'retlines': { -> [] },
      \ 'custom':  {
          \ 'header': ['%s: %p'],
          \ 'params': ['@param %s %p'],
          \ 'rtype': [],
          \},
      \}

fun! s:vb.drawFrame()
    return !self.style.is_docstring || self.style.get_style() !~ 'simple\|minimal'
endfun

fun! s:vb.alignParameters()
    return self.style.get_style() !~ 'simple\|minimal'
endfun

fun! s:vb.paramsNames() abort
  let params = substitute(self.parsed.params, 'as \w\+', '', 'g')
  let params = substitute(params, 'optional ', '', 'g')
  let params = substitute(params, '\s*=\s*[^,]\+', '', 'g')
  return map(split(params, ','), { k,v -> split(v)[0] })
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
