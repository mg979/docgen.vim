" VARIABLES {{{1
let s:supported = ['vim', 'lua', 'python', 'sh', 'java', 'ruby',
      \            'go', 'vlang', 'c', 'cpp', 'cs', 'gdscript']
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
  let doc = docgen#doc#new(0)

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
  exe 'silent' (doc.was_comment || line('.') == 1 ? '-1': '') . 'put =lines'

  call doc.reindent_box(lines)
  normal! `[
  exe 'normal! zv'. (doc.style.extraHeight + 1) . 'j'
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

  let doc = docgen#doc#new(1)

  " with bang, we only change the current style, we don't parse anything
  if a:bang
    if a:count
      call doc.style.change(a:count - 1)
    else
      call doc.style.choose()
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
  let oldlines = doc.previous_docstring(startLn)
  let newlines = doc.preserve_oldlines(oldlines)

  " create new docstring
  let lines = doc.create_box(newlines)

  exe 'silent ' ( doc.below() ? '' : '-1' ) . 'put =lines'
  call doc.reindent_box(lines)

  " edit first placeholder, or go back to starting line if none is found
  let ph = doc.placeholder()
  normal! {
  if search(ph, '', startLn + len(lines))
    let @/ = ph
    let @= = '''"_cgn'''
  else
    let @= = '""'
    exe startLn
  endif
endfun "}}}



" vim: et sw=2 ts=2 sts=2 fdm=marker tags=tags
