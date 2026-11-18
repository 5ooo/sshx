# Bash completion for sshx.

_sshx_saved_aliases() {
    [ -f "$HOME/.ssh/config" ] || return 0
    awk -v mark_begin="# >>> sshx hosts >>>" -v mark_end="# <<< sshx hosts <<<" '
        $0 == mark_begin { in_sshx_block = 1; next }
        $0 == mark_end { in_sshx_block = 0; next }
        in_sshx_block && /^Host[[:space:]]+/ { print $2 }
    ' "$HOME/.ssh/config" 2>/dev/null
}

_sshx_completion() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"

    local commands="help list rm mv -p"
    local aliases
    aliases="$(_sshx_saved_aliases)"

    case "$prev" in
        -p)
            # 端口是数字，交由 shell 直接输入；下一个参数可继续输入目标地址。
            return
            ;;
        rm)
            COMPREPLY=( $(compgen -W "$aliases" -- "$cur") )
            return
            ;;
        mv)
            COMPREPLY=( $(compgen -W "$aliases" -- "$cur") )
            return
            ;;
    esac

    if (( COMP_CWORD == 1 )); then
        COMPREPLY=( $(compgen -W "$commands $aliases" -- "$cur") )
    fi
}

complete -F _sshx_completion sshx
