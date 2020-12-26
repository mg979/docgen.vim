fun! docgen#ft#python#get() "{{{1
    return s:python
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:python = {
      \ 'parsers':   { -> ['^\s*%s%s%s%s:'] },
      \ 'typePat':   { -> '\(class\|def\)\s*' },
      \ 'putBelow':  { -> 1 },
      \ 'jollyChar': { -> ':' },
      \ 'leadingSpaceAfterComment': { -> 1 },
      \}

fun! s:python.rtypeFmt() abort
  let rtype = substitute(self.parsed.rtype, '\s*->\s*', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return [self.jollyChar() . 'return: ' . rtype . ' %p']
endfun

fun! s:python.comment() abort
  return self.style.is_docstring ? ['"""', '', '"""', '"'] : ['#', '#', '#', '-']
endfun

fun! s:python.is_comment(line) abort
  return synIDattr(synID(a:line, indent(a:line) + 1, 1), "name") =~? 'comment\>\|string\>'
endfun

fun! s:python.paramsNames() abort
  let params = substitute(self.parsed.params, '\s*=\s*[^,]\+', '', 'g')
  while params =~ '('
    let params = substitute(params, '([^(]\{-})', '', 'g')
  endwhile
  while params =~ '\['
    let params = substitute(params, '\[[^[]\{-}]', '', 'g')
  endwhile
  while params =~ '{'
    let params = substitute(params, '{[^{]\{-}}', '', 'g')
  endwhile
  let params = substitute(params, ':[^,]\+', '', 'g')
  return split(params, ',')
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"vim: ft=vim et sw=4 fd=marker