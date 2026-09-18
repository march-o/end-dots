# Martins' interactive shell configuration.
export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.local/share/oh-my-zsh"
export ZSH_CUSTOM="$ZSH/custom"

ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
plugins=(git fzf zsh-autosuggestions zsh-syntax-highlighting fzf-tab)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# Accept an autosuggestion with Tab; otherwise open fzf-tab completion.
_tab_or_fzf() {
  if [[ -n "$POSTDISPLAY" ]]; then
    zle autosuggest-accept
  elif (( $+widgets[fzf-tab-complete] )); then
    zle fzf-tab-complete
  else
    zle expand-or-complete
  fi
}
zle -N _tab_or_fzf
bindkey '^I' _tab_or_fzf
bindkey '^H' backward-kill-word
bindkey '^Z' undo

for fragment in "$HOME"/.config/zshrc.d/*.{zsh,sh}(N); do
  source "$fragment"
done

[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

alias clear="printf '\033[2J\033[3J\033[1;1H'"
alias celar=clear
alias claer=clear
alias pamcan=pacman
alias q='qs -c ii'
alias ls='eza --icons=auto'
alias grep=rg
alias find=fd
[[ "$TERM" == xterm-kitty ]] && alias ssh='kitten ssh'

# Explicitly requested unsafe shortcut: run Codex without approvals or sandboxing.
alias cod='codex --dangerously-bypass-approvals-and-sandbox'
alias codr='codex resume --last --dangerously-bypass-approvals-and-sandbox'
