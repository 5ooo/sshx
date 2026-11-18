[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $projectDir 'src'
$binDir = Join-Path $HOME '.local\bin'
$files = @{
    'sshx.ps1' = 'sshx-main.ps1'
    'sshx.cmd' = 'sshx.cmd'
    'sshx-completion.ps1' = 'sshx-completion.ps1'
}
foreach ($source in $files.Keys) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDir $source))) { throw 'Run this script from a complete sshx project directory.' }
}
foreach ($command in @('ssh', 'scp', 'ssh-keygen')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw 'Windows OpenSSH Client is required. Install it from Windows Optional Features, then rerun this script.' }
}
. (Join-Path $PSScriptRoot 'sshx-marked-block.ps1')
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
foreach ($source in $files.Keys) {
    Copy-Item -LiteralPath (Join-Path $sourceDir $source) -Destination (Join-Path $binDir $files[$source]) -Force
}
if ($env:OS -eq 'Windows_NT') {
    $registry = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $exists = $registry.GetValueNames() -contains 'Path'
        $kind = if ($exists) { $registry.GetValueKind('Path') } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }
        if ($kind -ne [Microsoft.Win32.RegistryValueKind]::String -and $kind -ne [Microsoft.Win32.RegistryValueKind]::ExpandString) {
            throw 'The current user PATH has an unexpected registry type; add the sshx bin directory to PATH manually.'
        }
        $userPath = [string]$registry.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $pathParts = @($userPath -split ';' | Where-Object { $_ })
        $expanded = @($pathParts | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"')).TrimEnd('\') })
        $pathChanged = $expanded -notcontains $binDir.TrimEnd('\')
        if ($pathChanged) {
            $separator = if ($userPath.Length -eq 0 -or $userPath.EndsWith(';')) { '' } else { ';' }
            $registry.SetValue('Path', ($userPath + $separator + $binDir), $kind)
        }
    } finally {
        $registry.Dispose()
    }
    if ($pathChanged) {
        try {
            if (-not ('SshxEnvironmentNotifier' -as [type])) {
                Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SshxEnvironmentNotifier {
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(IntPtr hwnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
}
'@
            }
            $result = [UIntPtr]::Zero
            [SshxEnvironmentNotifier]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 1000, [ref]$result) | Out-Null
        } catch {
            Write-Warning 'PATH was saved, but Windows could not be notified. Sign out and back in if a new terminal cannot find sshx.'
        }
    }
}
$snippet = @'
function global:sshx { & (Join-Path $HOME '.local\bin\sshx.cmd') @args }
. (Join-Path $HOME '.local\bin\sshx-completion.ps1')
'@
try {
    Set-SshxMarkedBlock -Path $PROFILE -Begin '# >>> sshx PowerShell setup >>>' -End '# <<< sshx PowerShell setup <<<' -Content $snippet
} catch {
    Write-Warning "Installed the command, but could not configure PowerShell completion: $($_.Exception.Message)"
}
Write-Host 'sshx has been installed for PowerShell and cmd.'
Write-Host 'Open a new terminal to refresh PATH. PowerShell completion loads when profiles are enabled.'
