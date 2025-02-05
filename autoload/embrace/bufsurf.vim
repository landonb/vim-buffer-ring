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
function! g:embrace#bufsurf#BufferRingReverse(until_index)
    if g:embrace#buffer_ring#BufSurfDisabled()

        return
    endif

    " a:until_index is -1 first time through; if we reach start of buffer
    " without finding editable, this function recursed with a:until_index
    " set to the initial w:history_index.

    let l:old_index = w:history_index
    let l:old_len = len(w:history)

    let w:history_index -= 1

    while w:history_index > a:until_index
        let l:cur_index = w:history_index

        if g:embrace#buffer_ring#BufSurfEdit()
            if a:until_index != -1
                call g:embrace#buffer_ring#BufNavigateEchoWrapped()
            endif

            return
        elseif l:cur_index > 0 && l:cur_index == w:history_index
            " Unreachable path, but just in case...
            echom 'GAFFE: vim-buffer-ring: index unmoved'

            let w:history_index -= 1
        endif

        " Note that BufSurfEdit() will decrement w:history_index
        " if w:history_index no longer indexes a valid buffer,
        " though it won't go negative.
        if l:cur_index == 0

            break
        endif
    endwhile

    if w:history_index < 1
        " Got to first element without finding editable buffer. If this function
        " did not start at final element, keep looking from back of list.
        if a:until_index == -1 && l:old_index != (l:old_len - 1)
            let w:history_index = len(w:history)

            call g:embrace#bufsurf#BufferRingReverse(l:old_index)
        endif
    endif
endfunction

" Open the next buffer in the navigation history for the current window.
" SYNC_ME: #BufferRingReverse and #BufferRingForward are similar, but opposite.
" - Derived from bufsurf.vim: BufSurfForward
function! g:embrace#bufsurf#BufferRingForward(until_index) abort
    if g:embrace#buffer_ring#BufSurfDisabled()

        return
    endif

    " a:until_index is -1 first time through; if we reach end of buffer
    " without finding editable, this function recursed with a:until_index
    " set to the initial w:history_index.
    if a:until_index == -1
        let l:range = range(w:history_index, len(w:history) - 1)
    else
        let l:range = range(0, a:until_index - 1)
    endif

    " Note that BufSurfPopMatching will decrement w:history_index
    " but not past this baseline.
    let l:old_index = w:history_index

    for l:index in l:range
        if w:history_index == len(w:history) - 1

            break
        endif

        let w:history_index += 1

        if g:embrace#buffer_ring#BufSurfEdit()
            if a:until_index != -1
                call g:embrace#buffer_ring#BufNavigateEchoWrapped()
            endif

            return
        endif
    endfor

    if w:history_index == len(w:history) - 1
        " Got to final element without finding editable buffer. If this function
        " did not start at first element, keep looking from front of list.
        if a:until_index == -1 && l:old_index != 0
            let w:history_index = -1

            call g:embrace#bufsurf#BufferRingForward(l:old_index)
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

function! s:CopyHistoryIfSplitFromPreviousWindow(bufnr) abort
    if exists('w:history')
        \ || !exists('s:prev_bufwintab')
        \ || s:prev_bufwintab.bufnr != a:bufnr

        return 0
    endif

    let l:winnr = s:prev_bufwintab.winnr

    if tabpagenr() == s:prev_bufwintab.tabnr
        if l:winnr == winnr()
            " When Vim splits window, the old window generally
            " shifts rightward, and the new window is created
            " before the old window. So our previous winnr is
            " now winnr+1, and the new winnr() is the same as
            " the previous value.
            let l:winnr = s:prev_bufwintab.winnr + 1
        endif
    endif

    let l:o_winid = win_getid(l:winnr, s:prev_bufwintab.tabnr)

    let l:o_bufnr = winbufnr(l:o_winid)

    if l:o_bufnr == a:bufnr
        " Window likely split from existing window.
        " Clone the other window's history.
        let l:history = gettabwinvar(s:prev_bufwintab.tabnr, l:winnr, 'history')

        if type(l:history) == v:t_list
            let w:history = copy(l:history)
            let w:history_index = gettabwinvar(
                \ s:prev_bufwintab.tabnr, l:winnr, 'history_index')

            return 1
        endif
    endif

    return 0
endfunction

function! s:UpdatePrevBufWinTab() abort
    let s:prev_bufwintab = { 'bufnr': bufnr('%'), 'winnr': winnr(), 'tabnr': tabpagenr()}
endfunction

" Insert given buffer number to the navigation history for the current window.
" - Derived from bufsurf.vim: BufSurfAppend
function! g:embrace#bufsurf#BufSurfInsertCurrent(copy_history) abort
    " (lb): Note that either bufnr('%') or winbufnr(winnr()) should work here.
    " - Mentioned because bufsurf.vim uses the latter.
    let l:bufnr = bufnr('%')

    let l:copied = 0
    if a:copy_history
        let l:copied = s:CopyHistoryIfSplitFromPreviousWindow(l:bufnr)
    endif

    call s:UpdatePrevBufWinTab()

    if l:bufnr == g:embrace#buffer_ring#HistoryLookup()
        " Current w:history_index already refs. l:bufnr.

        return
    endif

    " Ignore special buffers, like Vim help, netrw buffer, project.vim tray, etc.
    if !g:embrace#buffer_ring#BufSurfTargetable(l:bufnr)

        return
    endif

    call g:embrace#bufsurf#IndexBuffer(l:bufnr)
endfunction

" In case no navigation history exists for the current window,
" initialize the navigation history.
function! g:embrace#bufsurf#IndexBuffer(bufnr) abort
    if !exists('w:history') || !exists('w:history_index')
        " Initialize the navigation history for new windows.
        call g:embrace#buffer_ring#BufSurfInitHistory(a:bufnr)
        if w:history_index != -1
            " The buffer was located in the history and the index assigned.

            return
        endif
        " else, w:history populated with all other normal buffers,
        " but a:bufnr not located, and w:history_index still -1.
        " Which happens on startup.
        if len(w:history)
            echom 'GAFFE: vim-buffer-ring: Current buffer not added to history?!'
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
        call g:embrace#bufsurf#BufSurfDelete(a:bufnr, l:wipeout)
    endif

    let w:history_index += 1

    let w:history = insert(w:history, a:bufnr, w:history_index)
endfunction

" ***

" Displays buffer navigation history for the current window.
" - Derived from bufsurf.vim: BufSurfList
function! g:embrace#bufsurf#BufferRingList() abort
    if g:embrace#buffer_ring#BufSurfDisabled()

        return
    endif

    let l:curnr = g:embrace#buffer_ring#HistoryLookup()
    " Assert: l:curnr == bufnr("%")
    if l:curnr != bufnr('%')
        echom 'GAFFE: vim-buffer-ring: Expected bufnr(w:history_index) = bufnr("%") — '
            \ .. 'not: ' .. l:curnr .. ' != ' .. bufnr('%')
    endif

    let l:bring_list = g:embrace#bufsurf#PrettyPrintHistory(w:history, w:history_index, l:curnr)

    let l:plain = 1
    call g:embrace#bufsurf#BufSurfEcho(" \n"
        \ .. "Window buffer navigation history (* = current, → = next, ← = prev)\n"
        \ .. "──────────────────────────────────────────────────────────────────\n"
        \ .. join(l:bring_list, "\n")
        \ .. "\n\n", l:plain, ' ', ' ')
endfunction

" Displays buffer navigation history for all windows in all tabs.
function g:embrace#bufsurf#BufSurfListAll() abort
    let name_lines = []

    for tab_info in gettabinfo()
        for win_id in tab_info.windows
            call g:embrace#bufsurf#PrettyPrintAddTabWin(name_lines, tab_info.tabnr, win_id)
        endfor
    endfor

    let l:plain = 1
    call g:embrace#bufsurf#BufSurfEcho(" \n"
        \ .. "Window buffer navigation history (* = current, → = next, ← = prev)\n"
        \ .. "──────────────────────────────────────────────────────────────────\n"
        \ .. join(name_lines, "\n")
        \ .. "\n\n", l:plain, ' ', ' ')
endfunction

function! g:embrace#bufsurf#PrettyPrintAddTabWin(name_lines, tabnr, win_id) abort
    call add(a:name_lines, '')

    if win_getid() == a:win_id
        let cur_str = '* >'
    else
        let cur_str = '  >'
    endif
    let fmt_win = cur_str . 'tab: ' . a:tabnr . ' window: ' . win_id2win(a:win_id)
    call add(a:name_lines, fmt_win)

    let l:history = gettabwinvar(a:tabnr, a:win_id, 'history')
    let l:history_index = gettabwinvar(a:tabnr, a:win_id, 'history_index')

    if type(l:history) != v:t_list

        return
    endif

    let l:curnr = -1
    if l:history_index != -1
        let l:curnr = l:history[l:history_index]
    endif

    let l:bring_list = g:embrace#bufsurf#PrettyPrintHistory(l:history, l:history_index, l:curnr, '  ')

    call extend(a:name_lines, l:bring_list)
endfunction

function! g:embrace#bufsurf#PrettyPrintHistory(history, history_index, curnr, prefix = '') abort
    let l:bring_list = []
    
    for l:bufnr in a:history
        let l:buffer_name = bufname(l:bufnr)

        if l:buffer_name == ""
            let l:buffer_name = "[No Name #" . l:bufnr . "]"
        endif

        if l:bufnr == a:curnr
            let l:buffer_name = "* " . l:buffer_name
        elseif (
                \ (a:history_index > 0)
                \ && l:bufnr == g:embrace#buffer_ring#HistoryLookup(a:history_index - 1))
                \ || ((a:history_index == 0)
                \       && l:bufnr == g:embrace#buffer_ring#HistoryLookup(-1))
            let l:buffer_name = "← " . l:buffer_name
        elseif (
                \ (a:history_index < (len(a:history) - 1))
                \ && l:bufnr == g:embrace#buffer_ring#HistoryLookup(a:history_index + 1))
                \ || ((a:history_index == (len(a:history) - 1))
                \       && l:bufnr == g:embrace#buffer_ring#HistoryLookup(0))
            let l:buffer_name = "→ " . l:buffer_name
        else
            let l:buffer_name = "  " . l:buffer_name
        endif

        let l:buffer_name = a:prefix .. printf('%-3d', l:bufnr) .. ' ' .. l:buffer_name

        let l:bring_list = l:bring_list + [l:buffer_name]
    endfor

    return l:bring_list
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

    let w:history_index = g:embrace#bufsurf#RemoveBufnrFromHistory(
        \ w:history, w:history_index, a:bufnr)

    let w:history_index = min([w:history_index, len(w:history) - 1])

    " Note that vim-buffer-ring won't duplicate any buffer in the history,
    " because the Reverse/Forward commands call BufSurfEdit, which checks
    " BufSurfTargetable — which calls bufexists.
    " - But cleaning up preemptively makes the output from the
    "   BufferRingList and BufSurfListAll commands look better.
    if a:wipeout
        " Go into each window of each tab and remove the buffer from each window's history.
        for l:tab_info in gettabinfo()
            for l:win_idx in l:tab_info.windows
                let l:history = gettabwinvar(l:tab_info.tabnr, l:win_idx, 'history')

                if type(l:history) != v:t_list
                    " E.g., empty string (if 'history' undefined).

                    continue
                endif

                let l:history_index = gettabwinvar(l:tab_info.tabnr, l:win_idx, 'history_index')

                let l:history_index = g:embrace#bufsurf#RemoveBufnrFromHistory(
                    \ l:history, l:history_index, a:bufnr)

                call settabwinvar(l:tab_info.tabnr, l:win_idx, 'history', l:history)
                call settabwinvar(l:tab_info.tabnr, l:win_idx, 'history_index', l:history_index)
            endfor
        endfor
    endif
endfunction

function! g:embrace#bufsurf#RemoveBufnrFromHistory(history, history_index, bufnr) abort
    " If deleted buffer listed before current index, we'll shift 1 left.
    let l:lshift = 0

    if a:history_index > 0
        let l:lshift = count(a:history[0:a:history_index-1], a:bufnr)

        if l:lshift > 1
            " Unreachable branch.
            echom 'GAFFE: vim-buffer-ring: Deleted buffer had been listed more than once'
        endif
    endif

    " Remove the buffer from the current window's history.
    call filter(a:history, 'v:val !=' .. a:bufnr)

    let l:new_index = a:history_index - l:lshift

    let l:new_index = min([l:new_index, len(a:history) - 1])

    return l:new_index
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
function! g:embrace#bufsurf#BufSurfEcho(msg, plain = 0, prefix_1 = 'vim-buffer-ring: ', prefix_n = '') abort
    if !a:plain && g:BufferRingMessages != 1

        return
    endif

    let l:lines = split(a:msg, '\n')

    if !a:plain
        echohl WarningMsg
    endif

    echom a:prefix_1 .. l:lines[0]
    for l:line in l:lines[1:]
        echom a:prefix_n .. l:line
    endfor

    echohl None
endfunction

" -------------------------------------------------------------------

" SAVVY/2025-02-04: On :edit, BufEnter; but on :(v)split, WinEnter.
" - When the latter, look for buffer open in adjacent window, and
"   copy its history.

" Setup the autocommands that handle MRU buffer ordering per window.
function! g:embrace#bufsurf#CreateAutocommands() abort
    augroup BufSurf
        autocmd!
        " (lb): I traced both BufEnter and WinEnter to see if I could tell why
        " both are necessary, but it was not obvious. (Intuition says just BufEnter
        " should be enough; but does not hurt to hook both events, either.)
        autocmd BufEnter * :call g:embrace#bufsurf#BufSurfInsertCurrent(0)
        autocmd WinEnter * :call g:embrace#bufsurf#BufSurfInsertCurrent(1)
        autocmd BufWipeout * :call g:embrace#bufsurf#BufSurfDelete(str2nr(expand('<abuf>')), 1)
        autocmd BufDelete * :call g:embrace#bufsurf#BufSurfDelete(str2nr(expand('<abuf>')), 1)
        " The netrw buffer is not identifiable on BufEnter or WinEnter (netrw.vim
        " has not yet unlisted it, etc.), but eventually its FileType (and Syntax)
        " is set to 'netrw'.
        autocmd FileType netrw :call g:embrace#buffer_ring#BufSurfPopMatching(bufnr('%'))
    augroup End
endfunction

