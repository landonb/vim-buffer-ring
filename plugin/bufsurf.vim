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
command BufferRingList :call g:embrace#bufsurf#BufferRingList()
command BufSurfListAll :call g:embrace#bufsurf#BufSurfListAll()
command -bang BufferRingClear :call g:embrace#buffer_ring#BufSurfInitHistory(-1, <bang>0)

nnoremap <silent> <Plug>(buf-surf-back) :BufferRingReverse<CR>
nnoremap <silent> <Plug>(buf-surf-forward) :BufferRingForward<CR>

" -------------------------------------------------------------------

call g:embrace#bufsurf#CreateAutocommands()

