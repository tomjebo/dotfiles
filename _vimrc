let mapleader=","
set nocompatible
set encoding=utf-8
set spell spelllang=en_us
set spellfile=$HOME/vimfiles/spellfile.en_us.add
set termguicolors
colo zellner
set diffopt+=iwhite
if has('gui_running')
    set background=light
else
    set background=dark
endif
set backupdir=c:\\tmp,c:\\temp
set undodir=c:\\tmp,c:\\temp
set dir=c:\\tmp,c:\\temp
set autochdir

cnoremap %% <C-R>=fnameescape(expand('%:h')).'/'<cr>
map <leader>ew :e %%
map <leader>es :sp %%
map <leader>ev :vsp %%
map <leader>et :tabe %%

set cpoptions+=*
set guifont=Envy_Code_R:h11:cANSI
set guioptions-=T
"set statusline=\\\\%n\\%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P
set laststatus=2
set clipboard=unnamed
set hidden
set nu
set rnu
set scrolloff=5
cd $HOME\\Documents
source $VIMRUNTIME/vimrc_example.vim
"source $VIMRUNTIME/mswin.vim
source $HOME/vimfiles/tomjebo.vim

"behave mswin

"execute pathogen#infect()
filetype off
syntax on
set rtp+=$HOME/vimfiles/bundle/vundle.vim

call vundle#begin()

Plugin 'gmarik/vundle.vim'
Plugin 'XadillaX/json-formatter.vim'

call vundle#end()

filetype plugin indent on

au FileType xml setlocal equalprg=xmllint\ --format\ --recover\ -\ 2>/dev/null
au! BufWritePost .vimrc source % 

