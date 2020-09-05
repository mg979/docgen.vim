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
fun! docgen#box(bang, count) abort
  " {{{1
  let doc = s:new(0)

  " evaluate and apply docstring style
  let doc.style.is_boxed = a:bang
  if a:count
    call doc.style.change(a:count - 1)
    call doc.style.apply()
    call doc.style.echo()
  else
    call doc.style.apply()
  endif

  let doc.was_comment = doc.is_comment(line('.'))
  let lines = doc.create_box(doc.replace_comment())
  exe 'silent' (doc.was_comment ? '-1': '') . 'put =lines'

  call doc.reindent_box(lines)
  normal! `[
  exe 'normal!' (doc.style.extraHeight + 1) . 'j'
  " could be a converted comment
  let @= = doc.was_comment ? '""' : '"A "'
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

  let doc = s:new(1)

  " with bang, we only change the current style, we don't parse anything
  if a:bang
    if a:count
      call doc.style.change(a:count - 1)
    else
      call doc.style.change_below()
    endif
    call doc.style.echo()
    return
  endif

  " evaluate and apply docstring style
  if a:count
    call doc.style.change(a:count - 1)
    call doc.style.apply()
    call doc.style.echo()
  else
    call doc.style.apply()
  endif

  " if the parsers can't find a target, abort
  let startLn = doc.parse()
  if !startLn | return | endif

  " generate templates for docstring lines
  if !doc.is_storage
    call doc.make_templates()
  endif

  " move to the line with the function declaration
  exe startLn

  " generate the formatted lines
  call doc.format()

  " keep the old lines of the previous docstring, if unchanged
  let lines = doc.preserve_oldlines( doc.previous_docstring(startLn, doc.below()) )

  " align placeholders and create box
  let lines = doc.create_box(lines)

  exe 'silent ' ( doc.below() ? '' : '-1' ) . 'put =lines'
  call doc.reindent_box(lines)

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
" Docstring formatter initializer
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" The docstring is generated in several passages:
"
" 1. the parsers for the filetype are generated.
" 2. the parsers look for a potential target, if nothing is found the process
"     is aborted.
" 3. the style settings are evaluated, and raw (unformatted) templates for
"     lines are generated.
" 4. the target is parsed and a list of matches is the generated.
" 5. these matches are fed to the raw lines, that are formatted with printf()
"     using the matches as arguments.
"
" @member parsed:     parsed elements of the docstring (name, params, type, rtype)
"                     -> generated by doc.parse()
" @member templates:  unformatted templates for lines (header, params, rtype)
"                     -> generated by doc.templates()
" @member lines:      the formatted lines as they will be pasted in the buffer
"                     -> generated by doc.format()
""
let s:Doc = { 'parsed': {}, 'templates': {}, 'lines': {}, 'is_storage': 0 }


""
" s:new: start a new DocGen instance
" @return: the instance
""
fun! s:new(is_docstring) abort
  "{{{1
  " b:docgen can create a new s:{&filetype} variable, to add support for
  " unsupported filetypes
  if exists('b:docgen')
    let s:{&filetype} = extend(get(s:, &filetype, {}), b:docgen)
  endif

  let doc = extend(deepcopy(s:Doc), s:FT())
  let doc.style = s:Style
  let doc.style.is_docstring = a:is_docstring
  " so that s:Style can access the current instance
  let doc.style.doc = doc
  return doc
endfun "}}}




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Docstring formatter patterns
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" default formatters for docstring lines
let s:Doc.headerFmt   = { -> {
      \ 'boxed':    ['Function: %s' . s:ph, ''],
      \ 'default':  ['Function: %s' . s:ph, ''],
      \ 'simple':   ['%s:' . s:ph],
      \ 'minimal':  ['%s:' . s:ph],
      \} }

fun! s:Doc.paramsFmt()
  " {{{1
  return [self.jollyChar() . 'param %s: ' . s:ph]
endfun "}}}

fun! s:Doc.rtypeFmt()
  " {{{1
  return [self.jollyChar() . 'return: ' . s:ph]
endfun "}}}

" default patterns for function name, parameters, pre and post
let s:Doc.typePat   = { -> '\(\)' }
let s:Doc.namePat   = { -> '\s*\([^( \t]\+\)' }
let s:Doc.paramsPat = { -> '\s*(\(.\{-}\))' }
let s:Doc.rtypePat  = { -> '\s*\(.*\)\?' }

" default order for patterns, and the group they match in matchlist()
let s:Doc.order     = { -> ['type', 'name', 'params', 'rtype'] }

" default sections of the docstring
let s:Doc.sections  = { -> ['header', 'params', 'rtype'] }

" by default, no parsers for storage keywords
let s:Doc.storage      = { -> [] }
let s:Doc.storageLines = { -> [] }

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Docstring formatter styles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:Doc.boxed     = { -> 0 }
let s:Doc.minimal   = { -> 0 }
let s:Doc.putBelow  = { -> 0 }
let s:Doc.jollyChar = { -> '@' }

let s:Doc.leadingSpaceAfterComment = { -> 0 }

fun! s:Doc.frameChar()
  "{{{1
  return self.comment()[3]
endfun "}}}

fun! s:Doc.boxed()
  " {{{1
  return self.style.get_style() =~ 'box'
endfun "}}}

fun! s:Doc.minimal()
  " {{{1
  return self.style.get_style() == 'minimal'
endfun "}}}

fun! s:Doc.below()
  " {{{1
  return get(s:FT(), '_putBelow', self.putBelow())
endfun "}}}




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Docstring parser
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:Doc.parse
"
" Parse the target. If it's a function, parse its declaration and get its name,
" parameters and return type. If it's a storage type, it's handled elsewhere,
" just return the matching line.
"
" If it's a function, the parser creates a list of matches based on the
" different subpatterns. These subpatterns have a specific order, depending on
" the filetype. Once the list of matches is created, the groups must be
" assigned to the right variable in the right order, that is given by
" doc.order(). For example, if 'type' comes first in the order, parsed.type
" will be the variable that is assigned to the first matched group.
"
" Which variable will be assigned to which group, depends doc.order().
"
" @return: the line number with the function declaration
""
fun! s:Doc.parse() abort
  "{{{1
  let [self.startLn, self.endLn] = self.search_target()
  if !self.startLn
    return 0
  elseif self.is_storage
    return self.startLn
  endif
  let all  = matchlist(join(getline(self.startLn, self.endLn), "\n"), self.pattern)[1:]
  let ix = 0
  for group in self.order()
    let self.parsed[group] = substitute(trim(all[ix]), "\n", '', '')
    let ix += 1
  endfor
  return self.startLn
endfun "}}}


""
" Function: s:Doc.search_target
"
" Search the closest target upwards, if it can be found set the current pattern
" to the one that found it. When searching we don't move the cursor: we ensure
" that the match has a valid start and a valid end. The start must be on the
" same line or before it, the end can be after the current line. In both cases
" the searchs stops at empty lines, unless the search pattern includes '\n', in
" that case the search won't fail.
"
" @return: the line number with the docstring target
""
fun! s:Doc.search_target() abort
  "{{{1
  let [startLn, endLn] = [0, 0]

  let emptyLn = search('^\s*$', 'cnbW')
  let minLn = emptyLn ? '\%>' . emptyLn . 'l' : ''
  let emptyLn = search('^\s*$', 'cnW')
  let maxLn = emptyLn ? '\%<' . emptyLn . 'l' : ''
  let limit = minLn . maxLn

  for p in self.make_parsers()
    if !startLn || search(limit . p, 'cnbW') > startLn
      let startLn = search(limit . p, 'cnbW')
      let endLn = search(limit . p, 'cnbeW')
      if !endLn || endLn < startLn
        let endLn = search(limit . p, 'cneW')
      endif
      if !endLn
        let startLn = 0
      else
        let self.pattern = p
      endif
    endif
  endfor
  if !startLn
    let self.is_storage = 1
    for p in self.storage()
      if !startLn || search(limit . p, 'cnbW') > startLn
        let startLn = search(limit . p, 'cnbW')
        let endLn = search(limit . p, 'cnbeW')
        if !endLn || endLn < startLn
          let endLn = search(limit . p, 'cneW')
        endif
        if !endLn
          let startLn = 0
        else
          let self.pattern = p
        endif
      endif
    endfor
  endif
  return [startLn, endLn]
endfun "}}}


""
" Function: s:Doc.make_parsers
" Format the parsers with printf(), replacing the placeholders with the
" specific patterns for the current filetype.
"
" @return: the formatted parsers
""
fun! s:Doc.make_parsers() abort
  "{{{1
  let d = self
  let parsers = []
  let u_parsers = d.parsers()
  let pats = join(map(self.ordered_patterns(), { k,v -> string(v) }), ',')
  for p in range(len(u_parsers))
    let P = eval('printf(u_parsers[p],' . pats .')')
    call add(parsers, P)
  endfor
  return parsers
endfun "}}}


""
" Function: s:Doc.ordered_patterns
"
" @return: the patterns of the parser, in the order defined by the filetype
""
fun! s:Doc.ordered_patterns() abort
  "{{{1
  let s = self
  let o = self.order()
  return map(o, { k,v -> eval('s.'.o[k].'Pat()') })
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Docstring templates
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Doc.make_templates() abort
  let style = self.style.get_style()
  for x in self.sections()
    let fmt = eval('self.'.x.'Fmt()')
    let self.templates[x] = type(fmt) == v:t_dict ? fmt[style] : fmt
  endfor
endfun



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Docstring formatting
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Doc.format() abort
  if self.is_storage
    let self.lines.header = self.storageLines()
  elseif self.minimal()
    call filter(self.lines.header, { k,v -> v != '' })
  else
    " process params and return first, if absent the docstring could be reduced
    let self.lines.params = s:align(self.paramsLines())
    let self.lines.detail = self.detailLines()
    let self.lines.return = self.retLines()
    let self.lines.header = self.headerLines()
  endif
endfun

""
" Function: s:Doc.headerLines
"
" @return: the line(s) with the formatted description
""
fun! s:Doc.headerLines() abort
  "{{{1
  let header = self.templates.header

  " some text that doesn't contain %s placeholders, return it as it is
  let linesWithName = filter(copy(header), 'v:val =~ "%s"')
  if empty(linesWithName)
    return header
  endif

  " remove empty lines if no params nor return statement
  if empty(self.lines.params) && empty(self.lines.return)
    call filter(header, { k,v -> v != '' })
  endif

  return map(header, { k,v -> v =~ '%s' ? printf(v, self.parsed.name) : v })
endfun "}}}


""
" Function: s:Doc.paramsNames
" Parse the parameters string, remove unwanted parts, and return a list with
" the parameters names.
"
" @return: a list with the parameters names
""
fun! s:Doc.paramsNames() abort
  "{{{1
  if !has_key(self.parsed, 'params')
    return []
  endif
  let params = substitute(self.parsed.params, '<.\{-}>', '', 'g')
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
  let lines = []
  for param in self.paramsNames()
    for line in self.templates.params
      call add(lines, line =~ '%s' ? printf(line, trim(param)) : line)
    endfor
  endfor
  return lines
endfun "}}}


""
" Function: s:Doc.detailLines
" Additional lines for more detailed description. Empty by default.
"
" @return: the formatted line(s) with the placeholder.
""
fun! s:Doc.detailLines() abort
  "{{{1
  return []
endfun "}}}

""
" Function: s:Doc.retLines
" By default there's no text replacement in the return line, so the template is
" returned as it it.
"
" @return: the formatted line(s) with the return value
""
fun! s:Doc.retLines() abort
  "{{{1
  return self.templates.rtype
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
  return cm == '/*%s*/' ? ['/**', ' *', ' */', '*'] : [c, c, c, trim(c)[:0]]
endfun "}}}


let s:Doc.preserve_oldlines = function('docgen#preserve#lines')


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
  if !a:below
    while 1
      if start == 1
        break
      elseif self.is_comment(start - 1)
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
      elseif self.is_comment(start + 1)
        call add(lines, getline(start + 1))
        exe (start + 1) . 'd _'
        let start += 1
      else
        break
      endif
    endwhile
  endif
  if !empty(lines)
    let c = self.comment()
    if trim(lines[0]) == c[0]
      call remove(lines, 0)
    endif
    if trim(lines[-1]) == c[2]
      call remove(lines, -1)
    endif
    for ix in range(len(lines))
      if lines[ix] !~ '\k'
        let lines[ix] = ''
      else
        let lines[ix] = substitute(lines[ix], '^\V' . c[1] . '\+ ', '', '')
      endif
    endfor
  endif
  return reverse(lines)
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
fun! s:Doc.create_box(lines) abort
  " {{{1
  let [a, m, b, _] = self.comment()
  let rwidth = &tw ? &tw : 79
  let char = self.frameChar()
  if self.boxed() && a == '/**'
    let box1 = a . repeat(char, rwidth - strlen(a))
    let box2 = ' ' . repeat(char, rwidth - strlen(b)) . trim(b)
  elseif self.boxed()
    if !self.style.is_docstring && self.leadingSpaceAfterComment()
      let [a, b] = [a . ' ', b . ' ']
    endif
    let box1 = a . repeat(char, rwidth - strlen(a))
    let box2 = b . repeat(char, rwidth - strlen(b))
  else
    let box1 = a
    let box2 = b
  endif
  let extra = map(range(self.style.extraHeight), { k,v -> m })
  ""
  " Reformat the lines as comment. Top and bottom lines are not handled here.
  "   - empty line ? comment char(s)
  "   - no comment char(s) (eg. python docstrings)? just the line
  "   - both? concatenate comment chars and line, with a space in between
  ""
  call map(a:lines, 'v:val == "" ? m : m == "" ? v:val : (m . " " . v:val)')
  return [box1] + extra + a:lines + extra + [box2]
endfun "}}}


""
" Function: s:Doc.reindent_box
"
" @param lines: the lines to reindent
""
fun! s:Doc.reindent_box(lines) abort
  "{{{1
  silent keepjumps normal! `[=`]
  let ind = matchstr(getline('.'), '^\s*')
  let lines = map(a:lines, "substitute(v:val, '^\s*', ind, '')")
  let [first, i, char] = [line('.') + 1, line('.'), self.frameChar()]
  let maxw = &tw ? &tw : 79
  " executing DocBox on a previous comment and wanting a full box
  let is_boxifying_comment = !self.style.is_docstring &&
        \                     self.was_comment && self.style.fullbox

  for line in lines
    if strwidth(line) > maxw
      let removeChars = printf('\V%s\{%s}', char, strlen(line) - maxw)
      let line = substitute(line, removeChars, '', '')
    endif
    if is_boxifying_comment && strwidth(line) < maxw
      let line .= repeat(' ', maxw - strwidth(line) - strwidth(char)) . char
      if self.style.centered && i == first
        let cchar = trim(self.comment()[1])
        let ind = matchstr(line, '^\s*')
        let text = trim(matchstr(line, '^\V\s\*' . cchar . '\zs\.\*\ze' . char))
        let spaces = maxw - strlen(ind) - strwidth(text) - strwidth(char) - strwidth(cchar)
        let s = repeat(' ', spaces/2)
        let [s1, s2] = spaces % 2 ? [s, s . ' '] : [s, s]
        let line = ind . cchar . s1 . text . s2 . char
      endif
    endif
    call setline(i, line)
    let i += 1
  endfor
endfun "}}}


""
" Function: s:Doc.is_comment
"
" @param line: the line to evaluate
" @return: if the evaluated line is a comment (or a docstring)
""
fun! s:Doc.is_comment(line) abort
  "{{{1
  return synIDattr(synID(a:line, indent(a:line) + 1, 1), "name") =~? 'comment'
endfun "}}}


""
" Function: s:Doc.replace_comment
" Replace previous docstring with the new one.
"
" @return: the removed lines, if not empty
""
fun! s:Doc.replace_comment() abort
  "{{{1
  let startLn = 0
  if self.is_comment(line('.'))
    let [startLn, endLn] = [line('.'), line('.')]
    while self.is_comment(startLn - 1)
      let startLn -= 1
    endwhile
    while self.is_comment(endLn + 1)
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



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Styles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""
" this class is linked inside the Doc instance (doc.style)
""

let s:Style = {
      \  'docstyles': { -> ['default', 'boxed', 'simple', 'minimal'] },
      \  'boxstyles': { -> ['simple', 'box', 'large_simple', 'large_box', 'fullbox', 'fullbox_centered'] },
      \}

""
" s:Style.change
" @param ...: change style to given index
""
fun! s:Style.change(...) abort
  "{{{1
  let ft = s:FT()
  let v = self.is_docstring ? '_dg_current' : '_db_current'
  if a:0
    let ft[v] = a:1 - 1
  else
    let ft[v] = self.get_current()
  endif
  if ft[v] >= len(self.get_list()) - 1
    let ft[v] = 0
  else
    let ft[v] += 1
  endif
endfun "}}}

""
" s:Style.change_below
"
" Toggle the variable that controls whether the docstring is added below or
" above the target. We set a filetype variable, so that this setting persits
" only for files of the same type.
""
fun! s:Style.change_below() abort
  "{{{1
  let ft = s:FT()
  let ft._putBelow = !self.doc.below()
endfun "}}}

""
" s:Style.apply
"
" Apply current style, generating templates for lines, and make it persistent
" for filetype.
""
fun! s:Style.apply() abort
  "{{{1
  let style = self.get_style()
  if self.is_docstring
    let self.extraHeight = 0
    let self.centered = 0
    let self.fullbox = 0
  else
    let self.extraHeight = style == 'large_simple' || style == 'large_box'
    let self.centered = style == 'fullbox_centered'
    let self.fullbox = style =~ 'fullbox'
  endif
endfun "}}}

""
" s:Style.echo: echo current style settings in the command line
""
fun! s:Style.echo() abort
  "{{{1
  let box = self.is_docstring ? '[docgen]' : '[docbox]'
  let blw = self.is_docstring && self.doc.below() ? '[below]' : ''
  echo box 'current style:' self.get_style() blw
endfun "}}}

""
" s:Style.get_style: currently active style for filetype
""
fun! s:Style.get_style() abort
  "{{{1
  try
    return self.get_list()[self.get_current()]
  catch
    return self.get_list()[0]
  endtry
endfun "}}}

""
" s:Style.get_current: current index in the styles list
""
fun! s:Style.get_current() abort
  "{{{1
  return self.is_docstring ? get(s:FT(), '_dg_current', 0)
        \                  : get(s:FT(), '_db_current', 0)
endfun "}}}

""
" s:Style.get_list: currently active styles list
""
fun! s:Style.get_list() abort
  "{{{1
  return self.is_docstring ? get(s:FT(), 'docstyles', self.docstyles)() :
        \self.is_boxed     ? filter(copy(get(s:FT(), 'boxstyles', self.boxstyles)()), { k,v -> v =~ 'box' })
        \                  : filter(copy(get(s:FT(), 'boxstyles', self.boxstyles)()), { k,v -> v !~ 'box' })
endfun "}}}




"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Filetype-specific
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Each filetype will define at least a list of function parsers.
" After that, each can provide specific members or methods.
""

let s:c = {
      \ 'parsers':   { -> ['^%s%s\n\?%s%s\s*\n\?[{;]'] },
      \ 'typePat':   { -> '\(\%(extern\|static\|inline\)\s*\)*' },
      \ 'rtypePat':  { -> s:c_rpat() },
      \ 'namePat':   { -> '\(\w\+\)' },
      \ 'paramsPat': { -> '\s*(\(\_.\{-}\))' },
      \ 'order':     { -> ['type', 'rtype', 'name', 'params'] },
      \ 'docstyles': { -> ['kernel', 'kernelboxed', 'default', 'boxed', 'simple', 'minimal'] },
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
  let [rtype, ch] = [self.parsed.rtype, self.jollyChar()]
  return {
        \ 'kernel':      ['Returns ' . rtype . ': ' . s:ph],
        \ 'kernelboxed': ['Returns ' . rtype . ': ' . s:ph],
        \ 'boxed':       [ch . 'return ' . rtype . ': ' . s:ph],
        \ 'default':     [ch . 'return ' . rtype . ': ' . s:ph],
        \ 'simple':      [ch . 'return: ' . s:ph],
        \ 'minimal':     [],
        \}
endfun

fun! s:c.paramsFmt() abort
  let ch = self.jollyChar()
  return {
        \ 'kernel':      [ch . '%s: ' . s:ph],
        \ 'kernelboxed': [ch . '%s: ' . s:ph],
        \ 'boxed':       [ch . 'param %s: ' . s:ph],
        \ 'default':     [ch . 'param %s: ' . s:ph],
        \ 'simple':      ['%s', s:ph],
        \ 'minimal':     ['%s:' . s:ph],
        \}
endfun

fun! s:c.headerFmt()
  let ch = self.jollyChar()
  return {
        \ 'kernel':      ['%s() - ' . s:ph],
        \ 'kernelboxed': ['%s() - ' . s:ph],
        \ 'boxed':       [ch . 'brief %s: ' . s:ph],
        \ 'default':     [ch . 'brief %s: ' . s:ph],
        \ 'simple':      ['%s', s:ph],
        \ 'minimal':     ['%s:' . s:ph],
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
  let names = []
  for p in split(params, ',')
    let _p = split(p)
    if len(_p) > 1
      call add(names, substitute(_p[-1], '^[*&]', '', ''))
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
  return self.style.get_style() =~ 'kernel' ? ['', s:ph] : []
endfun

fun! s:c.headerLines() abort
  let header = self.templates.header
  if empty(self.lines.params) && empty(self.lines.return)
    return [ self.parsed.name . ':' . s:ph ]
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
  " enum name {...};
  call add(storage, '^\s*\(\w\+\)\s\+\(\w\+\)\s*[{;]')
  " generic variable definition
  call add(storage, '^\s*\(\w\+\)\s\+\([^=]\+\);')
  return storage
endfun

fun! s:c.storageLines() abort
  let all = matchlist(join(getline(self.startLn, self.endLn), "\n"), self.pattern)
  let type = all[1]
  let name = all[2]
  if getline(self.startLn) =~ 'typedef'
    return ['typedef ' . trim(name) . ': ' .s:ph]
  elseif name != ''
    return [trim(type) . ' ' . trim(name) . ': ' . s:ph]
  else
    return [trim(type) . ': ' . s:ph]
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
  let ch = self.jollyChar()
  return {
        \ 'kernel':      [ch . '%s: ' . s:ph],
        \ 'kernelboxed': [ch . '%s: ' . s:ph],
        \ 'boxed':       [ch . 'tparam %s: ' . s:ph],
        \ 'default':     [ch . 'tparam %s: ' . s:ph],
        \ 'simple':      ['%s: ' . s:ph],
        \ 'minimal':     [],
        \}
endfun

fun! s:cpp.headerFmt()
  let m = matchstr(getline(self.startLn), '^\s*\%(\w\+\s*\)\?\zs\w\+\ze::')
  let f = m == '' ? 'Function' : '[' . m . '] Method'
  let s = m == '' ? '' : m . '.'
  return {
        \ 'kernel':      [s . '%s() - ' . s:ph],
        \ 'kernelboxed': [s . '%s() - ' . s:ph],
        \ 'boxed':       [self.jollyChar() . 'brief %s: ' . s:ph, ''],
        \ 'default':     [self.jollyChar() . 'brief %s: ' . s:ph, ''],
        \ 'simple':      [s . '%s:' . s:ph],
        \ 'minimal':     [s . '%s:' . s:ph, ''],
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
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:vim = {
      \ 'parsers': { -> ['^fu\k*!\?\s%s%s%s%s'] },
      \ 'comment': { -> ['""', '"', '""', '='] }
      \}

"{{{1
fun! s:vim.frameChar() abort
  return self.style.is_docstring ? '=' : '"'
endfun

fun! s:vim.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^endf', 'nW'))
        \ ? self.templates.rtype : []
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:lua = {
      \ 'parsers': { -> ['^%sfunction\s%s%s%s', '^%s%s\s*=\s*function%s%s'] },
      \ 'typePat': { -> '\(local\)\?\s*' },
      \ 'comment': { -> ['----', '--', '----', '-'] }
      \}

"{{{1
fun! s:lua.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^end', 'nW'))
        \ ? self.templates.rtype : []
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:python = {
      \ 'parsers':   { -> ['^\s*%s%s%s%s:'] },
      \ 'typePat':   { -> '\(class\|def\)\s*' },
      \ 'putBelow':  { -> 1 },
      \ 'jollyChar': { -> ':' },
      \ 'leadingSpaceAfterComment': { -> 1 },
      \}

"{{{1
fun! s:python.rtypeFmt() abort
  let rtype = substitute(self.parsed.rtype, '\s*->\s*', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return [self.jollyChar() . 'return: ' . rtype . ' ' . s:ph]
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
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:sh = {
      \ 'parsers': { -> ['^\s*function\s*%s\n\?\s*{', '^\s*%s()\n\?\s*{'] },
      \ 'order':    { -> ['name'] },
      \ 'comment': { -> ['#', '#', '#', '-'] }
      \}

"{{{1
fun! s:sh.retLines() abort
  return search('return\s*[[:alnum:]_([{''"]', 'nW', search('^\s*}', 'nW'))
        \ ? self.templates.rtype : []
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:java = {
      \ 'parsers':  { -> ['^\s*%s%s%s%s\s*[;{]'] },
      \ 'typePat':  { -> '\(\%(public\|private\|protected\|static\|final\)\s*\)*' },
      \ 'rtypePat': { -> '\s*\([[:punct:][:alnum:]]\+\)\?\s\+' },
      \ 'order':    { -> ['type', 'rtype', 'name', 'params'] },
      \}

"{{{1

fun! s:java.rtypeFmt() abort
  if self.parsed.rtype == 'void' || self.parsed.rtype == ''
    return []
  elseif self.parsed.rtype !~ '\S'
    return [self.jollyChar() . 'return: ' . s:ph]
  else
    let rtype = substitute(self.parsed.rtype, '<.*>', '', '')
    return [self.jollyChar() . 'return ' . rtype . ': ' . s:ph]
  endif
endfun

"}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:ruby = {
      \ 'parsers': { -> ['^\s*def\s\+%s%s[=!]\?%s%s'] },
      \ 'headerFmt': { -> [s:ph] },
      \ 'comment': { -> ['#', '#', '#', '-'] }
      \}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


let s:go = {
      \ 'parsers':   { -> ['^func\s\+%s%s%s%s\s*{'] },
      \ 'namePat':   { -> '\s*\%((.\{-})\s*\)\?\([^( \t]\+\)' },
      \ 'paramsPat': { -> '\s*(\(.\{-}\))' },
      \ 'rtypePat':  { -> '\s*\(.*\)\?' },
      \}

"{{{1
fun! s:go.headerFmt()
  let m = matchstr(getline(self.startLn), '^\s*func\s*(.\{-}\s\+\*\?\zs.\{-}\ze)')
  let f = m == '' ? 'Function' : '[' . m . '] Method'
  let s = m == '' ? '' : m . '.'
  return {
      \ 'boxed':    [f . ': %s' . s:ph, ''],
      \ 'default':  [f . ': %s' . s:ph, ''],
      \ 'simple':   [s . '%s:' . s:ph],
      \ 'minimal':  [s . '%s:' . s:ph, ''],
      \}
endfun

fun! s:go.rtypeFmt() abort
  let rtype = substitute(self.parsed.rtype, '^(', '', '')
  let rtype = substitute(rtype, ')$', '', '')
  let rtype = empty(rtype) ? '' : '[' . trim(rtype) . ']'
  return [self.jollyChar() . 'return: ' . rtype . ' ' . s:ph]
endfun

fun! s:go.paramsNames() abort
  let params = substitute(self.parsed.params, '<.\{-}>', '', 'g')
  let params = substitute(params, '\s*=\s*[^,]\+', '', 'g')
  return map(split(params, ','), { k,v -> split(v)[0] })
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" the filetype-specific settings, if available
""
fun! s:FT()
  return get(s:, &filetype, {})
endfun

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

" vim: et sw=2 ts=2 sts=2 fdm=marker tags=tags
