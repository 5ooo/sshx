([简体中文](README_zh.md) | English)

# sshx

A lightweight SSH helper for passwordless access and memorable host aliases. Set up a host once, then connect or copy files with `sshx`, standard `ssh`, or `scp`.

## Features

- Passwordless SSH connections after a one-time setup.
- Memorable aliases for servers, usernames, and ports.
- Reuse aliases directly with `ssh`, `scp`, and other SSH tools.
- Command and saved-alias completion.
- Support for custom usernames, hosts, ports, and aliases.
- List, rename, and remove saved connections.
- Choose whether to keep or remove saved data during uninstall.
- Zero extra dependencies, fast to install, and ready to use.

## Supported Platforms

| Platform | Shell | Status |
| --- | --- | --- |
| Linux | Bash | Supported |
| macOS | zsh, Bash | Supported |
| WSL (Linux) | Bash | Supported |
| Native Windows | PowerShell, cmd | Supported |

Required OpenSSH commands: `ssh`, `scp`, and `ssh-keygen`. Windows also requires Windows PowerShell 5.1 and the Windows OpenSSH Client optional feature. Initial setup expects a POSIX-compatible remote shell, such as the default shell on Linux or macOS.

## Project Layout

| Directory | Platform and contents |
| --- | --- |
| `linux-macos/` | Shared program, installers, and completion for Linux, macOS, and WSL. |
| `windows/` | Windows program, installers, completion, and regression tests. |
| `docs/` | Shared implementation notes. |

Each platform directory contains the files needed to install and run it and can be copied to the corresponding system on its own.

## Install

### Linux / macOS / WSL

```bash
git clone <repository-url>
cd sshx
./linux-macos/scripts/install.sh
```

Restart the terminal, or run the `source` command printed by the installer.

### Windows

From the project directory in PowerShell or cmd, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\install-sshx.ps1
```

Open a new terminal to use `sshx`. The installer adds the command to the user PATH and enables completion in the Windows PowerShell 5.1 profile. If the execution policy prevents profiles from loading, the command still works, but completion requires the profile to be enabled. The `sshx.cmd` launcher uses `Bypass` only for its PowerShell process; it does not change the global execution policy. WSL and Git Bash are not required. For completion in PowerShell 7, rerun the command with `pwsh.exe` instead of `powershell.exe` to update its separate profile.

## Quick Start

Create a host alias on the first connection. Enter the remote password when prompted.

```bash
sshx ubuntu@172.16.10.76 dev-server
```

Use a custom port when needed:

```bash
sshx ubuntu@172.16.10.76:2222 dev-server
sshx -p 2222 ubuntu@172.16.10.76 dev-server
```

After setup, use the alias without re-entering the host, port, or password:

```bash
sshx dev-server
ssh dev-server

scp ./report.txt dev-server:~/
scp -r ./project dev-server:~/projects/
scp dev-server:~/report.txt ./
```

## Command Reference

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

- `ip`: server IP address or hostname; the current local username is used by default.
- `user@ip`: specify the remote username.
- `:port` or `-p port`: specify the SSH port; defaults to `22`.
- `[alias]`: optional memorable name, such as `dev-server`.
- `sshx alias`: connect to a saved host.
- `list`, `mv`, and `rm`: list, rename, or remove saved aliases.

## Uninstall

Linux, macOS, or WSL:

```bash
./linux-macos/scripts/uninstall.sh
```

Windows (from the project directory):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\uninstall-sshx.ps1
```

The script removes sshx and its shell setup, then asks whether to remove sshx aliases and its dedicated key pair. Other SSH configuration and keys are not affected. On Windows, `-Yes` skips the uninstall confirmation and keeps saved data; pass `-Yes -RemoveData` explicitly to remove that data too.

## Development

See [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) for implementation notes.
