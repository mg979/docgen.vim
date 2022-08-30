fun! docgen#ft#go#get() "{{{1
    return s:go
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:go = {
      \ 'parsers':   { -> ['^func\s\+%s%s%s%s\s*{'] },
      \ 'namePat':   { -> '\s*\%((.\{-})\s*\)\?\([^( \t]\+\)' },
      \ 'paramsPat': { -> '\s*(\(.\{-}\))' },
      \ 'rtypePat':  { -> '\s*\(.*\)\?' },
      \}

fun! s:go.headerFmt()
  let m = matchstr(getline(self.startLn), '^\s*func\s*(.\{-}\s\+\*\?\zs.\{-}\ze)')
  let f = m == '' ? 'Function' : '[' . m . '] Method'
  let s = m == '' ? '' : m . '.'
  return {
      \ 'boxed':    [f . ': %s%p', ''],
      \ 'default':  [f . ': %s%p', ''],
      \ 'simple':   [s . '%s:%p'],
      \ 'minimal':  [s . '%s:%p', ''],
      \}
endfun

fun! s:go.rtypeFmt() abort
  let rtype = substitute(self.parsed.rtype, '^(', '', '')
  let rtype = substitute(rtype, ')$', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return [self.ctrlChar() . 'return: ' . rtype . ' %p']
endfun

fun! s:go.paramsNames() abort
  let params = substitute(self.parsed.params, '<.\{-}>', '', 'g')
  let params = substitute(params, '\s*=\s*[^,]\+', '', 'g')
  return map(split(params, ','), { k,v -> split(v)[0] })
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
