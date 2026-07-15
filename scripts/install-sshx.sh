#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SOURCE_SSHX="$PROJECT_DIR/src/sshx"
SOURCE_BASH_COMPLETION="$PROJECT_DIR/src/sshx-completion.bash"
SOURCE_ZSH_COMPLETION="$PROJECT_DIR/src/sshx-completion.zsh"
BIN_DIR="$HOME/.local/bin"
MARK_BEGIN="# >>> sshx shell setup >>>"
MARK_END="# <<< sshx shell setup <<<"
SHELL_NAME="$(basename "${SHELL:-bash}")"

if [ ! -f "$SOURCE_SSHX" ] || [ ! -f "$SOURCE_BASH_COMPLETION" ] || [ ! -f "$SOURCE_ZSH_COMPLETION" ]; then
    echo "安装文件不完整，请从完整的 sshx 项目目录运行此脚本。" >&2
    exit 1
fi

mkdir -p "$BIN_DIR"
install -m 755 "$SOURCE_SSHX" "$BIN_DIR/sshx"

case "$SHELL_NAME" in
    zsh)
        PROFILE_FILE="$HOME/.zshrc"
        COMPLETION_FILE="$HOME/.local/share/zsh/site-functions/_sshx"
        mkdir -p "$(dirname "$COMPLETION_FILE")"
        install -m 644 "$SOURCE_ZSH_COMPLETION" "$COMPLETION_FILE"
        SETUP_SNIPPET='if ! typeset -f compdef >/dev/null 2>&1; then
            autoload -Uz compinit
            compinit
        fi
        if [ -f "$HOME/.local/share/zsh/site-functions/_sshx" ]; then
            source "$HOME/.local/share/zsh/site-functions/_sshx"
        fi'
        ;;
    *)
        PROFILE_FILE="$HOME/.bashrc"
        COMPLETION_FILE="$HOME/.local/share/bash-completion/completions/sshx"
        mkdir -p "$(dirname "$COMPLETION_FILE")"
        install -m 644 "$SOURCE_BASH_COMPLETION" "$COMPLETION_FILE"
        SETUP_SNIPPET='if [ -f "$HOME/.local/share/bash-completion/completions/sshx" ]; then
            source "$HOME/.local/share/bash-completion/completions/sshx"
        fi'
        ;;
esac

touch "$PROFILE_FILE"
if ! grep -qF "$MARK_BEGIN" "$PROFILE_FILE"; then
    {
        printf '\n%s\n' "$MARK_BEGIN"
        echo 'case $- in'
        echo '    *i*)'
        echo '        export PATH="$HOME/.local/bin:$PATH"'
        printf '%s\n' "$SETUP_SNIPPET" | sed 's/^/        /'
        echo '        ;;'
        echo 'esac'
        printf '%s\n' "$MARK_END"
    } >> "$PROFILE_FILE"
fi

echo "✨ sshx 已安装完成！"
echo "请重新打开终端，或执行：source $PROFILE_FILE"
echo "已为 $SHELL_NAME 配置命令路径和补全。"
