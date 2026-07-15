([English](README.md) | 简体中文)

# sshx

一个轻量的 SSH 免密连接工具。首次配置服务器后，可以直接通过 `sshx`、标准 `ssh` 或 `scp` 使用保存的别名。

## 特点

- 首次配置后即可免密 SSH 连接。
- 用易记别名保存服务器、用户名和端口。
- 别名可直接用于 `ssh`、`scp` 等 SSH 工具。
- 支持命令和已保存别名补全。
- 支持自定义用户名、主机、端口和别名。
- 支持查看、重命名和删除已保存连接。
- 卸载时可选择保留或删除保存的数据。

## 支持平台

| 平台 | Shell | 状态 |
| --- | --- | --- |
| Linux | Bash | 支持 |
| macOS | zsh、Bash | 支持 |
| WSL（Linux 环境） | Bash | 支持 |
| 原生 Windows（PowerShell/cmd） | — | 暂不支持 |

系统需要提供 `ssh`、`scp` 和 `ssh-keygen`。如果没有 `ssh-copy-id`（macOS 常见），sshx 会自动使用 `ssh` 安装公钥。

## 安装

```bash
git clone <仓库地址>
cd sshx
./scripts/install-sshx.sh
```

重新打开终端，或执行安装脚本输出的 `source` 命令。

## 快速开始

首次连接时创建别名，并按提示输入远程服务器密码：

```bash
sshx ubuntu@172.16.10.76 dev-server
```

指定端口：

```bash
sshx ubuntu@172.16.10.76:2222 dev-server
sshx -p 2222 ubuntu@172.16.10.76 dev-server
```

配置后可直接用别名连接和传输文件，通常无需再输入密码：

```bash
sshx dev-server
ssh dev-server

scp ./report.txt dev-server:~/
scp -r ./project dev-server:~/projects/
scp dev-server:~/report.txt ./
```

## 命令说明

```text
sshx ip [alias]
sshx user@ip [alias]
sshx ip:port [alias]
sshx user@ip:port [alias]
sshx -p port user@ip [alias]
sshx alias
sshx list
sshx mv old_alias new_alias
sshx rm alias
sshx help
```

- `ip`：服务器 IP 或域名；默认使用本机当前用户名。
- `user@ip`：指定远程用户名。
- `:port` 或 `-p port`：指定 SSH 端口，默认 `22`。
- `[alias]`：可选别名，例如 `dev-server`。
- `sshx alias`：连接已保存的服务器。
- `list`、`mv`、`rm`：查看、重命名或删除已保存别名。

## 卸载

```bash
./scripts/uninstall-sshx.sh
```

卸载会移除 sshx 和 shell 初始化配置，然后询问是否删除 sshx 保存的连接和专用密钥。其他 SSH 配置和密钥不会受影响。

## 开发说明

实现细节见 [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md)。
