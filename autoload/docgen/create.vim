" ========================================================================///
" Description: creation of the docstring, with preservation of the old one
" File:        create.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     Mon 31 August 2020 23:32:44
" Modified:    Sat 26 December 2020 08:37:33
" ========================================================================///

function! docgen#create#box() abort
  return s:Doc
endfunction

let s:Doc = {}

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Remove previous docstring
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""
" Function: s:Doc.remove_previous
" @param start: the line where the command is started
" @return: the lines of the removed docstring, or an empty list
""
fun! s:Doc.remove_previous(start) abort
  " {{{1
  let lines = []
  let curr = a:start
  let next = self.below() ? 1 : -1
  let last = self.below() ? line('$') : 1
  while curr != last
    if self.is_comment(curr + next)
      let curr += next
      call add(lines, getline(curr))
      exe curr . 'd_'
    else
      break
    endif
  endwhile
  return reverse(lines)
endfun "}}}


""
" Function: s:Doc.previous_docstring
" @param start: start line
" @param below: whether the docstring will be added below the declaration
" @return: the lines in the docstring before update
""
fun! s:Doc.previous_docstring(start) abort
  " {{{1
  let lines = self.remove_previous(a:start)
  if !empty(lines)
    let c = self.comment()
    while trim(lines[0]) !~ '\k'
      call remove(lines, 0)
    endwhile
    while trim(lines[-1]) !~ '\k'
      call remove(lines, -1)
    endwhile
    for ix in range(len(lines))
      if lines[ix] !~ '\k'
        let lines[ix] = ''
      else
        try
          let lines[ix] = substitute(lines[ix], '^\V\s\*' . c[1] . '\+\s\?', '', '')
          let lines[ix] = substitute(lines[ix], '\V\s\+' . c[1] . '\_$', '', '')
        catch /.*/
        endtry
      endif
    endfor
  endif
  return lines
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
  let [a, m, b, _] = self.comment()[:3]
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
  let post = self.style.is_docstring ? self.comment()[4:] : []
  ""
  " Reformat the lines as comment. Top and bottom lines are not handled here.
  "   - empty line ? comment char(s)
  "   - no comment char(s) (eg. python docstrings)? just the line
  "   - both? concatenate comment chars and line, with a space in between
  ""
  call map(a:lines, 'v:val == "" ? m : m == "" ? v:val : (m . " " . v:val)')
  return [box1] + extra + a:lines + extra + [box2] + post
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
  let maxw = (&tw ? &tw : 79) - strdisplaywidth(ind) + strlen(ind)
  " executing DocBox on a previous comment and wanting a full box
  let is_boxifying_comment = !self.style.is_docstring &&
        \                     self.was_comment && self.style.fullbox

  for line in lines
    if strlen(line) > maxw
      let removeChars = printf('\V%s\{%s}', char, strlen(line) - maxw)
      let line = substitute(line, removeChars, '', '')
    endif
    if is_boxifying_comment && strlen(line) < maxw
      let line .= repeat(' ', maxw - strdisplaywidth(line) - strwidth(char)) . char
      if self.style.centered && i == first
        let cchar = trim(self.comment()[1])
        let ind = matchstr(line, '^\s*')
        let text = trim(matchstr(line, '^\V\s\*' . cchar . '\zs\.\*\ze' . char))
        let spaces = maxw - strlen(ind) - strdisplaywidth(text) - strwidth(char) - strwidth(cchar)
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
" Function: s:Doc.replace_comment
" Replace previous docstring with the new one.
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
    call map(lines, { k,v -> substitute(v, '^\s*[[:punct:]]\+\%(\s*\_$\|\s\)', '', '') })
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
" Function: s:Doc.preserve_oldlines
" Keep the valid lines of the previous docstring
"
" We break also oldlines in sections: we assume that parameters descriptions
" can span multiple lines, but new lines should not start with an uppercase
" letter. We assume instead that a paragraph with a long description starts
" with an uppercase letter, and will start the section 'detail'.
"
" @param oldlines: the old lines
" @return: the merged lines
""
function! s:Doc.preserve_oldlines(oldlines) abort
  " {{{1
  if self.is_storage
    return self.lines.header + a:oldlines[1:]
  endif

  let c = self.jollyChar()
  " the pattern that starts the 'detail' section
  let dpat = get(self, 'detailPat', '\s*\u')
  " the pattern that starts the 'return' section
  let rpat = '^\c\V' . c . '\?return\|rtype'
  " any other pattern with control char starts the 'params' section
  let ppat = '^\c\V' . c

  let oldlines = {'header': [], 'params': [], 'detail': [], 'return': []}
  let k = 'header'

  for ol in a:oldlines
    if ol =~ rpat
      let k = 'return'
    elseif ol =~ ppat
      let k = 'params'
    elseif k == 'params' && ol =~ dpat
      let k = 'detail'
    endif
    call add(oldlines[k], ol)
  endfor

  call s:transfer_equal_lines(self.lines, oldlines, self.placeholder())

  " here we handle extra edits, that is text inserted by the user
  call s:fill_header(self.lines.header, oldlines.header)
  call s:fill_section(self.lines.params, oldlines.params, ppat)
  call s:fill_section(self.lines.return, oldlines.return, rpat)

  if !empty(oldlines.detail)
    let self.lines.detail = oldlines.detail
  endif

  return self.lines.header + self.lines.params + self.lines.detail + self.lines.return
endfunction "}}}


""
" Function: s:transfer_equal_lines
" We keep the lines that look similar from the previous docstring.
"
" @param new: the new lines
" @param old: the old lines
""
function! s:transfer_equal_lines(new, old, ph) abort
  "{{{1
  for section in ['header', 'detail', 'params', 'return']
    for ix in range(len(a:new[section]))
      let line = substitute(a:new[section][ix], '\V'.escape(a:ph, '\'), '', 'g')
      for ol in a:old[section]
        if line != '' && ol =~ '^\V' . trim(line)
          let a:new[section][ix] = ol
          break
        endif
      endfor
    endfor
  endfor
endfunction "}}}


""
" Function: s:fill_header
" Add lines from the old header that are absent from the new lines.
"
" @param new: the new lines
" @param old: the old lines
""
function! s:fill_header(new, old) abort
  "{{{1
  for ix in range(len(a:old))
    let ol = a:old[ix]
    if ix >= len(a:new)
      call add(a:new, ol)
    elseif ol != a:new[ix]
      call insert(a:new, ol, ix)
    endif
  endfor
endfunction "}}}


""
" Function: s:fill_section
" Add lines from other sections that are absent from the new lines.
"
" @param new: the new lines
" @param old: the old lines
" @param pat: the pattern to skip (docstring keyword like @param)
""
function! s:fill_section(new, old, pat) abort
  "{{{1
  for ix in range(len(a:old))
    let ol = a:old[ix]
    if ol !~ a:pat
      if ix >= len(a:new)
        call add(a:new, ol)
      elseif ol != a:new[ix]
        call insert(a:new, ol, ix)
      endif
    endif
  endfor
endfunction "}}}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: et sw=2 ts=2 sts=2 fdm=marker
