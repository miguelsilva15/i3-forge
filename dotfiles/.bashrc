# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

alias dbeaver='flatpak run io.dbeaver.DBeaverCommunity'

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"


# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
export PATH="$HOME/.local/bin:$PATH"

# peon-ping quick controls
alias peon="bash /home/msilva/.claude/hooks/peon-ping/peon.sh"
[ -f /home/msilva/.claude/hooks/peon-ping/completions.bash ] && source /home/msilva/.claude/hooks/peon-ping/completions.bash
