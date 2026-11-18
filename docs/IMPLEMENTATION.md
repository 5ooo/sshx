# sshx 实现说明

本文档面向维护者，说明 sshx 的工作方式和本地文件结构。

## 组件

- `linux-macos/src/sshx`：主 Bash 脚本，负责解析参数、生成密钥、安装公钥和维护 SSH 配置。
- `linux-macos/scripts/install.sh`：将脚本安装到 `~/.local/bin/sshx`，并按当前 shell 启用 Bash 或 zsh 补全。
- `linux-macos/src/sshx-completion.bash`：供 Bash 使用的补全脚本。
- `linux-macos/src/sshx-completion.zsh`：供 macOS 默认 zsh 使用的补全脚本。
- `windows/src/sshx.ps1`：原生 Windows PowerShell 实现；`windows/src/sshx.cmd` 是 PowerShell 和 cmd 共用的入口。
- `windows/scripts/install-sshx.ps1`、`windows/scripts/uninstall-sshx.ps1`：Windows 安装和卸载脚本。
- `windows/src/sshx-completion.ps1`：PowerShell 补全。
- `windows/scripts/sshx-marked-block.ps1`：在保留标记之外字节和原编码的前提下更新配置区块。

## 密钥

sshx 使用专用 ED25519 密钥：

```text
~/.ssh/id_ed25519_sshx
~/.ssh/id_ed25519_sshx.pub
```

首次使用时脚本调用 `ssh-keygen` 创建密钥。Bash 版本优先调用 `ssh-copy-id`，未安装时使用 `ssh` 回退；Windows 版本通过 `ssh` 写入远程 `authorized_keys`。Windows 首次配置要求远程默认 shell 支持 POSIX 命令。

## SSH 配置

主机条目保存在 `~/.ssh/config` 的受管理区块：

```sshconfig
# >>> sshx hosts >>>
Host dev-server
    HostName 172.16.10.76
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519_sshx
    IdentitiesOnly yes
# <<< sshx hosts <<<
```

`Host dev-server` 让 OpenSSH 用别名解析后续连接字段，所以 `ssh`、`scp`、`sftp`、`rsync -e ssh`、sshfs 和多数 OpenSSH 客户端可以共用别名。脚本仅应修改标记之间的内容，必须保留标记外的用户配置。

## 主流程

1. 解析 `user@host:port`、`-p port` 和可选别名。
2. 未提供别名时，按用户名、主机和端口生成默认别名。
3. 创建 `~/.ssh`、配置文件和专用密钥（如不存在）。
4. 对新目标安装公钥：优先使用 `ssh-copy-id`，macOS 等缺少该命令的环境则使用 `ssh` 回退；远程已存在相同公钥时仍继续保存配置。
5. 将 `Host` 条目插入受管理区块，并执行 `ssh <alias>`。

外部配置占用别名时，脚本不可覆盖；sshx 管理的同名条目则在用户确认后更新。

## 别名管理

- `sshx list` 显示保存的连接。
- `sshx mv` 修改 `Host` 名称。
- `sshx rm` 仅删除受管理区块内的匹配主机条目。

## 安装与补全

安装脚本会写入：

```text
~/.local/bin/sshx
~/.local/share/bash-completion/completions/sshx
```

并在 `~/.bashrc` 的 sshx 标记区块中增加 PATH 与补全脚本加载逻辑。重复安装不会重复追加。

Windows 安装器将 `sshx.cmd`、`sshx-main.ps1` 和补全脚本复制到用户目录下的 `.local\bin`，加入用户 PATH，并在当前 PowerShell 配置文件的标记区块中启用补全。命令入口启动 Windows PowerShell 5.1 并对该进程临时使用执行策略 `Bypass`。Windows 首次创建 sshx 区块时将其放在 SSH 配置开头，使主机专属设置先于通配配置生效；写入使用无 BOM 的 UTF-8。配置损坏、标记不配对或公钥安装失败时不会删除现有条目。

## 维护约束

- `~/.ssh` 权限保持 `700`，配置文件保持 `600`。
- 不要输出或记录私钥内容。
- 变更配置解析逻辑时，避免修改 sshx 标记区块之外的内容。

## Windows 回归检查

在安装了 PowerShell 7.3+ 和 Python 3 的 Linux 或 macOS 开发环境中，可运行 `PWSH=/path/to/pwsh python3 windows/tests/test_windows_port.py`。测试使用隔离目录和模拟 SSH 传输，验证真实密钥生成、远程安装命令、配置解析、别名管理、安装和卸载；它不能代替 Windows 系统上的端到端检查。
