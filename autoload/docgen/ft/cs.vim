fun! docgen#ft#cs#get() "{{{1
    return s:cs
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:am = [ 'public', 'private', 'protected', 'static', 'internal',
            \'async', 'virtual', 'override', 'abstract', 'sealed']
let s:cs = {
      \ 'parsers':   { -> ['^%s%s%s%s\s*\n\?\s*{'] },
      \ 'typePat':   { -> '\s*\(\%(\%('. join(s:am, '\|') .'\)\s*\)*\)' },
      \ 'rtypePat':  { -> '\s*\(\w\{-}\)' },
      \ 'namePat':   { -> '\s*\(\w\+\)' },
      \ 'paramsPat': { -> '\s*(\(\_.\{-}\))' },
      \ 'order':     { -> ['type', 'rtype', 'name', 'params'] },
      \ 'docstyles': { -> ['xml', 'default', 'minimal'] },
      \ 'custom':    {'header': {}, 'params': {}, 'rtype': {}},
      \}

let s:cs.alignParameters = { -> 0 }
let s:cs.sections = { -> ['header', 'rtype', 'params'] }

let s:cs.custom.header.xml = ['<summary>', '%p', '</summary>', '']
let s:cs.custom.rtype.xml = ['<returns>', '%p', '</returns>', '']
let s:cs.custom.params.xml = ['<param name="%s">%p</param>']

fun! s:cs.comment()
    return self.style.is_docstring ? ['///', '///', '///', '/'] : ['/**', ' *', '*/', '*']
endfun

fun! s:cs.drawFrame()
    return !self.style.is_docstring
endfun

fun! s:cs.retLines() abort
  if self.parsed.rtype == 'void' || empty(self.parsed.rtype)
    return []
  endif
  return self.templates.rtype
endfun

fun! s:cs.paramsNames(...) abort
    if !has_key(self.parsed, 'params')
        return []
    endif
    let params = substitute(self.parsed.params, '<.\{-}>', '', 'g')
    let params = substitute(params, '\s*=\s*[^,]\+', '', 'g')
    let params = split(params, ',')
    return map(params, 'split(v:val)[-1]')
endfun

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"vim: ft=vim et sw=4 fd=marker
