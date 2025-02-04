" vim:tw=0:ts=4:sw=4:et:norl:ft=vim
" Author[1]: Landon Bouma <https://tallybark.com/>
" Online[1]: https://github.com/landonb/vim-buffer-ring#💍
" Digest[1]: Surf bufs in view order, skipping special bufs.
" Author[0]: Ton van den Heuvel <https://github.com/ton/>
" Online[0]: https://github.com/ton/vim-bufsurf
" License: MIT license applies, see LICENSE for licensing details.

" -------------------------------------------------------------------

" GUARD: Press <F9> to reload this plugin (or :source it).
" - Via: https://github.com/embrace-vim/vim-source-reloader#↩️

if expand('%:p') ==# expand('<sfile>:p')
  unlet! g:loaded_plugin_buffer_ring
endif

if exists('g:loaded_plugin_buffer_ring') || &cp || v:version < 800

  finish
endif

let g:loaded_plugin_buffer_ring = 1

" -------------------------------------------------------------------

command BufferRingReverse :call g:embrace#bufsurf#BufferRingReverse(-1)
command BufferRingForward :call g:embrace#bufsurf#BufferRingForward(-1)
command BufferRingClear :call <SID>BufferRingClear()
command BufferRingList :call <SID>BufferRingList()
command BufferRingInsert :call <SID>BufSurfInsertCurrent()

" -------------------------------------------------------------------

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

