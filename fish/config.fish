if status is-interactive
    fastfetch | tte expand --final-gradient-stops 508777 477787 --final-gradient-steps 12 --final-gradient-direction vertical
end

# Theme switcher aliases
alias theme-switch '~/.themes/_scripts/theme-switcher.sh'
alias new-theme '~/.themes/_scripts/new_theme.py'

# Git prompt settings
set -g __fish_git_prompt_show_informative_status 1
set -g __fish_git_prompt_showdirtystate 1
set -g __fish_git_prompt_showupstream auto
set -g __fish_git_prompt_showuntrackedfiles 1
set -g __fish_git_prompt_showstashstate 1
set -g __fish_git_prompt_showcolorhints 1

# Custom prompt - Theme colors applied by theme-switcher
function fish_prompt
    set -l last_status $status
    set -l stat
    if test $last_status -ne 0
        set stat (set_color C5A856)"[$last_status] "(set_color normal)
    end

    string join '' -- \
        (set_color 55834E)"$USER"(set_color normal)"@" \
        (set_color c3c9c6)"$hostname"(set_color normal)" " \
        (set_color c3c9c6)(prompt_pwd)(set_color normal)" " \
        (fish_git_prompt)" " \
        $stat \
        (set_color 3F828A)"▸ "
end
