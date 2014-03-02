
which ruby 2>&1 >/dev/null && ruby <<-EOC
    path = File.expand_path('~/.dotfiles-last-update')
    exit(0) unless File.exists?(path)
    time = File.mtime(path)
    status = Time.now - time > 86400 ? 0 : 1
    exit(status)
EOC

if [ $? -eq 0 ]; then
    ~/bin/update-dotfiles >~/.dotfiles-last-update.log 2>&1
    if [ $? -eq 0 ]; then
        touch ~/.dotfiles-last-update
        echo "Dotfiles updated!"
    else
        echo "Something went wrong updating the dotfiles. Please check the log (~/.dotfiles-last-update.log)."
    fi
fi
