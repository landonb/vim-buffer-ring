" vim:tw=0:ts=4:sw=4:et:norl:ft=vim
" Author: Landon Bouma <https://tallybark.com/>
" Project: https://github.com/landonb/vim-buffer-ring#💍
" Summary: Surf bufs in view order, skipping special bufs.
" License: MIT
" Thanks!: Extends vim-surf by Ton van den Heuvel
"   https://github.com/ton/vim-bufsurf

" -------------------------------------------------------------------

" CALSO: BufSurfDisabled, BufSurfIsDisabled — BufSurf\(Is\)\?Disabled
function! g:embrace#buffer_ring#BufSurfDisabled(bufnr = -1, inhibit_alert = 0) abort
    let l:bufnr = a:bufnr
    if l:bufnr == -1
        let l:bufnr = bufnr("%")
    endif

    if !g:embrace#buffer_ring#IsNormalBuffer(l:bufnr)
        if !a:inhibit_alert
            call g:embrace#bufsurf#BufSurfEcho("vim-buffer-ring: Navigation disabled for this buffer")
        endif

        return 1
    endif

    if !a:inhibit_alert
        if exists('w:history') && len(w:history) == 0
            " (lb): Seems unlikely. But just in case.
            echom 'GAFFE: vim-buffer-ring: Window has no history'

            return 1
        endif
    endif

    return 0
endfunction

function! g:embrace#buffer_ring#IsNormalBuffer(bufnr) abort
  let l:bufnr = bufnr(a:bufnr)

  if l:bufnr == -1

    return 0
  endif

  let l:ftype = getbufvar(l:bufnr, "&filetype")

  if 0
    \ || getbufvar(l:bufnr, '&buftype') != ''
    \ || getbufvar(l:bufnr, "&previewwindow")
    \ || !getbufvar(l:bufnr, "&modifiable")
    \ || !buflisted(l:bufnr)
    \ || l:ftype == 'qf'
    \ || l:ftype == 'git'
    \ || l:ftype == 'fugitiveblame'
    \ || bufname(l:bufnr) == '-MiniBufExplorer-'

    return 0
  endif

  return 1
endfunction

" ***

function! g:embrace#buffer_ring#BufSurfTargetable(bufnr) abort
    " If the user bwipes a buffer, it won't exist, but its reference may.
    if !bufexists(a:bufnr)

      return 0
    endif

    " Ignore unlisted buffers, e.g.:
    " - A :help window.
    " - The project drawer window from project.vim:
    "     https://www.vim.org/scripts/script.php?script_id=69
    "   and maintained by this plug's same author at:
    "     https://github.com/landonb/dubs_project_tray#🗂
    "   - Though note project tray buffer is initially buflisted,
    "     until the first BufEnter callback (see s:DoSetup()).
    " - If we didn't ignore these, a BufSurf operation in a 'regular'
    "   buffer could, e.g., jump to the project window.
    " - Note that quickfix *is* buflisted; see &ft check in BufSurfDisabled.
    if !buflisted(a:bufnr)

        return 0
    endif

    " We could also filter on buftype, which would sense 'quickfix' and
    " 'help', and a few other types, like 'nofile'. E.g.,:
    "     if getbufvar(a:bufnr, '&buftype') != '' | return 0 | endif
    " but I don't work with 'nofile' enough to know if that's desirable
    " or not. So commenting (hi!) instead!

    " In case the specified buffer should be ignored, do not append it to the
    " navigation history of the window.
    if g:embrace#bufsurf#BufSurfIsDisabled(a:bufnr)

        return 0
    endif

    let l:inhibit_alert = 1
    if g:embrace#buffer_ring#BufSurfDisabled(a:bufnr, l:inhibit_alert)

        return 0
    endif

    return 1
endfunction

function! g:embrace#buffer_ring#BufSurfPopMatching(bufnr) abort
    " Removes buffer indicated *iff* it's the currently indexed history element.
    " - I.e., the BufEnter hook adds the netrw buffer, and here we remove it.
    " - Note that FileType (and Syntax) is triggered twice on an `:Explore ...`
    "   command, hence the check that the bufnr passed is the current element.
    if !exists("w:history")
       \ || len(w:history) <= 0
       \ || a:bufnr != g:embrace#buffer_ring#HistoryLookup()

        return
    endif

    call remove(w:history, w:history_index)
    let w:history_index -= 1
    if w:history_index < 0 && len(w:history) > 0
        let w:history_index = 0
    endif
endfunction

" ***

function! g:embrace#buffer_ring#BufSurfEdit() abort
    if w:history_index < 0

        return
    endif

    let l:success = 0

    let l:bufnr = g:embrace#buffer_ring#HistoryLookup()

    if l:bufnr == -1
        let l:hist_len = len(w:history)

        echom "GAFFE: BufSurf index " .. w:history_index .. " > history len " .. l:hist_len
        " DUNNO/2024-12-22: Should we reset the lookup?
        "   call g:embrace#bufsurf#BufferRingClear()
        " Or just reset the index?
        "   let w:history_index = -1
        " Or would that leave user unable to buf-surf anywhere?
        " - We'll play it safe and set to the end of known history.
        let w:history_index = l:hist_len - 1
    elseif g:embrace#buffer_ring#BufSurfTargetable(l:bufnr)
        call g:embrace#bufsurf#BufSurfEditSafe(l:bufnr)

        let l:success = 1
    else
        call g:embrace#buffer_ring#BufSurfPopMatching(l:bufnr)
    endif

    return l:success
endfunction

function! g:embrace#buffer_ring#BufNavigateEchoWrapped() abort
    " Sorta like how Vim's `wrapscan` prints when it wraps around:
    "   "search hit BOTTOM, continuing at TOP",
    " we show a message when we wrap around the buffer queue.
    " - Note that Vim is still in the process of changing buffers, and
    "   the buffer path will be displayed almost immediately after this
    "   callback is processed. So rather than draw the error message now,
    "   because the next message (the buffer path) will just overwrite it
    "   immediately, set a timer to do it.
    " - Note that the message will not appear in Inert mode because Vim
    "   constantly shows `-- INSERT --` in that mode... and I'm not sure
    "   a way around... though probably is one. -- Ya know, I've got INSERT
    "   in Mescaline, I don't need to both places.
    "     ANSWER: set noshowmode
    let timer = timer_start(1, { -> execute('call g:embrace#buffer_ring#BufSurfEchoWrappedAround()', '')})
endfunction

function! g:embrace#buffer_ring#BufSurfEchoWrappedAround() abort
    call g:embrace#bufsurf#BufSurfEcho('Wrapped around history!')
endfunction

" -------------------------------------------------------------------

" DUNNO/2024-12-22: Sometimes when I close all buffers but some don't close
" because unsaved changes, when I try to next/prev to them (<C-k>/<C-j>),
" BufSurfEdit throws 'E684: List index out of range: {n}'. Though not sure
" why. So hardened.
function! g:embrace#buffer_ring#HistoryLookup(history_index = -1) abort
    if !exists('w:history') || !exists('w:history_index')

        return -1
    endif

    let l:history_index = a:history_index
    if l:history_index == -1
        let l:history_index = w:history_index
    endif

    let l:hist_len = len(w:history)

    if l:history_index < l:hist_len
        " Return the bufnr at this index.

        return w:history[l:history_index]
    else
        " Caller will have to deal with it.

        return -1
    endif
endfunction

" ***

function! g:embrace#buffer_ring#BufSurfInitHistory(bufnr = -1, bang = 0) abort
    let l:bufnr = a:bufnr
    if l:bufnr == -1
        let l:bufnr = bufnr('%')
    endif

    " Clear the navigation history
    function! s:BufSurfClear() abort
        let w:history = []
        let w:history_index = -1
    endfunction

    " Reset w:history and w:history_index.
    if a:bufnr == -1 || a:bang || !exists('w:history')
        call s:BufSurfClear()
    endif

    if a:bang
        " When user calls :BufferRingClear! the window buffer history
        " is reduced to just the currently loaded buffer.
        " - This is somewhat of an anti-pattern. Normally every window's
        "   history includes all normal, listed, non-hidden, non-special
        "   buffers. Author is unsure if there's a use case for restricting
        "   the history of a specific window, but now you can.
        call add(w:history, l:bufnr)
        let w:history_index = 0
    else
        " Build a new history from known buffers, and set index accordingly.
        let l:index = 0

        " HSTRY/2025-02-04: This used to iterate from 1 to the last buffer
        " number, weeding out numbers not associated with a buffer. E.g.,
        "
        "   let l:brange = range(1, bufnr('$'))
        "   let l:bufnrs = filter(l:brange, 'buflisted(v:val)')
        "
        " Alternatively, call |getbufinfo|.
        let l:buffers = getbufinfo({'buflisted': 1})

        for l:buf in l:buffers
            let l:curnr = l:buf.bufnr

            if g:embrace#buffer_ring#BufSurfTargetable(l:curnr)
                call add(w:history, l:curnr)

                if l:curnr == l:bufnr
                    let w:history_index = l:index
                endif

                let l:index += 1
            endif
        endfor
    endif
endfunction

" -------------------------------------------------------------------

