fun! docgen#ft#java#get() "{{{1
    return s:java
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:java = {
      \ 'parsers':  { -> ['^\s*%s%s%s%s\s*[;{]'] },
      \ 'typePat':  { -> '\(\%(public\|private\|protected\|static\|final\)\s*\)*' },
      \ 'rtypePat': { -> '\s*\([[:punct:][:alnum:]]\+\)\?\s\+' },
      \ 'order':    { -> ['type', 'rtype', 'name', 'params'] },
      \}

fun! s:java.rtypeFmt() abort
  if self.parsed.rtype == 'void' || self.parsed.rtype == ''
    return []
  elseif self.parsed.rtype !~ '\S'
    return [self.ctrlChar() . 'return: %p']
  else
    let rtype = substitute(self.parsed.rtype, '<.*>', '', '')
    return [self.ctrlChar() . 'return ' . rtype . ': %p']
  endif
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
