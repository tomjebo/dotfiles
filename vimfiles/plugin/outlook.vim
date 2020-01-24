" outlook.vim - Edit emails using Vim from Outlook
" ---------------------------------------------------------------
" Version:       14.0
" Authors:       David Fishburn <dfishburn dot vim at gmail dot com>
" Last Modified: 2016 Feb 17
" Created:       2009 Jan 17
" License:       VIM License
" Homepage:      http://www.vim.org/scripts/script.php?script_id=3087
" Help:          :h outlook.txt


" Only use this on the Windows platforms
if !has("win32") && !has("win95")  && !has("win64")
    finish
endif

if exists('g:loaded_outlook')
    finish
endif

" Turn on support for line continuations when creating the script
let s:cpo_save = &cpo
set cpo&vim

if !exists('g:outlook_debug')
    let g:outlook_debug = 0
endif

" Capture the output
if !exists('g:outlook_save_cscript_output')
    let g:outlook_save_cscript_output = 1
endif

" View errors if updates fail
if !exists('g:outlook_view_cscript_error')
    let g:outlook_view_cscript_error = 1
endif

" Whether to open the email in a new tab
if !exists('g:outlook_use_tabs')
    let g:outlook_use_tabs = 0
endif

" Whether to delete the buffer on save
if !exists('g:outlook_nobdelete')
    let g:outlook_nobdelete = 1
endif

" autoindent - preserve indent level on new line
if !exists('g:outlook_noautoindent')
    setlocal autoindent
endif

" javascript  - location of the outlookvim.js file
if !exists('g:outlook_javascript')
    " Default location for the outlookvim.js file.
    " This can be overridden in your vimrc via
    " g:outlook_javascript
    " let g:outlook_javascript = expand('$VIM/vimfiles/plugin/outlookvim.js')
    let g:outlook_javascript = expand('<sfile>:p:h').'/outlookvim.js'
endif

" servername  - Choose which Vim server instance to edit the email with
if !exists('g:outlook_servername')
    let g:outlook_servername = ''
endif

if !exists('g:outlook_always_use_unicode')
    let g:outlook_always_use_unicode = 0
endif

if !exists('g:outlook_scan_email_body_unicode')
    let g:outlook_scan_email_body_unicode = 1
endif

if !exists('g:outlook_supported_body_format')
    let g:outlook_supported_body_format = 'plain'
endif

if !exists('g:outlook_file_type')
    let g:outlook_file_type = 'mail'
endif

if !exists('g:outlook_cmd_filter_pre')
    let g:outlook_cmd_filter_pre = ''
endif

if !exists('g:outlook_cmd_filter_post')
    let g:outlook_cmd_filter_post = ''
endif

let s:outlook_edit_cmd = (g:outlook_use_tabs == 0 ? 'edit' : 'tabnew' )

" globpath uses wildignore and suffixes options unless a flag is provided
" to ignore those settings.
let s:ignore_wildignore_setting = 1

function! s:Outlook_WarningMsg(msg)
    echohl WarningMsg
    echomsg "outlook: ".a:msg
    echohl None
endfunction

function! s:Outlook_ErrorMsg(msg)
    echohl ErrorMsg
    echomsg "outlook: ".a:msg
    echohl None
endfunction

" Publicly available function
function! Outlook_EditFile(filename, encoding, bodyFormat)
    " Do not polute the users command history
    call histdel(':', -1)

    if g:outlook_servername == '' || g:outlook_servername == v:servername
        if !filereadable(a:filename)
            call s:Outlook_ErrorMsg( 'Cannot find filename['.a:filename.']')
            return
        endif

        let s:outlook_edit_cmd = 'edit'
        if !exists('g:outlook_edit_cmd')
            if g:outlook_use_tabs == 1 
                " Check if Vim was just launched, if so, do not create a
                " new tab, just edit the file.
                " There is only 1 file, only 1 window, only 1 tab. 
                " Max 1 line and the file is not modified.
                if !( bufnr('$') == 1 && winnr('$') == 1 && tabpagenr('$') == 1 
                            \ && getbufvar(1, "&modified") == 0 && empty(bufname(1)) == 1 )
                    let s:outlook_edit_cmd = 'tabnew'
                endif
            else
                " Check if the buffer we are in is modified and if nohidden is set
                if( &modified == 1 && &hidden == 0 )
                    let s:outlook_edit_cmd = 'split'
                endif
            endif
        else
            " Check if Vim was just launched, if so, just simply
            " edit the file.
            " There is only 1 file, only 1 window, only 1 tab. 
            " Max 1 line and the file is not modified.
            if !( bufnr('$') == 1 && winnr('$') == 1 && tabpagenr('$') == 1 
                        \ && getbufvar(1, "&modified") == 0 && empty(bufname(1)) == 1 )
                let s:outlook_edit_cmd = g:outlook_edit_cmd
            endif
        endif

        let cmd = ':'.
                    \ s:outlook_edit_cmd.
                    \ (a:encoding==''?'':' ++enc='.a:encoding).
                    \ ' '.a:filename

        let g:outlook_last_cmd = cmd
        if g:outlook_debug == 1
            call s:Outlook_WarningMsg( 'Outlook_EditFile before edit bufnr['.bufnr('%').'] bufname['.bufname(bufnr('%')).'] cmd['.g:outlook_last_cmd.']' )
        endif
        exec cmd

        if g:outlook_cmd_filter_pre != ''
            let cmd = ':%!' . expand(g:outlook_cmd_filter_pre)
            if g:outlook_debug == 1
                call s:Outlook_WarningMsg( 'Outlook_EditFile executing cmd_filter_pre cmd['.cmd.']' )
            endif
            exec cmd
        endif

        let b:outlook_body_format = a:bodyFormat
        let b:outlook_action      = 'update'

        " Determine the body format, default to plain or text
        if !exists('b:outlook_body_format')
            let b:outlook_body_format = 'plain'
            if exists('g:outlook_supported_body_format')
                if g:outlook_supported_body_format =~? 'html'
                    if &filetype == 'html'
                        let b:outlook_body_format = 'html'
                    endif
                elseif g:outlook_supported_body_format =~? 'rtf'
                    " Rich Text Format (RTF) is full of codes which
                    " Vim does not support.  A tool like "pandoc"
                    " can be used to convert between RTF and HTML.
                    " Since Vim doesn't support RTF, set the filetype
                    " to HTML and hope the pre and post filters have 
                    " been defined:
                    "     g:outlook_cmd_filter_pre
                    "     g:outlook_cmd_filter_post
                    if &filetype == 'html'
                        let b:outlook_body_format = 'html'
                    endif
                endif
            endif
        endif

        if exists('g:outlook_textwidth') && g:outlook_textwidth != 0
            let &l:textwidth = g:outlook_textwidth
        endif

        if g:outlook_debug == 1
            call s:Outlook_WarningMsg( 'Outlook_EditFile after edit bufnr['.bufnr('%').'] file['.a:filename.'] bodyFormat['.b:outlook_body_format.']' )
        endif
    else
        if match( serverlist(), '\<'.g:outlook_servername.'\>' ) > -1
            call remote_send( g:outlook_servername, ":call Outlook_EditFile( '".a:filename."', '".a:encoding."' )\<CR>" )
        else
            call s:Outlook_ErrorMsg( 'Please start a new Vim instance using "gvim --servername '.g:outlook_servername.'"')
        endif
    endif
endfunction

function! s:Outlook_BufEnter()
    let l:ft_cur = &filetype
    let l:ft_new = &filetype

    " Check various settings to determine if the
    " filetype must be set
    if !exists('b:outlook_body_format')
        let b:outlook_body_format = 'plain'
        let l:ft_new = g:outlook_file_type

        if exists('g:outlook_supported_body_format')
            if g:outlook_supported_body_format =~? 'html'
                if getline(1) =~ '^<html'
                    let b:outlook_body_format = 'html'
                    let l:ft_new = b:outlook_body_format
                endif
            endif
        endif
    else
        if b:outlook_body_format == 'html'
            if getline(1) =~ '^<html'
                let l:ft_new = b:outlook_body_format
            endif
        endif
    endif

    if l:ft_cur != l:ft_new
        exec 'setlocal filetype='.l:ft_new
    endif
endfunction

function! s:Outlook_BufWritePost()
    " autoread, prevents this message:
    "      "File has changed, do you want to Load"
    if !exists('g:outlook_noautoread')
        setlocal autoread
    endif

    let l:filename = expand("<afile>:p")
    let l:filename_filter_post = l:filename . '.post'
    if l:filename == ''
        let l:filename = expand("%:p")
        call s:Outlook_WarningMsg( 'Filename was blank, using:'.l:filename )
    endif

    let l:bufnr = expand("<abuf>")
    let l:bodyFormat = (exists('b:outlook_body_format')?(b:outlook_body_format):'plain')

    if g:outlook_debug == 1
        call s:Outlook_WarningMsg( 'Outlook_BufWritePost file['.l:filename.'] bufnr['.l:bufnr.'] bodyFormat['.b:outlook_body_format.']' )
    endif

    if g:outlook_cmd_filter_post != ''
        let cmd = 'silent! write !' . expand(g:outlook_cmd_filter_post) . '>' . l:filename_filter_post
        if g:outlook_debug == 1
            call s:Outlook_WarningMsg( 'Outlook_BufWritePost executing cmd_filter_post cmd['.cmd.']' )
        endif
        exec cmd
    endif

    " Call the Javascript function to ask Outlook to update the email
    " with the edited contents.
    " Depending on if a cmd_filter was provided instructs
    " which file to use.
    let cmd = 'cscript "'. expand(g:outlook_javascript).
                \ '" "'.
                \ ( (g:outlook_cmd_filter_post == '') ? (l:filename) : (l:filename_filter_post) ).
                \ '" '.
                \ g:outlook_nobdelete.
                \ ' "'.
                \ l:bodyFormat.
                \ '" '
    if g:outlook_debug == 1
        call s:Outlook_WarningMsg( 'Outlook_BufWritePost executing['.cmd.'] bufnr['.l:bufnr.']' )
    endif

    try
        let g:outlook_cscript_output = system(cmd)
        if g:outlook_debug == 1
            call s:Outlook_WarningMsg( 'Outlook_NewEmail results['.g:outlook_cscript_output.']' )
        endif
    catch /.*/
        call s:Outlook_WarningMsg( 'Outlook_BufWritePost: Error calling cscript to update Outlook bufnr['.l:bufnr.'] E['.v:exception.']' )
        if (g:outlook_save_cscript_output == 1 && g:outlook_view_cscript_error) || g:outlook_debug
           call s:Outlook_WarningMsg( v:exception )
       endif
    finally
        " Cleanup the cmd_filter_post file if one was created
        if g:outlook_cmd_filter_post != ''
            let rc = delete(l:filename_filter_post)
        endif
    endtry

    if (g:outlook_save_cscript_output == 1 && g:outlook_view_cscript_error) || g:outlook_debug
        if g:outlook_cscript_output =~ '\c\(OutlookVim\[\d\+\]:\s*\(Successfully\)\@<=\|runtime error\)'
           call s:Outlook_WarningMsg( substitute(g:outlook_cscript_output, '\c^.*\(OutlookVim\[.*\)', '\1', '') )
        elseif g:outlook_nobdelete == 0
            if g:outlook_debug == 1
                call s:Outlook_WarningMsg( 'Outlook_BufWritePost deleting buffer['.l:bufnr.'] when viewing cscript error' )
            endif
            bdelete
        endif
    else
        if g:outlook_nobdelete == 0
            if g:outlook_debug == 1
                call s:Outlook_WarningMsg( 'Outlook_BufWritePost deleting buffer['.l:bufnr.']' )
            endif
            bdelete
        endif
    endif
endfunction

function! s:Outlook_BufUnload()
    " This is necessary in case the buffer is not saved (:w), since
    " the temporary files are (by default) deleted by outlookvim.js.
    " But the javascript is only called if you save the buffer, if
    " you choose to abandon your edits (:bw!), the temporary files are
    " left over in the temporary directory.
    if !exists('g:outlook_nodelete_unload') || g:outlook_nodelete_unload != 1
        if expand('<afile>') == expand('%')
            if expand('<afile>:e') == 'outlook'
                if g:outlook_debug == 1
                    call s:Outlook_WarningMsg( 'Outlook_BufUnload deleting['.expand('<afile>:p').'] bufnr['.expand("<abuf>").']' )
                endif
                call delete(expand('<afile>:p').'.ctl')
                call delete(expand('<afile>:p'))
            endif
        else
            if g:outlook_debug == 1
                call s:Outlook_WarningMsg( 'Outlook_BufUnload not deleting buffer, most likely initial buffer c['.expand('%').'] a['.expand('<afile>').']' )
            endif
        endif
    endif
endfunction

function! s:Outlook_BufDelete()
    " This is necessary in case the buffer is not saved (:w), since
    " the temporary files are (by default) deleted by outlookvim.js.
    " But the javascript is only called if you save the buffer, if
    " you choose to abandon your edits (:bw!), the temporary files are
    " left over in the temporary directory.
    if !exists('g:outlook_nodelete_unload') || g:outlook_nodelete_unload != 1
        if expand('<afile>:e') == 'outlook'
            if g:outlook_debug == 1
                call s:Outlook_WarningMsg( 'Outlook_BufDelete deleting['.expand('<afile>:p').'] bufnr['.expand("<abuf>").']' )
            endif
            call delete(expand('<afile>:p').'.ctl')
            call delete(expand('<afile>:p'))
        endif
    endif
endfunction

function! s:Outlook_NewEmail()
    if bufname('%') == ''
       call s:Outlook_WarningMsg( 'OutlookVim: You must save the file first' )
       return
    endif

    if !exists('b:outlook_body_format')
        let b:outlook_body_format = 'plain'
        if exists('g:outlook_supported_body_format')
            if g:outlook_supported_body_format =~? 'html'
                if &filetype == 'html'
                    let b:outlook_body_format = 'html'
                endif
            endif
        endif
    endif
    let b:outlook_action = 'new'
    " Do not delete this buffer after updating Outlook
    let b:outlook_nobdelete = 1

    let cmd = 'cscript "'. expand(g:outlook_javascript).
                \ '" "'.
                \ expand('%:p').
                \ '" '.
                \ b:outlook_nobdelete.
                \ ' "'.
                \ b:outlook_body_format.
                \ '" '
    if g:outlook_debug == 1
        call s:Outlook_WarningMsg( 'Outlook_NewEmail executing['.cmd.'] bufnr['.bufnr('%').']' )
    endif

    try
        let g:outlook_cscript_output = system(cmd)
        if g:outlook_debug == 1
            call s:Outlook_WarningMsg( 'Outlook_NewEmail results['.g:outlook_cscript_output.']' )
        endif
    catch /.*/
        call s:Outlook_WarningMsg( 'Outlook_NewEmail: Error calling cscript to update Outlook bufnr['.bufnr('%').'] E['.v:exception.']' )
        if (g:outlook_save_cscript_output == 1 && g:outlook_view_cscript_error) || g:outlook_debug
           call s:Outlook_WarningMsg( v:exception )
       endif
    finally
    endtry
endfunction

command! OutlookNewEmail  call s:Outlook_NewEmail()

" Check is cscript.exe is already in the PATH
" Some path entries may end in a \ (c:\util\;), this must also be replaced
" or globpath fails to parse the directories
if v:version > 703 || v:version == 702 && has('patch051')
    let cscript_location = globpath(substitute($PATH, '\\\?;', ',', 'g'), 'cscript.exe', s:ignore_wildignore_setting)
else
    let cscript_location = globpath(substitute($PATH, '\\\?;', ',', 'g'), 'cscript.exe')
endif

if strlen(cscript_location) == 0
    call s:Outlook_ErrorMsg("Cannot find cscript.exe in system path")
    finish
endif

if exists('g:outlook_javascript')
    if !filereadable(expand(g:outlook_javascript))
        call s:Outlook_ErrorMsg("Cannot find javascript file[" .
                \ expand(g:outlook_javascript) .
                \ ']' )
        finish
    endif
else
    call s:Outlook_ErrorMsg("Cannot find the variable: g:outlook_javascript ")
    finish
endif

" These autocommands only need to be created once,
" so store a script variable to prevent reloading
if has('autocmd') && !exists("g:loaded_outlook")
    " Save the current default register
    let saveB = @"

    " Create a group of the autocommands for outlook
    augroup outlook
    " Remove the previous group (if it existed)
    au!

    " Each time we enter this buffer, set the filetype to mail
    " which allows us to rely on each personal users mail preferences
    " exec 'autocmd BufEnter *.outlook setlocal filetype='.g:outlook_file_type
    " exec 'autocmd BufEnter *.outlook setlocal filetype='.(exists('b:outlook_body_format')?(b:outlook_body_format):(g:outlook_file_type))
    autocmd BufEnter *.outlook call s:Outlook_BufEnter()

    " nested is required since we are issuing a bdelete, inside an autocmd
    " so we also need the required autocmd to fire for that command.
    " setlocal autoread, prevents this message:
    "      "File has changed, do you want to Load"
    autocmd BufWritePost *.outlook nested call s:Outlook_BufWritePost()

    " autocmd BufUnload *.outlook call s:Outlook_BufUnload()
    autocmd BufDelete *.outlook call s:Outlook_BufDelete()

    augroup END

    " Don't re-run the script if already sourced
    let g:loaded_outlook = 14

    let @"=saveB
endif

" If unicode is requested, verify Vim supports it.
" If not, display an error and disable unicode.
if g:outlook_always_use_unicode == 1
    if match(&fileencodings, '\<ucs-bom\|utf\>') == -1
        let g:outlook_always_use_unicode = 0
        call s:Outlook_WarningMsg( 'OutlookVim: Cannot force Outlook to use unicode as Vim is not setup for unicode. '.
                    \ 'See :h outlook-unicode' )
    endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
