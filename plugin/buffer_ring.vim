" Traverse buffers backwards and forwards in the order they were most recently viewed.
" Author[1]: Landon Bouma <https://tallybark.com/>
" Online[1]: https://github.com/landonb/vim-buffer-ring
" Author[0]: Ton van den Heuvel <https://github.com/ton/>
" Online[0]: https://github.com/ton/vim-bufsurf
" License: MIT. View the 'LICENSE' file for details.
" vim:tw=0:ts=4:sw=4:et:norl:ft=vim

" +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "

" YOU: Uncomment next 'unlet', then <F9> to reload this file.
"      (Iff: https://github.com/landonb/vim-source-reloader)
"
" silent! unlet g:loaded_plugin_buffer_ring

if exists('g:loaded_plugin_buffer_ring') || &cp || v:version < 800
    finish
endif

let g:loaded_plugin_buffer_ring = 1

" +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "

" Initialises var to value in case the variable does not yet exist.
function! s:InitVariable(var, value)
    if exists(a:var) | return | endif
    exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
endfunction

" YOU: You can `let g:BufferRingIgnore = [<pattern>, ...]` to exclude buffers
" whose name matches any <pattern>. The plugin always excludes unlisted buffers.
call s:InitVariable('g:BufferRingIgnore', '')

" YOU: You can `let g:BufferRingMessages = 0` to disable status bar messages.
call s:InitVariable('g:BufferRingMessages', 1)

command BufferRingReverse :call <SID>BufferRingReverse(-1)
command BufferRingForward :call <SID>BufferRingForward(-1)
command BufferRingClear :call <SID>BufferRingClear()
command BufferRingList :call <SID>BufferRingList()
command BufferRingInsert :call <SID>BufSurfInsertCurrent()

" List of buffer names that we should not track.
let s:ignore_buffers = split(g:BufferRingIgnore, ',')

" Indicates whether the plugin is enabled or not.
let s:disabled = 0

" ***

" Echo a BufSurf message in the Vim status line.
" - Note: In Insert mode, you can `set noshowmode` to hide the
"   "-- INSERT --" message, which will otherwise obscure any
"   other message printed while the user is in insert mode.
"   - If you use a powerline-esque plugin, such as the spirited
"       https://github.com/landonb/dubs_mescaline
"     you might already have the mode indicated elsewhere.
function! s:BufSurfEcho(msg)
    if g:BufferRingMessages == 1
        echohl WarningMsg
        let lines = split(a:msg, '\n')
        echomsg 'BufSurf: ' . lines[0]
        for l:line in lines[1:]
            echomsg l:line
        endfor
        echohl None
    endif
endfunction

function! s:BufSurfDisabled()
    let l:bufnr = bufnr("%")

    if !buflisted(l:bufnr) || &ft == 'qf' || &previewwindow
        call s:BufSurfEcho("Navigation disabled for this buffer")
        return 1
    endif

    if len(w:history) == 0
        " (lb): Seems unlikely. But just in case.
        call s:BufSurfEcho("Window has no history!")
        return 1
    endif

    return 0
endfunction

" ***

" Returns whether recording the buffer navigation history is disabled for the
" given buffer number *bufnr*.
function! s:BufSurfIsDisabled(bufnr)
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

function! s:BufSurfTargetable(bufnr)
    " If the user bwipes a buffer, it won't exist, but its reference may.
    if !bufexists(a:bufnr)
      return 0
    endif

    " Ignore unlisted buffers, such as the project drawer window from
    " project.vim, https://www.vim.org/scripts/script.php?script_id=69.
    " - If not, a BufSurf in another window can jump to the project window.
    " - The 'help' window is also !buflisted; but both quickfix and
    "   project tray are buflisted.
    if !buflisted(a:bufnr)
        return 0
    endif

    " We could also filter on buftype, which would sense 'quickfix' and
    " 'help', and a few other types, like 'nofile'. E.g.,:
    "     if getbufvar(a:bufnr, "&buftype") != "" | return 0 | endif
    " but I don't work with 'nofile' enough to know if that's desirable
    " or not. So commenting (hi!) instead!

    " In case the specified buffer should be ignored, do not append it to the
    " navigation history of the window.
    if s:BufSurfIsDisabled(a:bufnr)
        return 0
    endif

    return 1
endfunction

function! s:BufSurfPopMatching(bufnr)
    " Removes buffer indicated *iff* it's the currently indexed history element.
    " - I.e., the BufEnter hook adds the netrw buffer, and here we remove it.
    " - Note that FileType (and Syntax) is triggered twice on an `:Explore ...`
    "   command, hence the check that the bufnr passed is the current element.
    if !exists("w:history")
       \ || len(w:history) <= 0
       \ || a:bufnr != w:history[w:history_index]
        return
    endif

    call remove(w:history, w:history_index)
    let w:history_index -= 1
endfunction

" ***

function! BufSurfEdit()
    if w:history_index < 0 | return | endif
    let l:success = 0
    let l:bufnr = w:history[w:history_index]
    if s:BufSurfTargetable(l:bufnr)
        let s:disabled = 1
        execute "b " . l:bufnr
        let s:disabled = 0
        let l:success = 1
    else
        call s:BufSurfPopMatching(l:bufnr)
    endif
    return l:success
endfunction

function! s:BufNavigateEchoWrapped()
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
    let timer = timer_start(1, 'BufSurfEchoWrappedAround')
endfunction

function! BufSurfEchoWrappedAround(timer)
    call s:BufSurfEcho('Wrapped around history!')
endfunction

" Open the previous buffer from the window's navigation history.
" SYNC_ME: s:BufferRingReverse and s:BufferRingForward are similar, but opposite.
function! s:BufferRingReverse(limit)
    if s:BufSurfDisabled() | return | endif

    " l:limit is -1 first time through; if we reach start of buffer
    " without finding editable, this function recursed with l:limit
    " set to w:history_index.

    let l:cur_index = w:history_index
    while w:history_index > (a:limit + 1)
        let w:history_index -= 1
        if BufSurfEdit()
            if a:limit != -1
                call s:BufNavigateEchoWrapped()
            endif
            return
        endif
    endwhile

    if w:history_index == 0
        " Got to first element without finding editable buffer. If this function
        " did not start at final element, keep looking from back of list.
        if a:limit == -1 && l:cur_index != (len(w:history) - 1)
            let w:history_index = len(w:history)
            call s:BufferRingReverse(l:cur_index)
        endif
    endif
endfunction

" Open the next buffer in the navigation history for the current window.
" SYNC_ME: s:BufferRingReverse and s:BufferRingForward are similar, but opposite.
function! s:BufferRingForward(limit)
    if s:BufSurfDisabled() | return | endif

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
        if BufSurfEdit()
            if l:limit != len(w:history)
                call s:BufNavigateEchoWrapped()
            endif
            return
        endif
    endwhile

    if w:history_index == len(w:history) - 1
        " Got to final element without finding editable buffer. If this function
        " did not start at first element, keep looking from front of list.
        if a:limit == -1 && l:cur_index != 0
            let w:history_index = -1
            call s:BufferRingForward(l:cur_index)
        endif
    endif
endfunction

" ***

" Clear the navigation history
function! s:BufferRingClear()
    let w:history_index = -1
    let w:history = []
endfunction

function! s:BufSurfInitHistory(bufnr)
    " Reset w:history and w:history_index.
    call s:BufferRingClear()
    " Build a new history from known buffers, and set index accordingly.
    let l:index = 0

    " WATCH/2021-02-04 20:34: Every so often, Vim won't quit (at least the
    " Vim I've got configured, with 10s of plugins, if not 100). It looks
    " like filter() and one other item are causing error messages, but I'm
    " not sure which filter(). And the issue has been difficult to suss. So
    " using trace messages while I figure this out. Here's the original call:
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
        if s:BufSurfTargetable(l:curnr)
            " echom "BufSurfInitHistory: curnr: " . l:curnr . " / type: " . type(l:curnr)
            call add(w:history, l:curnr)
            if l:curnr == a:bufnr
                let w:history_index = l:index
            endif
            let l:index += 1
        endif
    endfor
endfunction

" QUESTION/2021-02-21: Scope caught my eye: Not meant to be an s:Function?
function! BufSurfEnsureIndexed(bufnr)
    if w:history_index >= 0 && w:history_index < len(w:history)
        return
    endif
    let w:history_index = -1
    if len(w:history) > 0
        let w:history_index = 0
        if a:bufnr != -1
            echom "ERROR: Did not determine w:history_index for buffer: " . a:bufnr
        endif
    endif
endfunction

" Insert given buffer number to the navigation history for the current window.
function! s:BufSurfInsertCurrent()
    " (lb): Note that either bufnr("%") or winbufnr(winnr()) should work here.
    let l:bufnr = bufnr("%")

    " Ignore special buffers, like Vim help, netrw buffer, project.vim tray, etc.
    if !s:BufSurfTargetable(l:bufnr) | return | endif

    if !exists('w:history_index')
        " Initialize the navigation history for new windows.
        call s:BufSurfInitHistory(l:bufnr)
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
        " I had been editing prior, I'd have to BufferRingReverse back through
        " all the <F2>-created redundant buffers... so just keep 1 copy of each!
        " - tl;dr.
        call s:BufSurfDelete(l:bufnr, 0)
        let w:history_index += 1
    endif

    let w:history = insert(w:history, l:bufnr, w:history_index)

    " Ensure that w:history_index is not still -1 from BufSurfInitHistory.
    call BufSurfEnsureIndexed(l:bufnr)

endfunction

" ***

" Displays buffer navigation history for the current window.
function! s:BufferRingList()
    let l:buffer_names = []
    " Same as:
    "   let l:curnr = bufnr("%")
    let l:curnr = w:history[w:history_index]
    for l:bufnr in reverse(copy(w:history))
        let l:buffer_name = bufname(l:bufnr)
        if l:buffer_name == ""
            let l:buffer_name = "[No Name #" . l:bufnr . "]"
        endif
        if l:bufnr == l:curnr
            let l:buffer_name = "* " . l:buffer_name
        elseif ((w:history_index > 0) && l:bufnr == w:history[w:history_index - 1])
                \ || ((w:history_index == 0) && l:bufnr == w:history[-1])
            let l:buffer_name = "↓ " . l:buffer_name
        elseif ((w:history_index < (len(w:history) - 1)) && l:bufnr == w:history[w:history_index + 1])
                \ || ((w:history_index == (len(w:history) - 1)) && l:bufnr == w:history[0])
            let l:buffer_name = "↑ " . l:buffer_name
        else
            let l:buffer_name = "  " . l:buffer_name
        endif
        let l:buffer_names = l:buffer_names + [l:buffer_name]
    endfor
    call s:BufSurfEcho("Window buffer navigation history (* = current, ↑ = next, ↓ = prev):\n"
        \ . join(l:buffer_names, "\n"))
endfunction

" ***

" Remove indicated buffer from the current window's navigation history.
function! s:BufSurfDelete(bufnr, ensure)
    if !exists('w:history') || len(w:history) == 0 | return | endif

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
        echom "WARNING: No w:history!!!"
    " else
    "     echom 'w:history (' . len(w:history) . '): ' . join(w:history, ' :: ')
    endif

    " Remove the buffer from the current window's history.
    call filter(w:history, 'v:val !=' . a:bufnr)

    let w:history_index -= l:lshift
    if a:ensure
        call BufSurfEnsureIndexed(a:bufnr)
    endif
endfunction

" ***

" Setup the autocommands that handle MRU buffer ordering per window.
augroup BufSurf
    autocmd!
    " (lb): I traced both BufEnter and WinEnter to see if I could tell why
    " both are necessary, but it was not obvious. (Intuition says just BufEnter
    " should be enough; but does not hurt to hook both events, either.)
    autocmd BufEnter * :call s:BufSurfInsertCurrent()
    autocmd WinEnter * :call s:BufSurfInsertCurrent()
    autocmd BufWipeout * :call s:BufSurfDelete(eval(expand('<abuf>')), 1)
    " The netrw buffer is not identifiable on BufEnter or WinEnter (netrw.vim
    " has not yet unlisted it, etc.), but eventually its FileType (and Syntax)
    " is set to 'netrw'.
    autocmd FileType netrw :call s:BufSurfPopMatching(winbufnr(winnr()))
augroup End

