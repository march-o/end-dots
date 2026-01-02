if not type -q zoxide
    exit
end

complete -c zi -f -a "(zoxide query -l)" -d "zoxide directory"
