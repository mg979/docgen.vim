""
" docgen#doc#new: start a new DocGen instance
" @return: the instance
""
fun! docgen#doc#new(is_docstring) abort
  "{{{1
  let doc = extend(deepcopy(s:Doc), docgen#create#box())

  call extend(doc, s:FT())

  let doc.style = docgen#style#get()
  let doc.style.is_docstring = a:is_docstring
  let doc.style.doc = doc " s:Style can now access the current instance
  return doc
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
" @member custom:     custom templates for lines (header, params, rtype)
"                     -> provided directly by filetype and not generated
" @member lines:      the formatted lines as they will be pasted in the buffer
"                     -> generated by doc.format()
""
let s:Doc = { 'parsed': {}, 'templates': {}, 'custom': {}, 'lines': {}, 'is_storage': 0 }


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Docstring formatter patterns
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

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

let s:Doc.putBelow                 = { -> 0 }
let s:Doc.ctrlChar                 = { -> '@' }
let s:Doc.placeholder              = { -> '___' }
let s:Doc.leadingSpaceAfterComment = { -> 0 }
let s:Doc.alignParameters          = { -> 1 }
let s:Doc.drawFrame                = { -> 1 }

""
" The character used for the frame in boxed docstrings.
""
fun! s:Doc.frameChar()
  "{{{1
  return self.comment()[3]
endfun "}}}

""
" These functions fetch the format for the active style in doc.style.fmt[type]
" A default (minimal) formatter is returned if this fails for some reason.
""

fun! s:Doc.headerFmt()
  " {{{1
  return self.style.get_fmt('header')
endfun "}}}

fun! s:Doc.paramsFmt()
  " {{{1
  return self.style.get_fmt('params')
endfun "}}}

fun! s:Doc.rtypeFmt()
  " {{{1
  return self.style.get_fmt('rtype')
endfun "}}}

""
" Docstring is of box type.
""
fun! s:Doc.boxed()
  " {{{1
  return self.style.get_style() =~ 'box'
endfun "}}}

""
" Minimal docstring.
""
fun! s:Doc.minimal()
  " {{{1
  return self.style.get_style() == 'minimal'
endfun "}}}

""
" Docstring will be put below the declaration.
""
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
  "{{{1
  let style = self.style.get_style()
  let ph = self.placeholder()
  for sect in self.sections()
    let default = eval('self.'.sect.'Fmt()')
    let fmt = get(self.custom, sect, default)
    let self.templates[sect] = type(fmt) == v:t_dict ? get(fmt, style, default) : fmt
    call map(self.templates[sect], 'substitute(v:val, "%p", ph, "")')
  endfor
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Docstring formatting
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:Doc.format
" Generate the docstring lines from the formatters of the different sections.
""
fun! s:Doc.format() abort
  "{{{1
  if self.is_storage
    let self.lines.header = self.storageLines()
  elseif self.minimal()
    let self.lines.params = []
    let self.lines.detail = []
    let self.lines.return = []
    let self.lines.header = filter(self.headerLines(), { k,v -> v != '' })
  else
    " process params and return first, if absent the docstring could be reduced
    if self.alignParameters()
      let self.lines.params = s:align(self.paramsLines(), self.placeholder())
    else
      let self.lines.params = self.paramsLines()
    endif
    let self.lines.detail = self.detailLines()
    let self.lines.return = self.retLines()
    let self.lines.header = self.headerLines()
  endif
endfun "}}}

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
  let cs = empty(&commentstring) ? '/*%s*/' : &commentstring
  let cm = cs =~ '//\s*%s' ? '/*%s*/' : cs
  let c = substitute(split(cs, '%s')[0], '\s*$', '', '')
  return cm == '/*%s*/' ? ['/**', ' *', ' */', '*'] : [c, c, c, '-']
endfun "}}}


""
" Function: s:Doc.is_comment
"
" @param line: the line to evaluate
" @return: if the evaluated line is a comment (or a docstring)
""
fun! s:Doc.is_comment(line) abort
  "{{{1
  return synIDattr(synID(a:line, match(getline(a:line), '\S') + 1, 1), "name") =~? 'comment'
endfun "}}}



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Filetype-specific
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Each filetype will define at least a list of function parsers.
" After that, each can provide specific members or methods.
""

let s:vim    = docgen#ft#vim#get()
let s:c      = docgen#ft#c#get('c')
let s:cpp    = docgen#ft#c#get('cpp')
let s:cs     = docgen#ft#cs#get()
let s:python = docgen#ft#python#get()
let s:lua    = docgen#ft#lua#get()
let s:sh     = docgen#ft#sh#get()
let s:java   = docgen#ft#java#get()
let s:ruby   = docgen#ft#ruby#get()
let s:go     = docgen#ft#go#get()
let s:gdscript = docgen#ft#gdscript#get()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Helpers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" The filetype-specific settings, if available.
""
fun! docgen#doc#ft()
  " b:docgen can add customizations or support for unsupported filetypes {{{1
  return extend(get(s:, &filetype, {}), get(b:, 'docgen', {}))
endfun

let s:FT = function('docgen#doc#ft')
 "}}}

""
" s:align: align placeholders in the given line.
"
" @param lines: the lines to align
" @param ...:   an optional pattern, if found the line is kept as it is
" @return:      the aligned lines
""
fun! s:align(lines, ph, ...) abort
  " {{{1
  let maxlen = max(map(copy(a:lines), { k,v -> strlen(a:0 && v =~ a:1 ? "" : v) }))
  if maxlen > 50 " don't align if lines are too long
    return a:lines
  endif
  for l in range(len(a:lines))
    if a:0 && a:lines[l] =~ '\V' . a:1
      continue
    elseif a:lines[l] =~ '\V' . a:ph
      let spaces = repeat(' ', maxlen - strlen(a:lines[l]))
      let a:lines[l] = substitute(a:lines[l], '\V' . a:ph, spaces . a:ph, '')
    endif
  endfor
  return a:lines
endfun "}}}

" vim: et sw=2 ts=2 sts=2 fdm=marker tags=tags
