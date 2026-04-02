
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

export GTK_THEME=Nordic-darker

# plugins
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab                    # tab completion with fuzzy search
zinit light zsh-users/zsh-history-substring-search  # up arrow searches history by what you typed
zinit snippet OMZP::copypath       # 'copypath' copies current directory to clipboard
zinit snippet OMZP::extract        # 'extract file.tar.gz' works for any archive format, no more remembering flags
zinit snippet OMZP::docker         # tab completion for all docker commands and container names
zinit snippet OMZP::docker-compose # same for docker compose
zinit light agkozak/zsh-z          # jump to frecent dirs, type 'z projects' instead of cd-ing everywhere
zinit light hlissner/zsh-autopair  # auto-closes brackets, quotes, parentheses — great when writing python
zinit snippet OMZP::git            # all the omz git aliases, gl, gst, gco, gp etc
zinit snippet OMZP::python         # aliases like py=python, pyfind, pygrep
zinit snippet OMZP::pip            # tab completion for pip commands
zinit snippet OMZP::virtualenv     # shows active venv in prompt
zinit light MichaelAquilina/zsh-you-should-use
zinit snippet OMZP::sudo                          # press ESC twice to add sudo to the previous command
zinit snippet OMZP::command-not-found            # suggests what to install when a command isn't found

autoload -Uz compinit && compinit


# keybindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down


# starship prompt
eval "$(starship init zsh)"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# peon-ping quick controls
alias peon="bash /home/msilva/.claude/hooks/peon-ping/peon.sh"
[ -f /home/msilva/.claude/hooks/peon-ping/completions.bash ] && source /home/msilva/.claude/hooks/peon-ping/completions.bash

# fnm
FNM_PATH="/home/msilva/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

