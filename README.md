# vim-buffer-ring 💍

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

This plug-in works on Neovim, or requires Vim v8.0 or greater, to take advantage of timers.

## Usage

- Call `:BufferRingReverse` to navigate to the previous buffer in the history:

  ```
    :BufferRingReverse
  ```

- Call `:BufferRingForward` to navigate to the next buffer in the history:

  ```
  :BufferRingForward
  ```

Additional Commands:

- Use `BufferRingList` to print the buffer history for the current window.

  ```
    :BufferRingList
  ```

- Use `BufferRingClear` to clear the buffer history for the current window.

  ```
    :BufferRingClear
  ```

### Neovim `lazy.nvim` config

The author wires `<Ctrl-;>` and `<Ctrl-'>` to reverse and forward through
the buffer-ring, and `<LocalLeader>dB` to show buffer-ring internals, e.g.:

  ```
    {
      "landonb/vim-buffer-ring",
      event = "VeryLazy",

      config = function()
        require("which-key").add({
          icon = "🪐",
          {
            "<C-;>",
            "<cmd>:BufferRingReverse<CR>",
            desc = "Buffer Ring Reverse",
            mode = { "n", "i" },
          },
          {
            "<C-'>",
            "<cmd>:BufferRingForward<CR>",
            desc = "Buffer Ring Forward",
            mode = { "n", "i" },
          },
          {
            "<localleader>dB",
            mode = { "n", "i" },
            '<cmd>lua vim.api.nvim_call_function("g:embrace#bufsurf#BufferRingListAll", {})<CR>',
            desc = "Inspect Buffer-Ring",
          },
        })
      end,
    },
  ```

### Vim config

The author has these two commands wired to `<Ctrl-j>` and `<Ctrl-k>`, e.g.,

  ```
    noremap <C-j> :BufferRingReverse<CR>
    inoremap <C-j> <C-O>:BufferRingReverse<CR>
  ```

  and

  ```
    noremap <C-k> :BufferRingForward<CR>
    inoremap <C-k> <C-O>:BufferRingForward<CR>
  ```

You could also use the `<Plug>` mappings, e.g:

  ```vimL
    nmap ]b <Plug>(buf-surf-forward)
    nmap [b <Plug>(buf-surf-back)
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

If you use Neovim and `lazy.nvim`, the example config above is all you need.

If you're still running Vim, you could use Vim's packages feature
(`:h packages`), e.g.,:

  ```shell
  mkdir -p ~/.vim/pack/landonb/start
  cd ~/.vim/pack/landonb/start
  git clone https://github.com/landonb/vim-buffer-ring.git
  vim -u NONE -c "helptags vim-buffer-ring/doc" -c q
  ```

## Related Projects

- *Harpoon*

  <https://github.com/ThePrimeagen/harpoon/tree/harpoon2>

  (From the prolific YouTuber, [`ThePrimeagen`](https://www.youtube.com/@ThePrimeagen)
  aka [`ThePrimeTime`](https://www.youtube.com/@ThePrimeTimeagen).)

  - Details on Reddit:

    <https://www.reddit.com/r/neovim/comments/16d9kg8/harpoon/>

  - A video overview:

    <https://www.youtube.com/watch?v=Qnos8aApa9g>

- ``nvim-project-marks`` — *A minimal plugin for Neovim that stores file marks in a local ShaDa file.*

  <https://github.com/BartSte/nvim-project-marks>

## License

Copyright 2020-2025 Landon Bouma. All rights reserved. \
Copyright 2010-2021 Ton van den Heuvel. All rights reserved.

This work is licensed under the MIT License.
View the [LICENSE](LICENSE) file for details.
