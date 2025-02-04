" vim:tw=0:ts=4:sw=4:et:norl:ft=vim
" Author: Landon Bouma <https://tallybark.com/>
" Project: https://github.com/landonb/vim-buffer-ring#💍
" Summary: Surf bufs in view order, skipping special bufs.
" License: MIT
" Thanks!: Extends vim-surf by Ton van den Heuvel
"   https://github.com/ton/vim-bufsurf

" -------------------------------------------------------------------

function! g:embrace#buffer_ring#BufSurfDisabled() abort
    let l:bufnr = bufnr("%")

    if !buflisted(l:bufnr) || &ft == 'qf' || &previewwindow
        call g:embrace#bufsurf#BufSurfEcho("vim-buffer-ring: Navigation disabled for this buffer")

        return 1
    endif

    if len(w:history) == 0
        " (lb): Seems unlikely. But just in case.
        call g:embrace#bufsurf#BufSurfEcho("GAFFE: vim-buffer-ring: Window has no history")

        return 1
    endif

    return 0
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

    return 1
endfunction

function! g:embrace#buffer_ring#BufSurfPopMatching(bufnr) abort
    " Removes buffer indicated *iff* it's the currently indexed history element.
    " - I.e., the BufEnter hook adds the netrw buffer, and here we remove it.
    " - Note that FileType (and Syntax) is triggered twice on an `:Explore ...`
    "   command, hence the check that the bufnr passed is the current element.
    if !exists("w:history")
       \ || len(w:history) <= 0
       \ || a:bufnr != g:embrace#buffer_ring#HistoryLookup(w:history_index)
        return
    endif

    call remove(w:history, w:history_index)
    let w:history_index -= 1
endfunction

" ***

function! g:embrace#buffer_ring#BufSurfEdit() abort
    if w:history_index < 0

        return
    endif

    let l:success = 0

    let l:bufnr = g:embrace#buffer_ring#HistoryLookup(w:history_index)

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
function! g:embrace#buffer_ring#HistoryLookup(history_index) abort
    let l:hist_len = len(w:history)

    if a:history_index < l:hist_len
        " Return the bufnr at this index.

        return w:history[a:history_index]
    else
        " Caller will have to deal with it.

        return -1
    endif
endfunction

" ***

function! g:embrace#buffer_ring#BufSurfInitHistory(bufnr) abort
    " Reset w:history and w:history_index.
    call g:embrace#bufsurf#BufferRingClear()
    " Build a new history from known buffers, and set index accordingly.
    let l:index = 0

    " WATCH/2021-02-04: Every so often, Vim won't quit (at least the
    " Vim I've got configured, with ~100 plugins). It looks like filter()
    " and one other item are causing error messages, but I'm not sure
    " which filter(). And the issue has been difficult to suss. So using
    " trace messages while I figure this out. Here's the original call:
    "
    "   let l:bufnrs = filter(range(1, bufnr('$')), 'buflisted(v:val)')
    "
    " And here's the same call, but with a warning message:
    let l:brange = range(1, bufnr('$'))
    if len(l:brange) == 0
        " LATER/2021-02-06: This path is temporary, to help author diagnose issue.
        echom "WARNING: No l:brange!!!"
    endif
    let l:bufnrs = filter(l:brange, 'buflisted(v:val)')

    for l:curnr in l:bufnrs
        if g:embrace#buffer_ring#BufSurfTargetable(l:curnr)
            " echom "BufSurfInitHistory: curnr: " . l:curnr . " / type: " . type(l:curnr)
            call add(w:history, l:curnr)
            if l:curnr == a:bufnr
                let w:history_index = l:index
            endif
            let l:index += 1
        endif
    endfor
endfunction

function! g:embrace#buffer_ring#BufSurfEnsureIndexed() abort
    if w:history_index >= 0 && w:history_index < len(w:history)

        return
    endif

    let w:history_index = -1

    if len(w:history) > 0
        " GUARD/2025-02-04: This is an unreachable branch, right
        let w:history_index = 0

        echom 'GAFFE: vim-buffer-ring: w:history_index unassigned'
    endif
endfunction

" -------------------------------------------------------------------

