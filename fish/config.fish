if status is-interactive
    # Commands to run in interactive sessions can go here
end
fish_add_path $HOME/.nimble/bin
fish_add_path /opt/OpenCode

# ---------- Pi: forza il protocollo Kitty per il rendering inline delle immagini ----------
# (foot supporta il protocollo Kitty graphics, ma pi non lo autodetectta)
set -gx PI_IMAGE_PROTOCOL kitty

# ---------- Prompt ----------
function fish_prompt
    # Salva lo stato dell'ultimo comando PRIMA di ogni altro comando
    set -l prev_status $status

    # Percorso completo, senza abbreviazioni tipo ~/m/d
    set -l path "$PWD"

    # Git: ramo + stato
    set -l gitinfo ""
    if git branch --show-current 2>/dev/null | read -l branch
        set gitinfo "$branch"
        set -l status_parts
        test (git diff --name-only --cached 2>/dev/null | wc -l) -gt 0; and set status_parts $status_parts "+staged"
        test (git diff --name-only 2>/dev/null | wc -l) -gt 0; and set status_parts $status_parts "~modificato"
        test (git ls-files --others --exclude-standard 2>/dev/null | wc -l) -gt 0; and set status_parts $status_parts "?nuovi"
        if test -n "$status_parts"
            set gitinfo "$gitinfo ($(string join '/' $status_parts))"
        end
    end

    set -l user_color (set_color cyan)
    set -l path_color (set_color white)
    set -l git_color (set_color magenta)
    set -l arrow_color (set_color green)
    set -l reset (set_color normal)

    # Stato dell'ultimo comando
    if test $prev_status -ne 0
        printf '%s[%s]%s %s[%s]%s ' $user_color matteo $reset $path_color $path $reset
        printf '✘ %s' (set_color red)
    else
        printf '%s[%s]%s %s[%s]%s ' $user_color matteo $reset $path_color $path $reset
        if test -n "$gitinfo"
            printf ' %s(%s)%s' $git_color "$gitinfo" $reset
        end
        printf ' %s›%s ' $arrow_color $reset
    end
end
