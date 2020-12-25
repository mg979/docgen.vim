" ========================================================================///
" Description: preservation of old lines when updating a comment
" File:        preserve.vim
" Author:      Gianmaria Bajo <mg1979@git.gmail.com>
" License:     MIT
" Created:     Mon 31 August 2020 23:32:44
" Modified:    Mon 31 August 2020 23:32:44
" ========================================================================///

""
" Function: docgen#preserve#lines
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
function! docgen#preserve#lines(oldlines) abort dict
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
  " we keep the lines that look similar
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
endfunction


""
" Function: s:fill_header
" Add lines from the old header that are absent from the new lines.
"
" @param new: the new lines
" @param old: the old lines
""
function! s:fill_header(new, old) abort
  for ix in range(len(a:old))
    let ol = a:old[ix]
    if ix >= len(a:new)
      call add(a:new, ol)
    elseif ol != a:new[ix]
      call insert(a:new, ol, ix)
    endif
  endfor
endfunction


""
" Function: s:fill_section
" Add lines from other sections that are absent from the new lines.
"
" @param new: the new lines
" @param old: the old lines
" @param pat: the pattern to skip (docstring keyword like @param)
""
function! s:fill_section(new, old, pat) abort
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
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim: et sw=2 ts=2 sts=2 fdm=marker
