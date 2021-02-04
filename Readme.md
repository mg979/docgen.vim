## docgen.vim

Vim/neovim plugin for code documentation.

[![asciicast](https://asciinema.org/a/381326.svg)](https://asciinema.org/a/381326)

There is [vim-doge](https://github.com/kkoomen/vim-doge) already, how is this different?

Cons:

* less supported filetypes
* no javascript support
* no snippet-like placeholder switching

Pros:

* built-in support for c/cpp
* different commenting styles
* possible to update previous docstring
* command to create comment boxes, and to boxify current comments
* more flexible, and possibly easier to tweak/customize (if really needed)

## Supported filetypes (as of now):

* c
* c#
* cpp
* java
* go
* lua
* python
* ruby
* bash
* vim
* gdscript

For some filetypes (especially c#, cpp and jave) support may not be optimal,
please open an issue if you find some problem.

## Usage

Creating docstring is only possible in the supported filetypes, creating
comment boxes should work with any filetype.

The commands are:

|||
|-|-|
|DocGen`[!]` `[count]`|create docstring|
|DocBox`[!]` `[count]`|create comment box, or boxify current comment|

Or with mappings (example): 
```vim
nmap ,d <Plug>(DocGen)
nmap ,D <Plug>(DocGen!)
nmap ,x <Plug>(DocBox)
nmap ,X <Plug>(DocBox!)
```
When you create a docstring, placeholders will be added, and the `@/` register
will be set to the placeholder. You can edit them with `cgn`, or use a more
comfortable mapping, for example:
```vim
nnoremap <Space><Tab> cgn
```

## Styles

The flexibility comes from the usage of `bang` and `count` in both mappings and
commands.

#### docstring

There are 4 different styles for docstrings (using mappings from example):

|style|mapping|effect|
|-|-|-|
|'default'         |<kbd>1,d</kbd>|quite descriptive, using @brief tag|
|'boxed'           |<kbd>2,d</kbd>|same but boxed|
|'simple'          |<kbd>3,d</kbd>|similar but simpler|
|'minimal'         |<kbd>4,d</kbd>|just the function name, no parameters|

For c/cpp there are additional styles (`kernel`, `kernelboxed`,
`minimalboxed`). In c/cpp there is also support for structs, unions, etc.

Also remember that using a `count` *sets* a style, and it is remembered if you
then use the mapping *without* count.

Using the `bang` or uppercase mapping will show a list of available styles, and
also allow you to change where the docstring will be inserted (above or below
the function).

#### comment boxes

There are 6 different styles for boxes (using mappings from example):

|style|mapping|effect|
|-|-|-|
|'simple'          |<kbd>1,x</kbd>|a simple box, no frame|
|'large_simple'    |<kbd>2,x</kbd>|a large box, no frame|
|'box'             |<kbd>1,X</kbd>|a simple box, full frame|
|'large_box'       |<kbd>2,X</kbd>|a large box, full frame|
|'fullbox'         |<kbd>3,X</kbd>|convert a comment/box to a full box|
|'fullbox_centered'|<kbd>4,X</kbd>|it also centers the first line|

`fullbox` means that the edge on the right is also closed. It only works when
boxifying a previous comment, or converting a simpler box.

## Credits

[vim-doge](https://github.com/kkoomen/vim-doge) for some of the regex patterns, and for test templates.
