" VARIABLES {{{1

let s:supported = ['vim', 'lua', 'python', 'sh', 'java', 'ruby', 'go', 'c', 'cpp']

let s:ph = '$' . 'PLACEHOLDER'

" }}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


""
" docgen#box: create a comment box
"
" @param bang: with full length frame
""
fun! docgen#box(bang) abort
  " {{{1
  let lines = s:create_box(s:replace_comment(), a:bang, trim(s:comment()[1]))
  silent -1put =lines
  silent keepjumps normal! `[=`]
  let i = line('.')
  for l in lines
    call setline(i, getline(i)[:&tw-1])
    let i += 1
  endfor
  normal! `[j
  " could be a converted comment
  if getline('.') !~ '\w'
    call feedkeys('A ', 'n')
  endif
endfun "}}}


""
" docgen#func: create or update template for function documentation
"
" @param bang: with full length frame
""
fun! docgen#func(bang, count) abort
  " {{{1
  let ft = split(&filetype, '\.')[0]
  if index(s:supported, ft) < 0 && !exists('b:docgen')
    echo '[docgen] not supported'
    return
  endif

  if ft == 'c' || ft == 'cpp'
    call doxygen#comment_func()
    return
  endif

  let doc = s:new()
  if a:bang
    call doc.style.change()
    return
  elseif a:count
    call doc.style.change(a:count - 1)
  else
    call doc.style.apply()
  endif

  let startLn = doc.parse(doc.search_function())
  if !startLn | return | endif

  " move to the line with the function declaration
  exe startLn

  " process params and return first, if absent the comment will be trimmed
  let doc.lines.params = doc.paramsLines()
  let doc.lines.return = doc.retLine()
  let doc.lines.desc = doc.descLines()

  let lines = doc.lines.desc + doc.lines.params + doc.lines.return

  " keep the old lines of the previous docstring, if unchanged
  let lines = s:preserve_oldlines( lines, s:previous_lines(startLn) )

  " align placeholders and create box
  let lines = s:create_box( s:align(lines, doc.funcName), doc.get_boxed() )

  call append(line('.') - 1, lines)

  " edit first placeholder, or go back to starting line if none is found
  normal! {
  if search(s:ph, '', startLn + len(lines))
    let @/ = s:ph
    call feedkeys('"_cgn', 'n')
  else
    exe startLn
  endif
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Formatter initializer
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:new() abort
  "{{{1
  let doc = extend(copy(s:Doc), s:{&filetype})
  let doc.style = s:Style
  return doc
endfun "}}}

let s:Doc = {'lines': {}}

" default formatters for docstring lines
let s:Doc.funcFmt   = ['%s:' . s:ph, '']
let s:Doc.paramsFmt = ["@param %s: " . s:ph]
let s:Doc.retFmt    = ['@return: ' . s:ph]

" default patterns for function name, parameters, pre and post
let s:Doc.prePat    = '\(\)'
let s:Doc.funcPat   = '\s*\([^( \t]\+\)'
let s:Doc.paramsPat = '\s*(\(.\{-}\))'
let s:Doc.postPat   = '\s*\(.*\)\?'

let s:Doc.boxed     = 0
let s:Doc.minimal   = 0


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Getters
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" getters that prefer b:docgen -> s:{&filetype} -> default

fun! s:get(what, doc)
  "{{{1
  let val = get(s:bdoc(), a:what, get(s:{&filetype}, a:what, a:doc[a:what]))
  return type(val) == v:t_func ? val() : val
endfun "}}}

fun! s:Doc.get_parsers() "{{{1
  return s:get('parsers', self)
endfun

fun! s:Doc.get_funcFmt() "{{{1
  return s:get('funcFmt', self)
endfun

fun! s:Doc.get_paramsFmt() "{{{1
  return s:get('paramsFmt', self)
endfun

fun! s:Doc.get_retFmt() "{{{1
  return s:get('retFmt', self)
endfun

fun! s:Doc.get_prePat() "{{{1
  return s:get('prePat', self)
endfun

fun! s:Doc.get_funcPat() "{{{1
  return s:get('funcPat', self)
endfun

fun! s:Doc.get_paramsPat() "{{{1
  return s:get('paramsPat', self)
endfun

fun! s:Doc.get_postPat() "{{{1
  return s:get('postPat', self)
endfun

fun! s:Doc.get_boxed() "{{{1
  return s:get('boxed', self)
endfun

fun! s:Doc.get_minimal() "{{{1
  return s:get('minimal', self)
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Formatter methods
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:Doc.parse
" Parse the function declaration and get function name, parameters and return
" value out of it.
"
" @param where: the line number with the function declaration, if found
" @return:      the line number with the function declaration
""
fun! s:Doc.parse(where) abort
  "{{{1
  if !a:where
    return 0
  endif
  let all = matchlist(getline(a:where), self.pattern)[1:4]
  let self.funcPre    = all[0]
  let self.funcName   = all[1]
  let self.funcParams = all[2]
  let self.funcPost   = all[3]
  return a:where
endfun "}}}

""
" Function: s:Doc.search_function
" Search the closest function declaration upwards, if it can be found set the
" current pattern to the one that found it.
"
" @return: the line number with the function declaration
""
fun! s:Doc.search_function() abort
  "{{{1
  let startLn = 0
  for p in self.format_parsers()
    if !startLn || search(p, 'cnbW') > startLn
      let startLn = search(p, 'cnbW')
      let self.pattern = p
    endif
  endfor
  return startLn
endfun "}}}

""
" Function: s:Doc.format_parsers
" Convert the parsers to patterns with printf(), replacing the placeholders
" with the specific patterns for the current filetype.
"
" @return: the formatted parsers
""
fun! s:Doc.format_parsers() abort
  "{{{1
  let d = self
  let pats = []
  let parsers = d.get_parsers()
  for p in range(len(parsers))
    call add(pats, printf(parsers[p], d.get_prePat(),
          \                           d.get_funcPat(),
          \                           d.get_paramsPat(),
          \                           d.get_postPat()))
  endfor
  return pats
endfun "}}}

""
" Function: s:Doc.descLines
"
" @return: the line(s) with the formatted description
""
fun! s:Doc.descLines() abort
  "{{{1
  let lines = []
  let template = self.get_funcFmt()
  if empty(self.lines.params) && empty(self.lines.return)
    call filter(template, 'v:val =~ "%s"')
  endif
  for v in template
    call add(lines, v =~ '%s' ? printf(v, self.funcName) : v)
  endfor
  return lines
endfun "}}}

""
" Function: s:Doc.paramsLines
"
" @return: the line(s) with parameters
""
fun! s:Doc.paramsLines() abort
  "{{{1
  if empty(self.get_paramsFmt()) || self.get_minimal()
    return []
  endif
  let params = substitute(self.funcParams, '<.\{-}>', '', 'g')
  let params = substitute(params, '\s*=\s*[^,]\+', '', 'g')
  let params = split(params, ',')
  let lines = []
  for par in params
    for line in self.get_paramsFmt()
      call add(lines, line =~ '%s' ? printf(line, trim(par)) : line)
    endfor
  endfor
  return lines
endfun "}}}

""
" Function: s:Doc.retLine
"
" @return: the line(s) with the return value
""
fun! s:Doc.retLine() abort
  "{{{1
  return self.get_minimal() ? [] : self.get_retFmt()
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Styles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:Style = {
      \   'list': ['nonboxed', 'boxed', 'simple', 'minimal'],
      \   'current': 0,
      \  }

fun! s:Style.change(...) abort
  "{{{1
  if a:0
    let self.current = a:1 - 1
  endif
  if self.current >= len(self.list) - 1
    let self.current = 0
  else
    let self.current += 1
  endif
  call self.apply()
  echo '[docgen] current style:' self.list[self.current]
endfun "}}}

fun! s:Style.apply() abort
  "{{{1
  let ft = s:{&filetype}
  let styles = get(s:bdoc(), 'styles', get(ft, 'styles', self.list))
  if styles[self.current] == 'nonboxed'
    let ft.funcFmt = [ 'Function: %s' . s:ph, '' ]
    let ft.boxed = 0
    let ft.minimal = 0
  elseif styles[self.current] == 'boxed'
    let ft.funcFmt = [ 'Function: %s' . s:ph, '' ]
    let ft.boxed = 1
    let ft.minimal = 0
  elseif styles[self.current] == 'simple'
    let ft.funcFmt = ['%s:' . s:ph, '']
    let ft.boxed = 0
    let ft.minimal = 0
  else
    let ft.funcFmt = ['%s:' . s:ph]
    let ft.boxed = 0
    let ft.minimal = 1
  endif
endfun "}}}




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Filetype-specific
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Each filetype will define at least a list of function parsers.
" After that, each can provide specific members or methods.
""

let s:vim = {
      \ 'parsers': ['^fu\k*!\?\s%s%s%s%s'],
      \}

"{{{1

""
" don't add the @return line if no meaningful return value
""
fun! s:vim.retLine() abort
  return self.get_minimal() ? [] :
        \ search('return\s*[[:alnum:]_([{''"]', 'nW', search('^endf', 'nW'))
        \ ? self.get_retFmt() : []
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:lua = {
      \ 'parsers': ['^%sfunction\s%s%s%s',
      \             '^%s%s\s*=\s*function%s%s'],
      \ 'prePat': '\(local\)\?\s*'
      \}

"{{{1

fun! s:lua.descLines() abort
  let pre = empty(self.funcPre) ? '' : '[' . self.funcPre . '] '
  let line = printf(pre . self.get_funcFmt()[0], self.funcName)
  return self.get_minimal() ? [line] : [line, '']
endfun

""
" don't add the @return line if no meaningful return value
""
fun! s:lua.retLine() abort
  return self.get_minimal() ? [] :
        \ search('return\s*[[:alnum:]_([{''"]', 'nW', search('^end', 'nW'))
        \ ? self.get_retFmt() : []
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:python = {
      \ 'parsers': ['^%s%s%s%s:'],
      \ 'prePat': '\(class\|def\)\s*'
      \}

"{{{1

fun! s:python.retLine() abort
  let rtype = substitute(self.funcPost, '\s*->\s*', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return ['@return: ' . rtype . ' ' . s:ph]
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:sh = {
      \ 'parsers': ['^function\s%s%s%s%s', '^%s%s%s%s']
      \}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:java = {
      \ 'parsers': ['^%s.\{-}%s%s%s\s*[;{]'],
      \ 'prePat': '\(\(public\|private\|protected\|static\|final\)\s*\)*'
      \}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ruby = {
      \ 'parsers': ['^def\s\+%s%s[=!]\?%s%s']
      \}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


let s:go = {
      \ 'parsers': ['^func\s\+%s%s%s%s\s*{']
      \}

"{{{1

fun! s:go.retLine() abort
  let rtype = substitute(self.funcPost, '^(', '', '')
  let rtype = substitute(rtype, ')$', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return ['@return: ' . rtype . ' ' . s:ph]
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:is_comment(line) abort
  return synIDattr(synID(a:line, indent(a:line) + 1, 1), "name") =~? 'comment'
endfun

fun! s:bdoc()
  " {{{1
  return get(b:, 'docgen', {})
endfun "}}}

fun! s:comment()
  " {{{1
  let cm = &commentstring =~ '//\s*%s' ? '/*%s*/' : &commentstring
  let c = substitute(split(&commentstring, '%s')[0], '\s*$', '', '')
  return cm == '/*%s*/' ? ['/*', ' *', ' */'] : [c, c, c]
endfun "}}}

fun! s:preserve_oldlines(lines, oldlines) abort
  " {{{1
  for l in range(len(a:lines))
    let line = substitute(a:lines[l], '\V' . s:ph, '', 'g')
    for ol in a:oldlines
      if line != '' && ol =~ '^\V' . line
        let a:lines[l] = ol
        break
      endif
    endfor
  endfor
  for o in range(len(a:oldlines))
    let ol = a:oldlines[o]
    if ol =~ '^\%(.\?param \|.\?return \)\?\S\+:'
      continue
    endif
    if index(a:lines, ol) < 0
      call insert(a:lines, ol, o)
    endif
  endfor
  return a:lines
endfun "}}}

""
" Function: s:previous_lines
"
" @param start: start line
" @return: the lines in the docstring before update
""
fun! s:previous_lines(start) abort
  " {{{1
  let lines = []
  let start = a:start
  let c = s:comment()[1]
  while 1
    if start == 1
      break
    elseif match(getline(start - 1), '^\V' . c) == 0
      call add(lines, getline(start - 1))
      exe (start - 1) . 'd _'
      let start -= 1
    else
      break
    endif
  endwhile
  call map(lines, 'substitute(v:val, "^\\V" . c . " ", "", "")')
  return reverse(filter(lines, 'v:val =~ "\\k"'))
endfun "}}}

fun! s:align(lines, name) abort
  " {{{1
  let maxlen = max(map(copy(a:lines), 'strlen(v:val =~ a:name ? "" : v:val)'))
  if maxlen > 50 " don't align if lines are too long
    return a:lines
  endif
  for l in range(len(a:lines))
    if a:lines[l] =~ '\V' . s:ph
      let spaces = repeat(' ', maxlen - strlen(a:lines[l]))
      let a:lines[l] = substitute(a:lines[l], '\V' . s:ph, spaces . s:ph, '')
    endif
  endfor
  return a:lines
endfun "}}}

fun! s:replace_comment() abort
  let startLn = 0
  if s:is_comment(line('.'))
    let [startLn, endLn] = [line('.'), line('.')]
    while s:is_comment(startLn - 1)
      let startLn -= 1
    endwhile
    while s:is_comment(endLn + 1)
      let endLn += 1
    endwhile
    let lines = getline(startLn, endLn)
    " strip the previous comment chars
    call map(lines, 'substitute(v:val, "^\\s*[[:punct:]]\\+\\s*", "", "")' )
    if empty(lines[0])
      call remove(lines, 0)
    endif
    if empty(lines[-1])
      call remove(lines, -1)
    endif
    exe startLn . ',' . endLn . 'd _'
  else
    let lines = ['']
  endif
  return lines
endfun

fun! s:create_box(lines, boxed, ...) abort
  " {{{1
  let [a, m, b] = s:comment()
  let rchar = a:0 ? a:1 : a == '/*' ? '*' : '='
  if a:boxed && a != b
    let box1 = a . repeat(rchar, &tw - strlen(a))
    let box2 = ' ' . repeat(rchar, &tw - strlen(a)) . trim(b)
  elseif a:boxed
    let box1 = m . repeat(rchar, &tw - strlen(a))
    let box2 = box1
  else
    let box1 = a . trim(m)
    let box2 = m . trim(b)
  endif
  call map(a:lines, 'v:val == "" || v:val == m ?'.
        \ '(v:val . m) : (m . " " . v:val)')
  return [box1] + a:lines + [box2]
endfun "}}}

" vim: et sw=2 ts=2 sts=2 fdm=marker tags=tags
