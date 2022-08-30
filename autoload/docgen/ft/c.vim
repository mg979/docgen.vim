fun! docgen#ft#c#get(ft) "{{{1
    return s:{a:ft}
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:c = {
      \ 'parsers':   { -> ['^%s%s\n\?%s%s\s*\n\?[{;]'] },
      \ 'typePat':   { -> '\(\%(extern\|static\|inline\)\s*\)*' },
      \ 'rtypePat':  { -> s:c_rpat() },
      \ 'namePat':   { -> '\(\w\+\)' },
      \ 'paramsPat': { -> '\s*(\(\_.\{-}\))' },
      \ 'order':     { -> ['type', 'rtype', 'name', 'params'] },
      \ 'docstyles': { -> ['kernel', 'kernelboxed', 'default', 'boxed', 'simple', 'minimal', 'minimalboxed'] },
      \}

"{{{1
""
" This may be used as example to make a custom parser. EVERYTHING must be
" defined as a function (also lambda is ok). Whatever is not defined here, will
" have its fallback in the s:Doc class.
"
" The dictionary above contains the mandatory 'parsers' list.
" The xxxPat are the patterns that will replace the '%s' in the parsers,
" according to the order defined by the 'order' key.
"
" Then you can replace other methods.
"
" Methods with xxxFmt() are called first, when the style is applied and
" templates are generated. For maximum flexibility, they can return
" a dictionary with the available styles as keys, and the desired format as
" value. When they return a simple list, the same format is used for all
" styles. Sometimes you may just want to return nothing (an empty list).
"
" During template generation, 'self.templates' is generated, with a template
" for each section (see s:Doc.sections).
"
" paramsNames() is called after the parameters have been parsed. It is used to
" refine how the parameters will be displayed, removing unwanted parts that
" have been parsed.
"
" After the parsing has been done, the 'self.parsed' dictionary is generated.
" Its keys are the same as the types in the 'self.order()' list.
"
" Methods with xxxLines() are called last, and return the lines as they will
" be printed. They should access the self.templates[section] and format them
" with the contents of the self.parsed dictionary.
""
fun! s:c.rtypeFmt() abort
  if self.parsed.rtype == 'void'
    return []
  endif
  let [rtype, ch] = [self.parsed.rtype, self.ctrlChar()]
  return {
        \ 'kernel':      ['Returns ' . rtype . ': %p'],
        \ 'kernelboxed': ['Returns ' . rtype . ': %p'],
        \ 'boxed':       [ch . 'return ' . rtype . ': %p'],
        \ 'default':     [ch . 'return ' . rtype . ': %p'],
        \ 'simple':      [ch . 'return: %p'],
        \ 'minimal':     [],
        \ 'minimalboxed': [],
        \}
endfun

fun! s:c.paramsFmt() abort
  let ch = self.ctrlChar()
  return {
        \ 'kernel':      [ch . '%s: %p'],
        \ 'kernelboxed': [ch . '%s: %p'],
        \ 'boxed':       [ch . 'param %s: %p'],
        \ 'default':     [ch . 'param %s: %p'],
        \ 'simple':      ['%s%p'],
        \ 'minimal':     [],
        \ 'minimalboxed': [],
        \}
endfun

fun! s:c.headerFmt()
  let ch = self.ctrlChar()
  return {
        \ 'kernel':      ['%s() - %p'],
        \ 'kernelboxed': ['%s() - %p'],
        \ 'boxed':       [ch . 'brief %s: %p'],
        \ 'default':     [ch . 'brief %s: %p'],
        \ 'simple':      ['%s%p'],
        \ 'minimal':     ['%s:%p'],
        \ 'minimalboxed': ['%s:%p'],
        \}
endfun

""
" s:c_rpat: the pattern for the C/C++ return type
""
fun! s:c_rpat()
  " either a single sequence of any characters, or more words like 'unsigned int'
  let pat = '\%([[:punct:][:alnum:]]\+\|\%(\w\+\s*\)\+\)\+'
  " either spaces or new line, possibly followed by asterisks
  let pat .= '\%(\n\*\{-}\|\s\+\*\{-}\)'
  return '\(' . pat . '\)'
endfun

""
" s:c._params_names
" This helper will also be used by cpp. If the parameter name is omitted, the
" parameter type is used, but enclosed in square brackets.
""
fun! s:c._params_names(...) abort
  " remove inline comments
  let params = substitute(a:1, '/\*.\{-}\*/', '', 'g')
  " remove parameters of function pointers
  let params = substitute(params, '(\k.\{-})', '@@FUNCARGS@@', 'g')
  let names = []
  for p in split(params, ',')
    let _p = split(p)
    if len(_p) > 1
      if _p[-1] =~ '^(\*\k\+)@@FUNCARGS@@'
        let pp = matchstr(_p[-1], '^(\*\k\+)')
      elseif _p[-1] =~ '^\k\+@@FUNCARGS@@'
        let pp = '(*' . matchstr(_p[-1], '^\k\+') . ')'
      else
        let pp = _p[-1]
      endif
      call add(names, substitute(pp, '^[*&]\+', '', ''))
    else
      call add(names, '[' . _p[0] . ']')
    endif
  endfor
  return names
endfun

fun! s:c.paramsNames() abort
  if self.parsed.params == 'void'
    return []
  endif
  return self._params_names(self.parsed.params)
endfun

fun! s:c.detailLines() abort
  return self.style.get_style() =~ 'kernel' ? ['', self.placeholder()] : []
endfun

fun! s:c.headerLines() abort
  let header = self.templates.header
  if empty(self.lines.params) && empty(self.lines.return)
    return [ self.parsed.name . ':' . self.placeholder() ]
  endif
  return map(header, { k,v -> v =~ '%s' ? printf(v, self.parsed.name) : v })
endfun

""
" Here we handle structures and even variables.
""
fun! s:c.storage() abort
  let storage = []
  " typedef ... name;
  call add(storage, '^\s*\(typedef\)\s\+\%(\w\+\s\+\)\+\(\w\+\);')
  " [typedef] struct|union|class|enum [tag] {...} name[, name...];  WITH NO \n
  call add(storage, '^\s*\(\%(\w\+\s\+\)\+\)\s*{\%(.\{-}\)}\s*\(\w\+\%(,\s*\w\+\)\?\)\?;')
  " [typedef] struct|union|class|enum [tag] {...} name[, name...];  WITH \n
  call add(storage, '^\s*\(\%(\w\+\s\+\)\+\)\s*{\%(.*\n\?\)\{-}}\s*\(\w\+\%(,\s*\w\+\)\?\)\?;')
  " generic variable definition
  call add(storage, '^\s*\(\w\+\)\s\+\([^=]\+\)\%(=\s*.*\)\?;')
  return storage
endfun

fun! s:c.storageLines() abort
  let all = matchlist(join(getline(self.startLn, self.endLn), "\n"), self.pattern)
  let type = all[1]
  let name = all[2]
  if getline(self.startLn) =~ 'typedef'
    return ['typedef ' . trim(name) . ': ' .self.placeholder()]
  elseif name != ''
    return [trim(type) . ' ' . trim(name) . ': ' . self.placeholder()]
  else
    return [trim(type) . ': ' . self.placeholder()]
  endif
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:cpp = extend(copy(s:c), {
      \ 'parsers':    { -> ['^%s%s%s\n\?%s%s\s*\%(=\s*.*\|\w\+\s*\)\?\n\?[{;]'] },
      \ 'typePat':    { -> '\(\%(extern\|static\|inline\|explicit\|virtual\|volatile\|const\)\s*\)*' },
      \ 'rtypePat':   { -> s:c_rpat() . '\%(\w\+::\)\?\*\{-}' },
      \ 'tparamsPat': { -> '\%(\s*template\s*<\(.*\)>\n\)\?' },
      \ 'namePat':    { -> '\(\w\+[[:punct:]]\{-}\)' },
      \ 'order':      { -> ['tparams', 'type', 'rtype', 'name', 'params'] },
      \ 'sections':   { -> ['header', 'tparams', 'params', 'rtype'] },
      \})

"{{{1
fun! s:cpp.tparamsFmt() abort
  let ch = self.ctrlChar()
  return {
        \ 'kernel':      [ch . '%s: %p'],
        \ 'kernelboxed': [ch . '%s: %p'],
        \ 'boxed':       [ch . 'tparam %s: %p'],
        \ 'default':     [ch . 'tparam %s: %p'],
        \ 'simple':      ['%s: %p'],
        \ 'minimal':     [],
        \ 'minimalboxed': [],
        \}
endfun

fun! s:cpp.headerFmt()
  let m = matchstr(getline(self.startLn), '^\s*\%(\w\+\s*\)\?\zs\w\+\ze::')
  let f = m == '' ? 'Function' : '[' . m . '] Method'
  let s = m == '' ? '' : m . '.'
  return {
        \ 'kernel':      [s . '%s() - %p'],
        \ 'kernelboxed': [s . '%s() - %p'],
        \ 'boxed':       [self.ctrlChar() . 'brief %s: %p', ''],
        \ 'default':     [self.ctrlChar() . 'brief %s: %p', ''],
        \ 'simple':      [s . '%s:%p'],
        \ 'minimal':     [s . '%s:%p', ''],
        \ 'minimalboxed': [s . '%s:%p', ''],
        \}
endfun

""
" s:cpp._clean_params
" Clean up both params and tparams by removing text in angle brackets and
" parameters default values.
""
fun! s:cpp._clean_params(...) abort
  let params = substitute(a:1, '<.\{-}>', '', 'g')
  let params = substitute(params, '\s*=\s*[^,]\+', '', 'g')
  return params
endfun

fun! s:cpp.tparamsNames() abort
  return self._params_names(self._clean_params(self.parsed.tparams))
endfun

fun! s:cpp.paramsNames() abort
  if self.parsed.params == 'void'
    return []
  endif
  return self._params_names(self._clean_params(self.parsed.params))
endfun

fun! s:cpp.paramsLines() abort
  let lines = []
  for arg in self.tparamsNames()
    for line in self.templates.tparams
      call add(lines, line =~ '%s' ? printf(line, trim(arg)) : line)
    endfor
  endfor
  for param in self.paramsNames()
    for line in self.templates.params
      call add(lines, line =~ '%s' ? printf(line, trim(param)) : line)
    endfor
  endfor
  return lines
endfun

fun! s:cpp.retLines() abort
  return !empty(self.parsed.tparams) ? [] : self.templates.rtype
endfun

fun! s:cpp.storage() abort
  let storage = []
  " typedef ... name;
  call add(storage, '^\s*\(typedef\)\s\+\%(\w\+\s\+\)\+\(\w\+\);')
  " [typedef] struct|union|class|enum [tag] [: type] {...} name[, name...];  WITH NO \n
  call add(storage, '^\s*\(\%(\w\+\s\+\)\+\)\s*\%(:\%(\s\+\w\+\)\+\s*\)\?{\%(.\{-}\)}\s*\(\w\+\%(,\s*\w\+\)\?\)\?;')
  " [typedef] struct|union|class|enum [tag] [: type] {...} name[, name...];  WITH \n
  call add(storage, '^\s*\(\%(\w\+\s\+\)\+\)\s*\%(:\%(\s\+\w\+\)\+\s*\)\?{\%(.*\n\?\)\{-}}\s*\(\w\+\%(,\s*\w\+\)\?\)\?;')
  " generic variable definition
  call add(storage, '^\s*\(\w\+\)\s\+\([^=]\+\)\%(=\s*.*\)\?;')
  return storage
endfun

"}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: ft=vim et ts=2 sw=2 sts=2 fdm=marker
