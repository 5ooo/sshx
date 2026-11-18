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
- 0 额外依赖，极速安装，开箱即用。

## 支持平台

| 平台 | Shell | 状态 |
| --- | --- | --- |
| Linux | Bash | 支持 |
| macOS | zsh、Bash | 支持 |
| WSL（Linux 环境） | Bash | 支持 |
| 原生 Windows | PowerShell、cmd | 支持 |

系统需要提供 `ssh`、`scp` 和 `ssh-keygen`。Windows 需要 Windows PowerShell 5.1 和 Windows OpenSSH 客户端；如果缺少 OpenSSH 客户端，可在 Windows 的“可选功能”中安装。首次配置目标机器时，远程默认 shell 需要支持 POSIX 命令（例如 Linux 或 macOS 的 shell）。

## 目录结构

| 目录 | 适用平台和内容 |
| --- | --- |
| `linux-macos/` | Linux、macOS 和 WSL 共用的主程序、安装卸载脚本及补全。 |
| `windows/` | Windows 主程序、安装卸载脚本、补全及回归测试。 |
| `docs/` | 共用的实现说明。 |

两个平台目录都包含各自运行和安装所需的文件，可以单独复制到对应系统使用。

## 安装

### Linux / macOS / WSL

```bash
git clone <仓库地址>
cd sshx
./linux-macos/scripts/install.sh
```

重新打开终端，或执行安装脚本输出的 `source` 命令。

### Windows

在 PowerShell 或 cmd 中进入项目目录，执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\install-sshx.ps1
```

重新打开终端后即可使用 `sshx`。安装脚本会为当前用户添加命令路径，并为 Windows PowerShell 5.1 的配置文件添加补全；如果系统执行策略不允许加载配置文件，命令仍可使用，但补全需要启用配置文件。`sshx.cmd` 在启动其 PowerShell 脚本时仅对该进程使用 `Bypass`，不会修改全局执行策略。Windows 不需要 WSL 或 Git Bash。如果使用 PowerShell 7 并希望启用补全，可将上述命令中的 `powershell.exe` 换成 `pwsh.exe` 再执行一次，以更新 PowerShell 7 自己的配置文件。

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

Linux、macOS 或 WSL：

```bash
./linux-macos/scripts/uninstall.sh
```

Windows（在项目目录下）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\uninstall-sshx.ps1
```

卸载会移除 sshx 和对应的 shell 配置，然后询问是否删除 sshx 保存的连接和专用密钥。其他 SSH 配置和密钥不会受影响。Windows 中可使用 `-Yes` 跳过卸载确认并保留数据；如需同时删除数据，可明确指定 `-Yes -RemoveData`。

## 开发说明

实现细节见 [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md)。
