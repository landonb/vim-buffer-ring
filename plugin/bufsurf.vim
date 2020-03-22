" bufsurf.vim
"
" MIT license applies, see LICENSE for licensing details.
if exists('g:loaded_bufsurf')
    finish
endif

let g:loaded_bufsurf = 1

" ***

" Initialises var to value in case the variable does not yet exist.
function s:InitVariable(var, value)
    if exists(a:var) | return | endif
    exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
endfunction

" YOU: You can `let g:BufSurfIgnore = [<pattern>, ...]` to exclude buffers
" whose name matches any <pattern>.
call s:InitVariable('g:BufSurfIgnore', '')

" YOU: You can `let g:BufSurfMessages = 0` to disable status bar messages.
call s:InitVariable('g:BufSurfMessages', 1)

command BufSurfBack :call <SID>BufSurfBack()
command BufSurfForward :call <SID>BufSurfForward()
command BufSurfClear :call <SID>BufSurfClear()
command BufSurfList :call <SID>BufSurfList()

" List of buffer names that we should not track.
let s:ignore_buffers = split(g:BufSurfIgnore, ',')

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
function s:BufSurfEcho(msg)
    if g:BufSurfMessages == 1
        echohl WarningMsg
        let lines = split(a:msg, '\n')
        echomsg 'BufSurf: ' . lines[0]
        for l in lines[1:]
            echomsg l
        endfor
        echohl None
    endif
endfunction

" ***

" Returns whether recording the buffer navigation history is disabled for the
" given buffer number *bufnr*.
function s:BufSurfIsDisabled(bufnr)
    if s:disabled
        return 1
    endif

    for bufpattern in s:ignore_buffers
        if match(bufname(a:bufnr), bufpattern) != -1
            return 1
        endif
    endfor

    return 0
endfunction

function s:BufSurfable(bufnr)
    " Ignore unlisted buffers, such as the project drawer window from
    " project.vim, https://www.vim.org/scripts/script.php?script_id=69.
    " - If not, a BufSurf in one window can jump to the project window.
    if !buflisted(a:bufnr)
        return 0
    endif

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

" Open the previous buffer from the window's navigation history.
function s:BufSurfBack()
    if w:history_index > 0
        let w:history_index -= 1
        let s:disabled = 1
        execute "b " . w:history[w:history_index]
        let s:disabled = 0
    else
        call s:BufSurfEcho("reached start of window navigation history")
    endif
endfunction

" Open the next buffer in the navigation history for the current window.
function s:BufSurfForward()
    if w:history_index < len(w:history) - 1
        let w:history_index += 1
        let s:disabled = 1
        execute "b " . w:history[w:history_index]
        let s:disabled = 0
    else
        call s:BufSurfEcho("reached end of window navigation history")
    endif
endfunction

" ***

" Clear the navigation history
function s:BufSurfClear()
    let w:history_index = -1
    let w:history = []
endfunction

function BufSurfEnsureIndexed(bufnr)
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

" Add the given buffer number to the navigation history for the window
" identified by winnr.
function s:BufSurfAppend(bufnr)
    if !BufSurfable(a:bufnr) | return | endif

    " In case no navigation history exists for the current window, initialize
    " the navigation history.
    if !exists('w:history_index')
        " Make sure that the current buffer will be inserted at the start of
        " the window navigation list.
        let w:history_index = 0
        let w:history = []

        " Add all buffers loaded for the current window to the navigation
        " history.
        let s:i = a:bufnr + 1
        while bufexists(s:i)
            " Ignore unlisted buffers, e.g., the project.vim tray buffer.
            " Also ignore buffers indicated by BufSurfIsDisabled().
            if BufSurfable(s:i)
                call add(w:history, s:i)
            endif
            let s:i += 1
        endwhile

    " In case the newly added buffer is the same as the previously active
    " buffer, ignore it.
    elseif w:history_index != -1 && w:history[w:history_index] == a:bufnr
        return

    " Add the current buffer to the buffer navigation history list of the
    " current window.
    else
        let w:history_index += 1
    endif

    " In case the buffer that is being appended is already the next buffer in
    " the history, ignore it. This happens in case a buffer is loaded that is
    " also the next buffer in the forward browsing history. Thus, this
    " prevents duplicate entries of the same buffer occurring next to each
    " other in the browsing history.
    let l:is_buffer_listed = (w:history_index != len(w:history) && w:history[w:history_index] == a:bufnr)

    if !l:is_buffer_listed
        let w:history = insert(w:history, a:bufnr, w:history_index)
    endif
endfunction

" ***

" Displays buffer navigation history for the current window.
function s:BufSurfList()
    let l:buffer_names = []
    for l:bufnr in w:history
        let l:buffer_name = bufname(l:bufnr)
        if bufnr("%") == l:bufnr
            let l:buffer_name = "* " . l:buffer_name
        else
            let l:buffer_name = "  " . l:buffer_name
        endif
        let l:buffer_names = l:buffer_names + [l:buffer_name]
    endfor
    call s:BufSurfEcho("window buffer navigation history (* = current):" . join(l:buffer_names, "\n"))
endfunction

" ***

" Remove indicated buffer from the current window's navigation history.
function s:BufSurfDelete(bufnr, ensure)
    if len(w:history) == 0 | return | endif

    let l:lshift = count(w:history[0:w:history_index], a:bufnr)

    " We do not have to worry about l:bufnr == l:curnr because, if so,
    " Vim will close the window, and it and its w:history_index disappear.

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
    autocmd BufEnter * :call s:BufSurfAppend(winbufnr(winnr()))
    autocmd WinEnter * :call s:BufSurfAppend(winbufnr(winnr()))
    autocmd BufWipeout * :call s:BufSurfDelete(eval(expand('<abuf>')), 1)
    " The netrw buffer is not identifiable on BufEnter or WinEnter (netrw.vim
    " has not yet unlisted it, etc.), but eventually its FileType (and Syntax)
    " is set to 'netrw'.
    autocmd FileType netrw :call s:BufSurfPopMatching(winbufnr(winnr()))
augroup End

