# sshx 实现说明

本文档面向维护者，说明 sshx 的工作方式和本地文件结构。

## 组件

- `sshx`：主 Bash 脚本，负责解析参数、生成密钥、安装公钥和维护 SSH 配置。
- `scripts/install-sshx.sh`：将脚本安装到 `~/.local/bin/sshx`，并按当前 shell 启用 Bash 或 zsh 补全。
- `src/sshx-completion.bash`：供 Bash 使用的补全脚本。
- `src/sshx-completion.zsh`：供 macOS 默认 zsh 使用的补全脚本。

## 密钥

sshx 使用专用 ED25519 密钥：

```text
~/.ssh/id_ed25519_sshx
~/.ssh/id_ed25519_sshx.pub
```

首次使用时脚本调用 `ssh-keygen` 创建密钥；首次添加目标服务器时优先调用 `ssh-copy-id` 写入远程 `authorized_keys`，未安装该命令（例如 macOS）时使用 `ssh` 回退。

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

## 维护约束

- `~/.ssh` 权限保持 `700`，配置文件保持 `600`。
- 不要输出或记录私钥内容。
- 变更配置解析逻辑时，避免修改 sshx 标记区块之外的内容。
