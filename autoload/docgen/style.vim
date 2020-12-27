"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Styles
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""
" this class is linked inside the Doc instance (doc.style)
""

let s:Style = {
      \ 'fmt': {},
      \ 'docstyles': { -> ['default', 'boxed', 'simple', 'minimal'] },
      \ 'boxstyles': { -> ['simple', 'box', 'large_simple', 'large_box', 'fullbox', 'fullbox_centered'] },
      \}

""
" backup minimal formatters if something goes really out of its way
""
let s:Style._fmt = {
      \ 'header':  ['%s:%p'],
      \ 'params':  ['param %s: %p'],
      \ 'tparams': ['tparam %s: %p'],
      \ 'rtype':   ['return: %p'],
      \}

let s:Style.fmt.header = {
      \ 'boxed':    ['Function: %s%p', ''],
      \ 'default':  ['Function: %s%p', ''],
      \ 'simple':   ['%s:%p'],
      \ 'minimal':  ['%s:%p'],
      \}

let s:Style.fmt.params = {
      \ 'boxed':    ['param %s: %p'],
      \ 'default':  ['param %s: %p'],
      \ 'simple':   ['param %s: %p'],
      \ 'minimal':  ['param %s: %p'],
      \}

let s:Style.fmt.rtype = {
      \ 'boxed':    ['return: %p'],
      \ 'default':  ['return: %p'],
      \ 'simple':   ['return: %p'],
      \ 'minimal':  ['return: %p'],
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
" s:Style.choose
""
fun! s:Style.choose() abort
  "{{{1
  echohl Title
  echo 'Choose a docstring style:'
  echohl Comment
  echo '-------------------------'
  echohl None
  let pos = printf("Change position (current: %s)",
        \          self.doc.below() ? 'below' : 'above')
  let list = map(self.get_list() + [pos], { k,v -> (k+1) . '. ' . v })
  let npos = len(self.get_list()) + 1
  let choice = inputlist(list)
  if choice
    if choice == npos
      call self.change_below()
    else
      call self.change(choice - 1)
    endif
  endif
  redraw
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
" Echo current style settings in the command line.
""
fun! s:Style.echo() abort
  "{{{1
  let box = self.is_docstring ? '[docgen]' : '[docbox]'
  let blw = self.is_docstring && self.doc.below() ? '[below]' : ''
  echo box 'current style:' self.get_style() blw
endfun "}}}

""
" Currently active style for filetype.
""
fun! s:Style.get_style() abort
  "{{{1
  try
    return self.get_list()[self.get_current()]
  catch
    let list = self.get_list()
    return empty(list) ? 'minimal' : list[0]
  endtry
endfun "}}}

""
" Current index in the styles list.
""
fun! s:Style.get_current() abort
  "{{{1
  return self.is_docstring ? get(s:FT(), '_dg_current', 0)
        \                  : get(s:FT(), '_db_current', 0)
endfun "}}}

""
" Currently active styles list.
""
fun! s:Style.get_list() abort
  "{{{1
  return self.is_docstring ? get(s:FT(), 'docstyles', self.docstyles)() :
        \self.is_boxed     ? filter(copy(get(s:FT(), 'boxstyles', self.boxstyles)()), { k,v -> v =~ 'box' })
        \                  : filter(copy(get(s:FT(), 'boxstyles', self.boxstyles)()), { k,v -> v !~ 'box' })
endfun "}}}

""
" Function: s:Style.get_fmt
" This function tries to fetch a valid formatter for the current style, for the
" given section. This format will be used to generate templates. When the
" filetype defines its own formatter, it is returned as-is, otherwise the
" control character is added to the template (but not for the header).
"
" If the lookup fails, a backup (minimal) formatter is returned.
" This could happen, for example, if a filetype defines a style, but not the
" template for all sections.
"
" @param section: header, params or rtype
" @return: the unformatted template for the section
""
fun! s:Style.get_fmt(section) abort
  "{{{1
  let style = self.get_style()
  try
    " eg: s:vim.fmt.header.boxed
    return copy(s:FT().fmt[a:section][style])
  catch
    try
      " eg: self.fmt.header.boxed
      if a:section == 'header'
        return copy(self.fmt[a:section][style])
      else
        return map(copy(self.fmt[a:section][style]), 'v:val != "" ? self.doc.ctrlChar() . v:val : ""')
      endif
    catch
      " eg: self._fmt.header
      if a:section == 'header'
        return copy(self._fmt[a:section])
      else
        return map(copy(self._fmt[a:section]), 'v:val != "" ? self.doc.ctrlChar() . v:val : ""')
      endif
    endtry
  endtry
endfun "}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Helpers {{{1
let s:FT = function('docgen#doc#ft')

fun! docgen#style#get()
    return s:Style
endfun
"}}}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" vim: et sw=2 ts=2 sts=2 fdm=marker tags=tags
