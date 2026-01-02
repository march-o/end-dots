if type -q fzf
    set -l fzf_share (string replace -r '/bin/fzf$' '/share/fzf' (command -s fzf))
    set -l fzf_loaded 0
    for f in $fzf_share/key-bindings.fish /usr/share/fzf/key-bindings.fish /usr/local/share/fzf/key-bindings.fish
        if test -f $f
            source $f
            set fzf_loaded 1
            break
        end
    end
    for f in $fzf_share/completion.fish /usr/share/fzf/completion.fish /usr/local/share/fzf/completion.fish
        if test -f $f
            source $f
            set fzf_loaded 1
            break
        end
    end
    if test $fzf_loaded -eq 0; and type -q fzf_configure_bindings
        fzf_configure_bindings
    end
end
