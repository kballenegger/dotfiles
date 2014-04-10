type reattach-to-user-namespace &>/dev/null
if [ $? -eq 0 ]; then
    reattach-to-user-namespace -l zsh
else
    type zsh &>/dev/null
    if [ $? -eq 0 ]; then
        zsh -l
    else
        bash -l
    fi
fi
