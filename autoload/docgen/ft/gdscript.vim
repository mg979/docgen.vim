fun! docgen#ft#gdscript#get() "{{{1
  return s:gdscript
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:gdscript = {
      \ 'parsers': { -> ['^%sfunc\s%s%s%s:'] },
      \ 'comment': { -> ['#', '#', '#', '-'] },
      \ 'custom': { 'header': ['%p'] },
      \ 'alignParameters': { -> v:false }
      \}

fun! s:gdscript.drawFrame()
  return !self.style.is_docstring
endfun

fun! s:gdscript.rtypeFmt() abort
  if self.hintReturnType()
    let rtype = substitute(self.parsed.rtype, '\s*->\s*', '', '')
    let rtype = empty(rtype) ? '' : ' [' . trim(rtype) . ']'
  else
    let rtype = ''
  endif
  return [self.ctrlChar() . 'return' . rtype . ': %p']
endfun

fun! s:gdscript.paramsNames() abort
  let params = []
  for p in map(split(self.parsed.params, ','), 'trim(v:val)')
    let pstr = matchstr(p, '^\w\+')
    if self.hintParamType() && match(p, ': \w\+') >= 0
      let pstr .= ' [' .. matchstr(p, ': \zs\w\+') .. ']'
    endif
    call add(params, pstr)
  endfor
  return params
endfun

fun! s:gdscript.retLines() abort
  return match(self.parsed.rtype, 'void') == -1 ? self.templates.rtype : []
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 fdm=marker
