" vim:tw=0:ts=4:sw=4:et:norl:ft=vim
" Author[1]: Landon Bouma <https://tallybark.com/>
" Online[1]: https://github.com/landonb/vim-buffer-ring#💍
" Digest[1]: Surf bufs in view order, skipping special bufs.
" Author[0]: Ton van den Heuvel <https://github.com/ton/>
" Online[0]: https://github.com/ton/vim-bufsurf
" License: MIT license applies, see LICENSE for licensing details.

" -------------------------------------------------------------------

" Initialises var to value in case the variable does not yet exist.
function! s:InitVariable(var, value) abort
    if exists(a:var)

        return
    endif

    exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
endfunction

" USAGE: You can `let g:BufferRingIgnore = [<pattern>, ...]` to exclude buffers
" whose name matches any <pattern>. The plugin always excludes unlisted buffers.
call s:InitVariable('g:BufferRingIgnore', '')

" YOU: You can `let g:BufferRingMessages = 0` to disable status bar messages.
call s:InitVariable('g:BufferRingMessages', 1)

" -------------------------------------------------------------------

" List of buffer names that we should not track.
let s:ignore_buffers = split(g:BufferRingIgnore, ',')

" Used to temporarily disable plugin functionality when changing buffers
" (so the BufEnter ignores the edit event, and doesn't reprocess the buffer).
let s:disabled = 0

" -------------------------------------------------------------------

" Open the previous buffer from the window's navigation history.
" SYNC_ME: #BufferRingReverse and #BufferRingForward are similar, but opposite.
" - Derived from bufsurf.vim: s:BufSurfBack
function! g:embrace#bufsurf#BufferRingReverse(limit)
    if g:embrace#buffer_ring#BufSurfDisabled() | return | endif

    " l:limit is -1 first time through; if we reach start of buffer
    " without finding editable, this function recursed with l:limit
    " set to w:history_index.

    let l:cur_index = w:history_index
    while w:history_index > (a:limit + 1)
        let w:history_index -= 1
        if g:embrace#buffer_ring#BufSurfEdit()
            if a:limit != -1
                call g:embrace#buffer_ring#BufNavigateEchoWrapped()
            endif
            return
        endif
    endwhile

    if w:history_index == 0
        " Got to first element without finding editable buffer. If this function
        " did not start at final element, keep looking from back of list.
        if a:limit == -1 && l:cur_index != (len(w:history) - 1)
            let w:history_index = len(w:history)
            call g:embrace#bufsurf#BufferRingReverse(l:cur_index)
        endif
    endif
endfunction

" Open the next buffer in the navigation history for the current window.
" SYNC_ME: #BufferRingReverse and #BufferRingForward are similar, but opposite.
" - Derived from bufsurf.vim: BufSurfForward
function! g:embrace#bufsurf#BufferRingForward(limit) abort
    if g:embrace#buffer_ring#BufSurfDisabled() | return | endif

    " l:limit is -1 first time through; if we reach end of buffer
    " without finding editable, this function recursed with l:limit
    " set to w:history_index.
    let l:limit = a:limit
    if l:limit == -1
        let l:limit = len(w:history)
    endif

    let l:cur_index = w:history_index
    while w:history_index < (l:limit - 1)
        let w:history_index += 1
        if g:embrace#buffer_ring#BufSurfEdit()
            if l:limit != len(w:history)
                call g:embrace#buffer_ring#BufNavigateEchoWrapped()
            endif
            return
        endif
    endwhile

    if w:history_index == len(w:history) - 1
        " Got to final element without finding editable buffer. If this function
        " did not start at first element, keep looking from front of list.
        if a:limit == -1 && l:cur_index != 0
            let w:history_index = -1
            call g:embrace#bufsurf#BufferRingForward(l:cur_index)
        endif
    endif
endfunction

function! g:embrace#bufsurf#BufSurfEditSafe(bufnr) abort
    " Set s:disabled, so that when BufEnter calls BufSurfInsertCurrent,
    " the BufSurfTargetable guard stops it.
    let s:disabled = 1
    execute 'b ' .. a:bufnr
    let s:disabled = 0
endfunction

" ***

" Insert given buffer number to the navigation history for the current window.
" - Derived from bufsurf.vim: BufSurfAppend
function! g:embrace#bufsurf#BufSurfInsertCurrent() abort
    " (lb): Note that either bufnr("%") or winbufnr(winnr()) should work here.
    " - Mentioned because bufsurf.vim uses the latter.
    let l:bufnr = bufnr('%')

    " Ignore special buffers, like Vim help, netrw buffer, project.vim tray, etc.
    if !g:embrace#buffer_ring#BufSurfTargetable(l:bufnr)

        return
    endif

    " In case no navigation history exists for the current window, initialize
    " the navigation history.
    if !exists('w:history_index')
        " Initialize the navigation history for new windows.
        call g:embrace#buffer_ring#BufSurfInitHistory(l:bufnr)
        if w:history_index != -1
            " The buffer was located in the history and the index assigned.

            return
        endif
    else
        " Remove all entries for this buffer and insert again at current index.
        " (lb): Orig. vim-bufsurf behavior would add the same buffer multiple
        " times, just not adjacent in the history. But I always found this a
        " little annoying, especially if I used my <F2> mapping, which jumps
        " back and forth between the two MRU buffers -- this would add the 2
        " buffers to the history back to back, so that to get to any file that
        " I had been editing prior, I'd have to #BufferRingReverse back through
        " all the <F2>-created redundant buffers... so just keep 1 copy of each!
        " - tl;dr.
        let l:wipeout = 0
        call g:embrace#bufsurf#BufSurfDelete(l:bufnr, l:wipeout)
        let w:history_index += 1
    endif

    let w:history = insert(w:history, l:bufnr, w:history_index)

    " Ensure that w:history_index is not still -1 from BufSurfInitHistory.
    call g:embrace#buffer_ring#BufSurfEnsureIndexed()
endfunction

" ***

" Displays buffer navigation history for the current window.
" - Derived from bufsurf.vim: BufSurfList
function! g:embrace#bufsurf#BufferRingList() abort
    let l:buffer_names = []

    let l:curnr = g:embrace#buffer_ring#HistoryLookup(w:history_index)
    " Assert: l:curnr == bufnr("%")
    if l:curnr != bufnr('%')
        echom 'GAFFE: vim-buffer-ring: Expected bufnr(w:history_index) = bufnr("%") — '
            \ .. 'not: ' .. l:curnr .. ' != ' .. bufnr('%')
    endif

    " Print list in reverse so most recently visited buffers are listed first/top.
    for l:bufnr in reverse(copy(w:history))
        let l:buffer_name = bufname(l:bufnr)
        if l:buffer_name == ""
            let l:buffer_name = "[No Name #" . l:bufnr . "]"
        endif
        if l:bufnr == l:curnr
            let l:buffer_name = "* " . l:buffer_name
        elseif (
                \ (w:history_index > 0)
                \ && l:bufnr == g:embrace#buffer_ring#HistoryLookup(w:history_index - 1))
                \ || ((w:history_index == 0)
                \       && l:bufnr == g:embrace#buffer_ring#HistoryLookup(-1))
            let l:buffer_name = "↓ " . l:buffer_name
        elseif (
                \ (w:history_index < (len(w:history) - 1))
                \ && l:bufnr == g:embrace#buffer_ring#HistoryLookup(w:history_index + 1))
                \ || ((w:history_index == (len(w:history) - 1))
                \       && l:bufnr == g:embrace#buffer_ring#HistoryLookup(0))
            let l:buffer_name = "↑ " . l:buffer_name
        else
            let l:buffer_name = "  " . l:buffer_name
        endif
        let l:buffer_names = l:buffer_names + [l:buffer_name]
    endfor
    call g:embrace#bufsurf#BufSurfEcho("Window buffer navigation history (* = current, ↑ = next, ↓ = prev):\n"
        \ . join(l:buffer_names, "\n"))
endfunction

" Displays buffer navigation history for all windows in all tabs.
function g:embrace#bufsurf#BufSurfListAll() abort
    let name_lines = []

    for tab_info in gettabinfo()
        for win_id in tab_info.windows
            call add(name_lines, '')
            if win_getid() == win_id
                let cur_str = '* >'
            else
                let cur_str = '  >'
            endif
            let fmt_win = cur_str . 'tab: ' . tab_info.tabnr . ' window: ' . win_id2win(win_id)
            call add(name_lines, fmt_win)

            let history = gettabwinvar(tab_info.tabnr, win_id, 'history')
            let history_index = gettabwinvar(tab_info.tabnr, win_id, 'history_index')

            if type(history) != v:t_list
                continue
            endif

            for hist_idx in range(len(history))
                let name = bufname(history[hist_idx])
                if history_index == hist_idx
                    let cur_str = '  * >'
                else
                    let cur_str = '    >'
                endif
                let fmt_name = cur_str . name
                call add(name_lines, fmt_name)
            endfor
        endfor
    endfor

    call g:embrace#bufsurf#BufSurfEcho('window buffer nav hist (* = current):' . join(name_lines, "\n"))
endfunction

" ***

" Returns whether recording the buffer navigation history is disabled for the
" given buffer number *bufnr*.
function! g:embrace#bufsurf#BufSurfIsDisabled(bufnr) abort
    if s:disabled
        return 1
    endif

    for l:bufpattern in s:ignore_buffers
        if match(bufname(a:bufnr), l:bufpattern) != -1
            return 1
        endif
    endfor

    return 0
endfunction

" Remove indicated buffer from the current window's navigation history.
" - Derived from bufsurf.vim: BufSurfDelete
function! g:embrace#bufsurf#BufSurfDelete(bufnr, wipeout) abort
    if !exists('w:history') || len(w:history) == 0

        return
    endif

    let l:lshift = count(w:history[0:w:history_index], a:bufnr)

    " We do not have to worry about l:bufnr == l:curnr because, if so,
    " Vim will close the window, and it and its w:history_index disappear.

    " WATCH/2021-02-04 20:34: Every so often, Vim won't quit, and it prints
    " an error about filter() and one other thing. But not sure which filter.
    " - But I'd guess this one, which happens on delete, because the issue
    "   happens when I'm using <Alt-f e> to close all files/buffers, before
    "   I'd use <Aft-f x> to exit Vim.
    " - See longer comment above (also at 2021-02-04 20:34).
    if len(w:history) == 0
        " LATER/2021-02-06: This path is temporary, to help author diagnose issue.
        " TRACK/2024-11-21: I haven't seen this warning *in ages*, or perhaps
        " just not in MacVim (I haven't been running Vim on Linux much since
        " eary 2024).
        echom "buffer_ring.vim: GAFFE: No w:history!"
    " else
    "     echom 'w:history (' . len(w:history) . '): ' . join(w:history, ' :: ')
    endif

    " Remove the buffer from the current window's history.
    call filter(w:history, 'v:val !=' . a:bufnr)

    let w:history_index -= l:lshift

    call g:embrace#buffer_ring#BufSurfEnsureIndexed()

    if a:wipeout
        " Go into each window of each tab and remove the buffer from each window's history.
        for tab_info in gettabinfo()
            for win_idx in tab_info.windows
                let history = gettabwinvar(tab_info.tabnr, win_idx, 'history')
                if type(history) != v:t_list
                    continue
                endif
                let history_index = gettabwinvar(tab_info.tabnr, win_idx, 'history_index')

                call filter(history, 'v:val != ' . a:bufnr)
                " Remove duplicate buffers that have been made adjacent from the deletion.
                " - [lb]: This is from bufsurf.vim but vim-buffer-ring doesn't allow duplicates.
                "
                "  call uniq(history)
                call settabwinvar(tab_info.tabnr, win_idx, 'history', history)

                " In case the current window history index is no longer valid, move it within boundaries.
                if history_index >= len(history)
                    let history_index = len(history) - 1
                    call settabwinvar(tab_info.tabnr, win_idx, 'history_index', history_index)
                endif
            endfor
        endfor
    endif
endfunction

" ***

" Echo a BufSurf message in the Vim status line.
" - Note: In Insert mode, you can `set noshowmode` to hide the
"   '-- INSERT --' message, which will otherwise obscure any
"   other message printed while the user is in insert mode.
"   - If you use a powerline-esque plugin, such as the spirited
"       https://github.com/landonb/dubs_mescaline
"     you might already have the mode indicated elsewhere.
" - Derived from bufsurf.vim: BufSurfEcho
function! g:embrace#bufsurf#BufSurfEcho(msg) abort
    if g:BufferRingMessages != 1

        return
    endif

    echohl WarningMsg
    let lines = split(a:msg, '\n')
    echom 'vim-buffer-ring: ' . lines[0]
    for l:line in lines[1:]
        echom l:line
    endfor
    echohl None
endfunction

" -------------------------------------------------------------------

" Setup the autocommands that handle MRU buffer ordering per window.
function! g:embrace#bufsurf#CreateAutocommands() abort
    augroup BufSurf
        autocmd!
        " (lb): I traced both BufEnter and WinEnter to see if I could tell why
        " both are necessary, but it was not obvious. (Intuition says just BufEnter
        " should be enough; but does not hurt to hook both events, either.)
        autocmd BufEnter * :call g:embrace#bufsurf#BufSurfInsertCurrent()
        autocmd WinEnter * :call g:embrace#bufsurf#BufSurfInsertCurrent()
        autocmd BufWipeout * :call g:embrace#bufsurf#BufSurfDelete(str2nr(expand('<abuf>')), 1)
        " The netrw buffer is not identifiable on BufEnter or WinEnter (netrw.vim
        " has not yet unlisted it, etc.), but eventually its FileType (and Syntax)
        " is set to 'netrw'.
        autocmd FileType netrw :call g:embrace#buffer_ring#BufSurfPopMatching(bufnr('%'))
    augroup End
endfunction

