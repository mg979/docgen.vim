" VARIABLES {{{1

let s:supported = ['vim', 'lua', 'python', 'sh', 'java', 'ruby', 'go', 'c', 'cpp']

let s:ph = '$' . 'PLACEHOLDER'

" }}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


""
" docgen#box: create a comment box, or convert an existing comment to a box
" @param bang: with full length frame
" @param cnt:  extra height of the box, both above and below
""
fun! docgen#box(bang, cnt) abort
  " {{{1
  let doc = s:new()
  let [rChar, is_comment] = [doc.get_comment()[3], s:is_comment(line('.'))]
  let indent = matchstr(getline('.'), '^\s*')
  let lines = doc.create_box(s:replace_comment(), a:bang, rChar, a:cnt)
  exe 'silent' (is_comment ? '-1': '') . 'put =lines'

  call s:reindent_box(lines, indent, rChar)
  normal! `[
  exe 'normal!' (a:cnt + 1) . 'j'
  " could be a converted comment
  let @= = is_comment ? '""' : '"A"'
endfun "}}}


""
" docgen#func: create or update template for function documentation
" @param bang: with full length frame
" @param count: set style
""
fun! docgen#func(bang, count) abort
  " {{{1
  let [ft, @=] = [split(&filetype, '\.')[0], '""']
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
    if a:count
      call doc.style.change(a:count - 1)
    else
      let doc.style.putBelow = !doc.get_putBelow()
      call doc.style.apply(1)
    endif
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

  " get the indent for the docstring
  let indent = matchstr(getline(doc.get_putBelow() ? startLn + 1 : startLn), '^\s*')

  " process params and return first, if absent the comment will be trimmed
  let doc.lines.params = doc.paramsLines()
  let doc.lines.return = doc.retLines()
  let doc.lines.desc = doc.descLines()

  let lines = doc.lines.desc + s:align(doc.lines.params) + doc.lines.return

  " keep the old lines of the previous docstring, if unchanged
  let lines = doc.preserve_oldlines( lines, doc.previous_docstring(startLn, doc.get_putBelow()) )

  " align placeholders and create box
  let lines = doc.create_box( lines, doc.get_boxed(), doc.get_frameChar(), 0 )

  exe 'silent ' ( doc.get_putBelow() ? '' : '-1' ) . 'put =lines'
  call s:reindent_box(lines, indent, doc.get_frameChar())

  " edit first placeholder, or go back to starting line if none is found
  normal! {
  if search(s:ph, '', startLn + len(lines))
    let @/ = s:ph
    let @= = '''"_cgn'''
  else
    let @= = '""'
    exe startLn
  endif
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Formatter initializer
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" s:new: start a new DocGen instance
" @return: the instance
""
fun! s:new() abort
  "{{{1
  let doc = extend(extend(deepcopy(s:Doc), s:{&filetype}),
        \                 get(b:, 'docgen', {}))
  " s:Style is static and changes to it persist across instantiations
  let doc.style = s:Style
  " so that s:Style can access the current instance
  let doc.style.doc = doc
  let doc.frameChar = doc.get_comment()[3]
  return doc
endfun "}}}

let s:Doc = {'lines': {}}

" default formatters for docstring lines
let s:Doc.nameFmt   = {
      \ 'boxed':    ['Function: %s' . s:ph, ''],
      \ 'nonboxed': ['Function: %s' . s:ph, ''],
      \ 'simple':   ['%s:' . s:ph],
      \ 'minimal':  ['%s:' . s:ph, ''],
      \}

let s:Doc.paramsFmt = ['param %s: ' . s:ph]
let s:Doc.rtypeFmt  = ['return: ' . s:ph]

" default patterns for function name, parameters, pre and post
let s:Doc.typePat   = '\(\)'
let s:Doc.namePat   = '\s*\([^( \t]\+\)'
let s:Doc.paramsPat = '\s*(\(.\{-}\))'
let s:Doc.rtypePat  = '\s*\(.*\)\?'

" default order for patterns, and the group they match in matchlist()
let s:Doc.order     = ['type', 'name', 'params', 'rtype']

let s:Doc.boxed     = 0
let s:Doc.minimal   = 0
let s:Doc.putBelow  = 0
let s:Doc.jollyChar = '@'


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Getters
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" getters that prefer b:docgen -> s:{&filetype} -> default

fun! s:get(what, doc, ...)
  "{{{1
  let a:doc[a:what] = get(s:bdoc(), a:what, get(s:{&filetype}, a:what, a:0 ? a:1 : a:doc[a:what]))
  return type(a:doc[a:what]) == v:t_func ? a:doc[a:what]() : a:doc[a:what]
endfun "}}}

fun! s:Doc.get_parsers() "{{{1
  return s:get('parsers', self)
endfun

fun! s:Doc.get_nameFmt() "{{{1
  return self.style._nameFmt
endfun

fun! s:Doc.get_paramsFmt() "{{{1
  return map(s:get('paramsFmt', self), { k,v -> v =~ '^param' ? self.jollyChar . v : v })
endfun

fun! s:Doc.get_paramsParse() "{{{1
  return s:get('paramsParse', self)
endfun

fun! s:Doc.get_rtypeFmt() "{{{1
  return map(s:get('rtypeFmt', self), { k,v -> v =~ '^r' ? self.jollyChar . v : v })
endfun

fun! s:Doc.get_typePat() "{{{1
  return s:get('typePat', self)
endfun

fun! s:Doc.get_namePat() "{{{1
  return s:get('namePat', self)
endfun

fun! s:Doc.get_paramsPat() "{{{1
  return s:get('paramsPat', self)
endfun

fun! s:Doc.get_rtypePat() "{{{1
  return s:get('rtypePat', self)
endfun

fun! s:Doc.get_frameChar() "{{{1
  return s:get('frameChar', self)
endfun

fun! s:Doc.get_comment() "{{{1
  return s:get('comment', self)
endfun

fun! s:Doc.get_putBelow() "{{{1
  return get(self.style, 'putBelow', s:get('putBelow', self))
endfun

fun! s:Doc.get_jollyChar() "{{{1
  return s:get('jollyChar', self)
endfun

fun! s:Doc.get_boxed() "{{{1
  return self.style.get_current() == 'boxed'
endfun

fun! s:Doc.get_minimal() "{{{1
  return self.style.get_current() == 'minimal'
endfun

fun! s:Doc.get_order() "{{{1
  return s:get('order', self)
endfun

fun! s:Doc.get_groups() abort "{{{1
  ""
  " The parser creates a list of matches based on the different subpatterns.
  " These subpatterns have a specific order, depending on the filetype.
  " Once the list of matches is created, the groups must be assigned to the right
  " variable, that depends on the position in the order.
  " For example, if 'type' comes first in the order, funcType must be the
  " variable that is assigned to the first matched group.
  "
  " @return: the groups that must be matched my matchlist()
  ""
  return s:get('groups', self, [
        \ index(self.order, 'type'),
        \ index(self.order, 'name'),
        \ index(self.order, 'params'),
        \ index(self.order, 'rtype'),
        \])
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Formatter methods
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:Doc.parse
" Parse the function declaration and get its name, parameters and return type.
"
" @param where: the line number with the function declaration, if found
" @return:      the line number with the function declaration
""
fun! s:Doc.parse(where) abort
  "{{{1
  if !a:where
    return 0
  endif
  let [g1, g2, g3, g4] = self.get_groups()
  let all  = matchlist(getline(a:where), self.pattern)[1:]
  let self.funcType    = trim(all[g1])
  let self.funcName    = trim(all[g2])
  let self.funcParams  = trim(all[g3])
  let self.funcRtype   = trim(all[g4])
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
  let emptyLn = search('^\s*$', 'cnbW')
  let minLn = emptyLn ? '\%>' . emptyLn . 'l' : ''
  for p in self.format_parsers()
    if !startLn || search(minLn . p, 'cnbW') > startLn
      let startLn = search(minLn . p, 'cnbW')
      let self.pattern = p
    endif
  endfor
  return startLn
endfun "}}}

""
" Function: s:Doc.format_parsers
" Build the parsers with printf(), replacing the placeholders with the specific
" patterns for the current filetype.
"
" @return: the formatted parsers
""
fun! s:Doc.format_parsers() abort
  "{{{1
  let d = self
  let pats = []
  let parsers = d.get_parsers()
  let [p1, p2, p3, p4] = self.ordered_patterns()
  for p in range(len(parsers))
    call add(pats, printf(parsers[p], p1, p2, p3, p4))
  endfor
  return pats
endfun "}}}

""
" Function: s:Doc.ordered_patterns
"
" @return: the patterns of the parser, in the order defined by the filetype
""
fun! s:Doc.ordered_patterns() abort
  "{{{1
  let o = self.get_order()
  return [ eval('self.get_'.o[0].'Pat()'),
        \  eval('self.get_'.o[1].'Pat()'),
        \  eval('self.get_'.o[2].'Pat()'),
        \  eval('self.get_'.o[3].'Pat()') ]
endfun "}}}

""
" Function: s:Doc.descLines
"
" @return: the formatted line(s) with the formatted description
""
fun! s:Doc.descLines() abort
  "{{{1
  let fmt = copy(self.get_nameFmt())

  let linesWithName = filter(copy(fmt), 'v:val =~ "%s"')
  if empty(linesWithName) | return fmt | endif

  let fname = printf(linesWithName[0], self.funcName)
  let type = self.funcType !~ '\S' ? '' : '[' . self.funcType . '] '

  if empty(self.lines.params) && empty(self.lines.return)
    return [fname]
  elseif self.style.get_current() == 'simple'
    return map(fmt, { k,v -> v =~ '%s' ? fname : v })
  else
    return map(fmt, { k,v -> v =~ '%s' ? type . fname : v })
  endif
endfun "}}}

""
" Function: s:Doc.paramsParse
" Parse the parameters string, remove unwanted parts, and return a list with
" the parameters names.
"
" @return: a list with the parameters names
""
fun! s:Doc.paramsParse() abort
  "{{{1
  let params = substitute(self.funcParams, '<.\{-}>', '', 'g')
  let params = substitute(params, '\s*=\s*[^,]\+', '', 'g')
  return split(params, ',')
endfun "}}}

""
" Function: s:Doc.paramsLines
"
" @return: the formatted line(s) with parameters
""
fun! s:Doc.paramsLines() abort
  "{{{1
  if empty(self.get_paramsFmt()) || self.get_minimal()
    return []
  endif
  let lines = []
  for par in self.paramsParse()
    for line in self.get_paramsFmt()
      call add(lines, line =~ '%s' ? printf(line, trim(par)) : line)
    endfor
  endfor
  return lines
endfun "}}}

""
" Function: s:Doc.retLines
"
" @return: the formatted line(s) with the return value
""
fun! s:Doc.retLines() abort
  "{{{1
  return self.get_minimal() ? [] : self.get_rtypeFmt()
endfun "}}}


""
" Function: s:Doc.comment
"
" @return: a list with four elements:
"          [0]  the opening multiline comment chars
"          [1]  the chars for lines in between
"          [2]  the closing multiline comment chars
"          [3]  a single char used for box frame
""
fun! s:Doc.comment()
  " {{{1
  let cm = &commentstring =~ '//\s*%s' ? '/*%s*/' : &commentstring
  let c = substitute(split(&commentstring, '%s')[0], '\s*$', '', '')
  return cm == '/*%s*/' ? ['/*', ' *', ' */', '*'] : [c, c, c, trim(c)[:0]]
endfun "}}}


""
" Function: s:Doc.preserve_oldlines
" Keep the valid lines of the previous docstring
"
" @param lines:    the new lines
" @param oldlines: the old lines
" @return: the merged lines
""
fun! s:Doc.preserve_oldlines(lines, oldlines) abort
  " {{{1
  " here we handle docstring generated lines, not extra edits
  " we compare the generated lines with the old lines, and we keep the ones
  " that look similar
  for l in range(len(a:lines))
    let line = substitute(a:lines[l], '\V' . s:ph, '', 'g')
    for ol in a:oldlines
      if line != '' && ol =~ '^\V' . trim(line)
        let a:lines[l] = ol
        break
      endif
    endfor
  endfor
  " here we handle extra edits, that is lines that have been inserted by the
  " user and that are not part of the generated docstring
  for o in range(len(a:oldlines))
    let ol = a:oldlines[o]
    " if the old line looks like @param, @rtype, etc, it's been generated and
    " we've already handled it
    if ol =~ s:docstring_words(['param', 'return', 'rtype'])
      continue
    endif
    if index(a:lines, ol) < 0
      call insert(a:lines, ol, o)
    endif
  endfor
  return a:lines
endfun "}}}


""
" Function: s:Doc.previous_docstring
"
" @param start: start line
" @param below: whether the docstring will be added below the declaration
" @return: the lines in the docstring before update
""
fun! s:Doc.previous_docstring(start, below) abort
  " {{{1
  let lines = []
  let start = a:start
  let c = self.get_comment()[1]
  if !a:below
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
  else
    while 1
      if start == line('$')
        break
      elseif match(getline(start + 1), '^\V' . c) == 0
        call add(lines, getline(start + 1))
        exe (start + 1) . 'd _'
        let start += 1
      else
        break
      endif
    endwhile
  endif
  call map(lines, 'substitute(v:val, "^\\V" . c . " ", "", "")')
  return reverse(filter(lines, 'v:val =~ "\\k"'))
endfun "}}}


""
" Function: s:Doc.create_box
" Create a box with the docstring
"
" @param lines: the docstring lines
" @param boxed: with full frame or not
" @param rchar: character used for full frame
" @param extraHeight: additional empty lines near the edges
" @return: the box lines
""
fun! s:Doc.create_box(lines, boxed, rchar, extraHeight) abort
  " {{{1
  let [a, m, b, _] = self.get_comment()
  let rwidth = &tw ? &tw : 79
  if a:boxed && a != b
    let box1 = a . repeat(a:rchar, rwidth - strlen(a))
    let box2 = ' ' . repeat(a:rchar, rwidth - strlen(a) - 1) . trim(b)
  elseif a:boxed
    let box1 = m . repeat(a:rchar, rwidth - strlen(a))
    let box2 = box1
  else
    let box1 = a . trim(m)
    let box2 = m . trim(b)
  endif
  let extra = map(range(a:extraHeight), { k,v -> m })
  call map(a:lines, 'v:val == "" || v:val == m ?'.
        \           '(v:val . m) : (m . " " . v:val)')
  return [box1] + extra + a:lines + extra + [box2]
endfun "}}}




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Styles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""
" this variable is linked inside the Doc instance, but not copied, so its
" values are supposed to persist between across instantiations.
""

let s:Style = {
      \   'list': ['nonboxed', 'boxed', 'simple', 'minimal'],
      \   'current': 0,
      \  }

""
" s:Style.change
" @param ...: change to given index
""
fun! s:Style.change(...) abort
  "{{{1
  if a:0
    let self.current = a:1 - 1
  endif
  if self.current >= len(self.get_list()) - 1
    let self.current = 0
  else
    let self.current += 1
  endif
  call self.apply(1)
endfun "}}}

""
" s:Style.apply
"
" Apply current style. If it's defined as a function in b:docgen or in the
" filetype, call that instead.
" @param ...: print current style
""
fun! s:Style.apply(...) abort
  "{{{1
  let [ft, current] = [get(b:, 'docgen', s:{&filetype}), self.get_current()]

  let self._nameFmt = has_key(ft, current)         ? ft[current]()
        \           : !has_key(ft, 'nameFmt')      ? s:Doc.nameFmt[current]
        \           : type(ft.nameFmt) == v:t_dict ? ft.nameFmt[current]
        \                                          : ft.nameFmt
  if a:0
    call self.echo()
  endif
endfun "}}}

""
" s:Style.get_current: return currently active style
""
fun! s:Style.get_current() abort
  "{{{1
  return self.get_list()[self.current]
endfun "}}}

""
" s:Style.get_list: return current styles list
""
fun! s:Style.get_list() abort
  "{{{1
  return get(s:bdoc(), 'styles', get(s:{&filetype}, 'styles', self.list))
endfun "}}}

""
" s:Style.echo: print current style settings
""
fun! s:Style.echo() abort
  let blw = self.putBelow ? '[below]' : ''
  echo '[docgen] current style:' self.get_list()[self.current] blw
endfun




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Filetype-specific
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Each filetype will define at least a list of function parsers.
" After that, each can provide specific members or methods.
""

let s:vim = {
      \ 'parsers': ['^fu\k*!\?\s%s%s%s%s'],
      \ 'frameChar': '=',
      \}

"{{{1
""
" don't add the @return line if no meaningful return value
""
fun! s:vim.retLines() abort
  return self.get_minimal() ? [] :
        \ search('return\s*[[:alnum:]_([{''"]', 'nW', search('^endf', 'nW'))
        \ ? self.get_rtypeFmt() : []
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:lua = {
      \ 'parsers': ['^%sfunction\s%s%s%s',
      \             '^%s%s\s*=\s*function%s%s'],
      \ 'typePat': '\(local\)\?\s*'
      \}

"{{{1
""
" don't add the @return line if no meaningful return value
""
fun! s:lua.retLines() abort
  return self.get_minimal() ? [] :
        \ search('return\s*[[:alnum:]_([{''"]', 'nW', search('^end', 'nW'))
        \ ? self.get_rtypeFmt() : []
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:python = {
      \ 'parsers': ['^\s*%s%s%s%s:'],
      \ 'typePat': '\(class\|def\)\s*',
      \ 'putBelow': 1,
      \ 'jollyChar': ':',
      \}

"{{{1
fun! s:python.rtypeFmt() abort
  let rtype = substitute(self.funcRtype, '\s*->\s*', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return ['return: ' . rtype . ' ' . s:ph]
endfun

fun! s:python.paramsParse() abort
  if empty(self.get_paramsFmt()) || self.get_minimal()
    return []
  endif
  let params = substitute(self.funcParams, '\s*=\s*[^,]\+', '', 'g')
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
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:sh = {
      \ 'parsers': ['^function\s%s%s%s%s', '^%s%s%s%s']
      \}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:java = {
      \ 'parsers': ['^\s*%s%s%s%s\s*[;{]'],
      \ 'typePat': '\(\%(public\|private\|protected\|static\|final\)\s*\)*',
      \ 'rtypePat': '\s*\(\S\+\)\s\+',
      \ 'order': ['type', 'rtype', 'name', 'params'],
      \}

"{{{1

fun! s:java.rtypeFmt() abort
  if self.funcRtype == 'void'
    return []
  elseif self.funcRtype !~ '\S'
    return ['return: ' . s:ph]
  else
    let rtype = substitute(self.funcRtype, '<.*>', '', '')
    return ['return ' . rtype . ': ' . s:ph]
  endif
endfun

"}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ruby = {
      \ 'parsers': ['^\s*def\s\+%s%s[=!]\?%s%s'],
      \ 'nameFmt': [s:ph]
      \}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


let s:go = {
      \ 'parsers': ['^func\s\+%s%s%s%s\s*{']
      \}

"{{{1
fun! s:go.rtypeFmt() abort
  let rtype = substitute(self.funcRtype, '^(', '', '')
  let rtype = substitute(rtype, ')$', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return ['return: ' . rtype . ' ' . s:ph]
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" s:is_comment: whether the line is a comment or not.
""
fun! s:is_comment(line) abort
  "{{{1
  return synIDattr(synID(a:line, indent(a:line) + 1, 1), "name") =~? 'comment'
endfun "}}}

""
" s:bdoc: get the buffer variable if defined.
""
fun! s:bdoc()
  " {{{1
  return get(b:, 'docgen', {})
endfun "}}}

""
" s:docstring_words: return a pattern that matches docstring-specific words
""
fun! s:docstring_words(words) abort
  " {{{1
  " the word preceded by an optional jollyChar and followed by a space
  let wordPatterns = map(a:words, { k,v -> '.\?' . v . ' ' })
  " join word patterns and make them optional
  return '^\%(' . join(wordPatterns, '\|') . '\)\?\S\+:'
endfun "}}}

""
" s:align: align placeholders in the given line.
"
" @param lines: the lines to align
" @param ...:   an optional pattern, if found the line is kept as it is
" @return:      the aligned lines
""
fun! s:align(lines, ...) abort
  " {{{1
  let maxlen = max(map(copy(a:lines), { k,v -> strlen(a:0 && v =~ a:1 ? "" : v) }))
  if maxlen > 50 " don't align if lines are too long
    return a:lines
  endif
  for l in range(len(a:lines))
    if a:0 && a:lines[l] =~ '\V' . a:1
      continue
    elseif a:lines[l] =~ '\V' . s:ph
      let spaces = repeat(' ', maxlen - strlen(a:lines[l]))
      let a:lines[l] = substitute(a:lines[l], '\V' . s:ph, spaces . s:ph, '')
    endif
  endfor
  return a:lines
endfun "}}}

""
" s:replace_comment: replace previous docstring with the new one.
"
" @return: the removed lines, if not empty
""
fun! s:replace_comment() abort
  "{{{1
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
    call map(lines, { k,v -> substitute(v, '^\s*[[:punct:]]\+\s*', '', '') })
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
endfun "}}}

""
" s:reindent_box
"
" @param lines:     the lines to reindent
" @param frameChar: the character used for the frame
""
fun! s:reindent_box(lines, indent, frameChar) abort
  "{{{1
  silent keepjumps normal! `[=`]
  let i = line('.')
  call map(a:lines, 'substitute(v:val, "^\s*", a:indent, "")')
  for line in a:lines
    let maxw = &tw ? &tw : 79
    if strlen(line) > maxw
      let removeChars = printf('\V%s\{%s}', a:frameChar, strlen(line) - maxw)
      let line = substitute(line, removeChars, '', '')
    endif
    call setline(i, line)
    let i += 1
  endfor
endfun "}}}

" vim: et sw=2 ts=2 sts=2 fdm=marker tags=tags
