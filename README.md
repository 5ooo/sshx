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

## Supported Platforms

| Platform | Shell | Status |
| --- | --- | --- |
| Linux | Bash | Supported |
| macOS | zsh, Bash | Supported |
| WSL (Linux) | Bash | Supported |
| Native Windows (PowerShell/cmd) | — | Not supported |

Required OpenSSH commands: `ssh`, `scp`, and `ssh-keygen`. On systems without `ssh-copy-id` (commonly macOS), sshx falls back to `ssh` to install the public key.

## Install

```bash
git clone <repository-url>
cd sshx
./scripts/install-sshx.sh
```

Restart the terminal, or run the `source` command printed by the installer.

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

```bash
./scripts/uninstall-sshx.sh
```

The script removes sshx and its shell setup, then asks whether to remove sshx aliases and its dedicated key pair. Other SSH configuration and keys are not affected.

## Development

See [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) for implementation notes.
