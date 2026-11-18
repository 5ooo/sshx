#compdef sshx

_sshx_saved_aliases() {
    [[ -f "$HOME/.ssh/config" ]] || return 0
    awk -v mark_begin="# >>> sshx hosts >>>" -v mark_end="# <<< sshx hosts <<<" '
        $0 == mark_begin { in_sshx_block = 1; next }
        $0 == mark_end { in_sshx_block = 0; next }
        in_sshx_block && /^Host[[:space:]]+/ { print $2 }
    ' "$HOME/.ssh/config" 2>/dev/null
}

_sshx() {
    local -a aliases commands
    aliases=("${(@f)$(_sshx_saved_aliases)}")
    commands=(help list rm mv -p)

    if (( CURRENT == 2 )); then
        case "${words[2]}" in
            rm|mv)
                compadd -- "${aliases[@]}"
                ;;
            *)
                compadd -- "${commands[@]}" "${aliases[@]}"
                ;;
        esac
    elif (( CURRENT == 3 )) && [[ "${words[2]}" == "mv" ]]; then
        compadd -- "${aliases[@]}"
    fi
}

compdef _sshx sshx
