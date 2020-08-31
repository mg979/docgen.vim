## docgen.vim

Vim/neovim plugin for code documentation.

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

* c/cpp
* java
* go
* lua
* python
* ruby
* bash
* vim

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

There are 4 different styles for docstrings (using mappings from example):

|style|mapping|effect|
|-|-|-|
|'default'         |<kbd>1,d</kbd>|quite descriptive, using @brief tag|
|'boxed'           |<kbd>2,d</kbd>|same but boxed|
|'simple'          |<kbd>3,d</kbd>|similar but simpler|
|'minimal'         |<kbd>4,d</kbd>|just the function name, no parameters|

For c/cpp there are 2 additional styles (`kernel`, `kernelboxed`) that are
actually the default (the other styles are still accessible increasing the
`count`). In c/cpp there is also support for structs, unions, etc.

Also remember that using a `count` *sets* a style, and it is remembered if you
then use the mapping *without* count.

Using the `bang` or uppercase mapping has a different effect: it doesn't create
the docstring, but sets the style to the chosen one (== `count`). With no
`count` it toggles between `above`/`below`, that is the position where the
docstring will be added (eg `python` defaults to `below`, but you can have the
same with any supported filetype).

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

## Documentation

For now it's all here. Experiment with the mappings (especially with `count`)
and find the style you like best.

## Customization

Yes it's possible, but maybe later. Ask if you need something.

## Contributing

Want to add support for more filetypes? Read the code and send a PR.

## Credits

[vim-doge](https://github.com/kkoomen/vim-doge) for some of the regex patterns, and for test templates.