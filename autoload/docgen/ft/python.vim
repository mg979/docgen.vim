fun! docgen#ft#python#get() "{{{1
  return s:python
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:python = {
      \ 'parsers':   { -> ['^\s*%s%s%s%s:'] },
      \ 'typePat':   { -> '\(class\|def\)\s*' },
      \ 'putBelow':  { -> 1 },
      \ 'ctrlChar': { -> ':' },
      \ 'leadingSpaceAfterComment': { -> 1 },
      \}

fun! s:python.rtypeFmt() abort
  if self.hintReturnType()
    let rtype = substitute(self.parsed.rtype, '\s*->\s*', '', '')
    let rtype = empty(rtype) ? '' : ' [' . trim(rtype) . ']'
  else
    let rtype = ''
  endif
  return [self.ctrlChar() . 'return' . rtype . ': %p']
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
  return filter(split(params, ','), 'v:val !=# "self"')
endfun

""
" Function: s:Doc.remove_previous
"
" python needs a different handling because docstrings can contain empty lines.
" We're only handling docstrings put below function definition.
"
" @param start: the line where the command is started
" @return: the lines of the removed docstring, or an empty list
""
fun! s:python.remove_previous(start) abort
  " {{{1
  let lines = []
  if !search('^\s*"""', 'n', a:start + 1)
    return []
  endif
  +
  let begin = line('.')
  if getline('.') =~ '^\s*""".*"""$'
    let end = begin
    let lines = [substitute(getline('.'), '"""\s*', '', 'g')]
  else
    let end = search('^\s*"""', 'n')
    let lines = getline(begin, end)
  endif

  let next = self.below() ? 1 : -1
  let last = self.below() ? line('$') : 1
  exe begin . ',' . end . 'd_'
  -
  return lines
endfun "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
