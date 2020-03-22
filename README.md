# vim-buffer-ring

A circular, most-recently-used buffer navigator.

## Introduction

A buffer navigator, similar to Vim's builtin `:bn[ext]` and `:bp[revious]`,
but rather than ordering buffers by their numbers, buffers are ordered by
how recently they were edited (i.e., by most recently used, or MRU, order).

This plugin is derived from the first great buffer navigator,
[vim-bufsurf](http://github.com/ton/vim-bufsurf).

But with two tweaks:

1. Each buffer is only included once in the history list.

- In this plugin, each buffer is only listed once in the history.

  For instance, suppose the user opens the three files, 'foo', 'bar', and
  then 'baz', in that order. The history list has the following entries:


    ```
    [foo, bar, baz]
               ^^^
    ```

   where 'baz' (as indicated) is the current index. 

   If the users edits 'foo' again, rather than creating a fourth
   entry in the list, e.g.,

    ```
    [foo, bar, baz, foo]  # How vim-bufsurf works.
                    ^^^
    ```

   this plugin will remove the existing entry and reposition it, e.g.,:

    ```
    [bar, baz, foo]  # How this plugin, vim-buffer-ring, works.
               ^^^
    ```

   - The author prefers this behavior because they often use an `:edit #`
     mapping to jump back and forth between the same two buffers, which
     would otherwise end up creating a history like this:

      ```
      [foo, bar, baz, foo, baz, foo, baz, foo, baz, foo]  # How vim-bufsurf works.
                                                    ^^^
      ```

which makes walking backwards (say, to the 'bar' buffer) take longer.

2. This plugin wraps around the buffer history list, rather than
   stopping at the front or back of the list.

### Requirements

This plug-in requires Vim v8.0 or greater, to take advantage of timers.

## Usage

Call `:BufferRingReverse` to navigate to the previous buffer in the history:

  ```
    :BufferRingReverse
  ```

Call `:BufferRingForward` to navigate to the next buffer in the history:

  ```
  :BufferRingForward
  ```

You will probably want to wire this in your own Vim configuration
to whatever keys you like best.

- The author has these two commands wired to `<Ctrl-j>` and `<Ctrl-k>`, e.g.,

  ```
    noremap <C-j> :BufferRingReverse<CR>
    inoremap <C-j> <C-O>:BufferRingReverse<CR>
  ```

  and

  ```
    noremap <C-k> :BufferRingForward<CR>
    inoremap <C-k> <C-O>:BufferRingForward<CR>
  ```

Additional Commands:

Use `BufferRingList` to print the buffer history for the current window.

  ```
    :BufferRingList
  ```

Use `BufferRingClear` to clear the buffer history for the current window.

  ```
    :BufferRingClear
  ```

## Options

To set an option, include a line like the following in your `~/.vimrc`:

  ```
    let g:BufferRingIgnore = '\[BufExplorer\]'
  ```

The following options are available:

- `g:BufferRingIgnore` — comma separated list of patterns (default: '')

  A comma-separated list of regular expressions used to exclude buffers.
  Any buffer whose name matches any of the regular expressions in the list
  will be excluded from the buffer history. Note that unlisted buffers are
  always excluded from the history (this includes the netrw buffer, for
  instance).

- `g:BufferRingMessages` — Boolean value; either 0 or 1 (default: 1)

  Determines whether BufferRing messages are displayed in the status line.

## Installation

Take advantage of Vim's packages feature (`:h packages`), e.g.,:

  ```shell
  mkdir -p ~/.vim/pack/landonb/start
  cd ~/.vim/pack/landonb/start
  git clone https://github.com/landonb/vim-buffer-ring.git
  vim -u NONE -c "helptags vim-buffer-ring/doc" -c q
  ```

To load the plugin manually, install to
`~/.vim/pack/landonb/opt` instead and call
`:packadd vim-buffer-ring` when ready.

## License

Copyright 2020 Landon Bouma. All rights reserved. \
Copyright 2010-2012, 2017-2019 Ton van den Heuvel. All rights reserved.

This work is licensed under the MIT License.
View the [LICENSE](LICENSE) file for details.

