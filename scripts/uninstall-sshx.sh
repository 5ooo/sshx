#!/usr/bin/env bash
set -euo pipefail

BIN_FILE="$HOME/.local/bin/sshx"
SSH_CONFIG_FILE="$HOME/.ssh/config"
SSHX_KEY_FILE="$HOME/.ssh/id_ed25519_sshx"
SHELL_MARK_BEGIN="# >>> sshx shell setup >>>"
SHELL_MARK_END="# <<< sshx shell setup <<<"
HOSTS_MARK_BEGIN="# >>> sshx hosts >>>"
HOSTS_MARK_END="# <<< sshx hosts <<<"

remove_shell_setup() {
    local profile_file="$1"
    [ -f "$profile_file" ] || return 0
    grep -qF "$SHELL_MARK_BEGIN" "$profile_file" || return 0

    local tmp_file
    tmp_file="$(mktemp)"
    awk -v begin="$SHELL_MARK_BEGIN" -v end="$SHELL_MARK_END" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$profile_file" > "$tmp_file"
    mv "$tmp_file" "$profile_file"
}

if [ "${1:-}" != "--yes" ]; then
    read -r -p "卸载 sshx？[y/N] " answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "已取消。"; exit 0 ;;
    esac
fi

rm -f "$BIN_FILE" \
    "$HOME/.local/share/bash-completion/completions/sshx" \
    "$HOME/.local/share/zsh/site-functions/_sshx"
remove_shell_setup "$HOME/.bashrc"
remove_shell_setup "$HOME/.zshrc"

echo "sshx 已卸载。"

has_sshx_connections=false
if [ -f "$SSH_CONFIG_FILE" ] && grep -qF "$HOSTS_MARK_BEGIN" "$SSH_CONFIG_FILE"; then
    has_sshx_connections=true
fi

if [ "$has_sshx_connections" = true ] || [ -f "$SSHX_KEY_FILE" ] || [ -f "${SSHX_KEY_FILE}.pub" ]; then
    read -r -p "是否删除 sshx 的所有用户数据（保存的连接和专用密钥）？[y/N] " remove_user_data
    case "$remove_user_data" in
        y|Y|yes|YES)
            if [ "$has_sshx_connections" = true ]; then
                tmp_file="$(mktemp)"
                awk -v begin="$HOSTS_MARK_BEGIN" -v end="$HOSTS_MARK_END" '
                    $0 == begin { skip = 1; next }
                    $0 == end { skip = 0; next }
                    !skip { print }
                ' "$SSH_CONFIG_FILE" > "$tmp_file"
                mv "$tmp_file" "$SSH_CONFIG_FILE"
                chmod 600 "$SSH_CONFIG_FILE"
            fi
            rm -f "$SSHX_KEY_FILE" "${SSHX_KEY_FILE}.pub"
            echo "已删除 sshx 保存的连接和专用密钥。"
            ;;
        *)
            echo "已保留 sshx 保存的连接和专用密钥。"
            ;;
    esac
else
    echo "未发现 sshx 用户数据。"
fi
