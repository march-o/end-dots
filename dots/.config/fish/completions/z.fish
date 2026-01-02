if not type -q zoxide
    exit
end

complete -c z -f -a "(zoxide query -l)" -d "zoxide directory"
