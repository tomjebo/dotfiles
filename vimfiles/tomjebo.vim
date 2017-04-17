function! FixLastSpellingError()
	normal! mm[s1z=`m
endfunction

noremap <leader>sp :call FixLastSpellingError()<cr>
noremap <leader>w :w<cr>
