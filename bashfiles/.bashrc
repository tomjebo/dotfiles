# Linux/Ubuntu

# sudo apt-get install bash-completion
if [ -f /etc/bash_completion ]; then
. /etc/bash_completion
fi

export PS1='\[\033[01;32m\]\u@\h\[\033[01;34m\] \w\[\033[01;32m\]$(__git_ps1)\[\033[01;34m\] \$\[\033[34m\] '
