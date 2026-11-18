[CmdletBinding()]
param([switch]$Yes, [switch]$RemoveData)

$ErrorActionPreference = 'Stop'
if (-not $Yes -and (Read-Host 'Uninstall sshx? [y/N]') -notmatch '^(y|yes)$') { Write-Host 'Cancelled.'; return }
. (Join-Path $PSScriptRoot 'sshx-marked-block.ps1')
$binDir = Join-Path $HOME '.local\bin'
$sshDir = Join-Path $HOME '.ssh'
$config = Join-Path $sshDir 'config'
$key = Join-Path $sshDir 'id_ed25519_sshx'
if (-not $Yes -and -not $RemoveData -and ((Test-Path -LiteralPath $config) -or (Test-Path -LiteralPath $key) -or (Test-Path -LiteralPath "$key.pub"))) {
    $RemoveData = (Read-Host 'Also delete sshx saved hosts and dedicated key? [y/N]') -match '^(y|yes)$'
}
if ($RemoveData) {
    Set-SshxMarkedBlock -Path $config -Begin '# >>> sshx hosts >>>' -End '# <<< sshx hosts <<<' -Remove
    Remove-Item -LiteralPath $key, "$key.pub" -Force -ErrorAction SilentlyContinue
}
try {
    Set-SshxMarkedBlock -Path $PROFILE -Begin '# >>> sshx PowerShell setup >>>' -End '# <<< sshx PowerShell setup <<<' -Remove
} catch {
    Write-Warning "Could not remove the PowerShell profile block: $($_.Exception.Message)"
}
Remove-Item -LiteralPath (Join-Path $binDir 'sshx-main.ps1'), (Join-Path $binDir 'sshx.cmd'), (Join-Path $binDir 'sshx-completion.ps1') -Force -ErrorAction SilentlyContinue
if ($RemoveData) { Write-Host 'sshx and its saved hosts and dedicated key were removed.' }
else { Write-Host 'sshx was uninstalled. Saved hosts and keys were kept.' }
