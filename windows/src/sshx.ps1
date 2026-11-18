$ErrorActionPreference = 'Stop'
$Arguments = @($args)
$SshDir = Join-Path $HOME '.ssh'
$KeyFile = Join-Path $SshDir 'id_ed25519_sshx'
$ConfigFile = Join-Path $SshDir 'config'
$MarkBegin = '# >>> sshx hosts >>>'
$MarkEnd = '# <<< sshx hosts <<<'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)

function Show-Usage {
    if ([Globalization.CultureInfo]::CurrentUICulture.Name -match '^zh(?:-|_|$)') {
        @'
用法:
  sshx ip [alias]                  使用当前本机用户名配置免密登录，并连接
  sshx user@ip [alias]             指定用户名配置免密登录，并连接
  sshx ip:port [alias]             使用当前本机用户名和指定端口
  sshx user@ip:port [alias]        指定用户名和端口
  sshx -p port user@ip [alias]     指定端口
  sshx alias                       连接已保存的主机
  sshx help                        查看帮助
  sshx list                        查看已保存的连接
  sshx mv old_alias new_alias      重命名连接
  sshx rm alias                    删除连接
'@ | Write-Host
    } else {
        @'
Usage:
  sshx ip [alias]                  Set up and connect as the current user
  sshx user@ip [alias]             Set up and connect as a specified user
  sshx ip:port [alias]             Set up with a specified port
  sshx user@ip:port [alias]        Set up with a specified user and port
  sshx -p port user@ip [alias]     Specify the port
  sshx alias                       Connect to a saved host
  sshx help                        Show this help
  sshx list                        List saved connections
  sshx mv old_alias new_alias      Rename a connection
  sshx rm alias                    Remove a connection
'@ | Write-Host
    }
}

function Get-ConfigState {
    $text = if (Test-Path -LiteralPath $ConfigFile) {
        $bytes = [IO.File]::ReadAllBytes($ConfigFile)
        if (($bytes.Length -ge 2 -and (($bytes[0] -eq 0xff -and $bytes[1] -eq 0xfe) -or ($bytes[0] -eq 0xfe -and $bytes[1] -eq 0xff))) -or
            ($bytes.Length -ge 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xfe -and $bytes[3] -eq 0xff)) {
            throw "The SSH config $ConfigFile must use UTF-8, not UTF-16 or UTF-32. Convert it before continuing."
        }
        [IO.File]::ReadAllText($ConfigFile, $Utf8NoBom)
    } else { '' }
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $beginMatches = [regex]::Matches($text, '(?m)^' + [regex]::Escape($MarkBegin) + '\r?$')
    $endMatches = [regex]::Matches($text, '(?m)^' + [regex]::Escape($MarkEnd) + '\r?$')
    if ($beginMatches.Count -eq 0 -and $endMatches.Count -eq 0) {
        return [pscustomobject]@{ Text = $text; Exists = $false; Before = ''; Body = ''; After = ''; Newline = $newline }
    }
    if ($beginMatches.Count -ne 1 -or $endMatches.Count -ne 1 -or $beginMatches[0].Index -ge $endMatches[0].Index) {
        throw "The sshx markers in $ConfigFile are incomplete or duplicated. Repair them before continuing."
    }
    $bodyStart = $beginMatches[0].Index + $beginMatches[0].Length
    if ($bodyStart -lt $text.Length -and $text[$bodyStart] -eq "`n") { $bodyStart++ }
    $endStart = $endMatches[0].Index
    [pscustomobject]@{
        Text = $text; Exists = $true
        Before = $text.Substring(0, $bodyStart)
        Body = $text.Substring($bodyStart, $endStart - $bodyStart)
        After = $text.Substring($endStart)
        Newline = $newline
    }
}

function Save-ConfigState($State, [string]$Body) {
    if ($State.Exists) {
        $newText = $State.Before + $Body + $State.After
    } else {
        $suffix = if ($State.Text.Length -gt 0) { $State.Newline + $State.Text } else { '' }
        $newText = $MarkBegin + $State.Newline + $Body + $MarkEnd + $State.Newline + $suffix
    }
    New-Item -ItemType Directory -Force -Path $SshDir | Out-Null
    $temporary = Join-Path $SshDir ('.sshx-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = "$temporary.bak"
    try {
        [IO.File]::WriteAllText($temporary, $newText, $Utf8NoBom)
        if (Test-Path -LiteralPath $ConfigFile) {
            [IO.File]::Replace($temporary, $ConfigFile, $backup)
        } else {
            [IO.File]::Move($temporary, $ConfigFile)
        }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
    }
}

function Get-HostRecords($State) {
    $found = [regex]::Matches($State.Body, '(?im)^[ \t]*Host[ \t]+([^\r\n]+)(?:\r?\n|$)')
    for ($i = 0; $i -lt $found.Count; $i++) {
        $start = $found[$i].Index
        $end = if ($i + 1 -lt $found.Count) { $found[$i + 1].Index } else { $State.Body.Length }
        $entry = $State.Body.Substring($start, $end - $start)
        $names = @($found[$i].Groups[1].Value.Trim() -split '[ \t]+' | Where-Object { $_ })
        $aliasName = if ($names.Count -eq 1) { $names[0] } else { $null }
        $hostMatch = [regex]::Match($entry, '(?im)^[ \t]*HostName[ \t]+(\S+)')
        $userMatch = [regex]::Match($entry, '(?im)^[ \t]*User[ \t]+(\S+)')
        $portMatch = [regex]::Match($entry, '(?im)^[ \t]*Port[ \t]+(\S+)')
        [pscustomobject]@{
            Alias = $aliasName; HostName = $hostMatch.Groups[1].Value; User = $userMatch.Groups[1].Value
            Port = if ($portMatch.Success) { $portMatch.Groups[1].Value } else { '22' }
            Start = $start; Length = $end - $start; HeaderLength = $found[$i].Length
        }
    }
}

function Find-ManagedHost($State, [string]$AliasName) {
    Get-HostRecords $State | Where-Object { $_.Alias -eq $AliasName } | Select-Object -First 1
}

function Test-AnyAlias($State, [string]$AliasName) {
    foreach ($match in [regex]::Matches($State.Text, '(?im)^[ \t]*Host[ \t]+([^\r\n]+)')) {
        foreach ($name in ($match.Groups[1].Value -split '[ \t]+')) {
            if ($name.StartsWith('#')) { break }
            if ($name -eq $AliasName) { return $true }
        }
    }
    return $false
}

function Test-OutsideAlias($State, [string]$AliasName) {
    $outside = if ($State.Exists) { $State.Before + $State.After } else { $State.Text }
    Test-AnyAlias ([pscustomobject]@{ Text = $outside }) $AliasName
}

function Assert-Alias([string]$AliasName) {
    if ($AliasName -notmatch '^[A-Za-z0-9_][A-Za-z0-9._-]*$') {
        throw 'Invalid alias. Use letters, digits, underscores, dots, or hyphens; the first character must be a letter, digit, or underscore.'
    }
}

function Remove-Entry($State, [string]$AliasName) {
    $record = Find-ManagedHost $State $AliasName
    if (-not $record) { throw "The sshx alias '$AliasName' was not found." }
    $State.Body = $State.Body.Remove($record.Start, $record.Length)
}

function Add-Entry($State, [string]$AliasName, $Target) {
    $nl = $State.Newline
    if ($State.Body.Length -gt 0 -and -not $State.Body.EndsWith("`n")) { $State.Body += $nl }
    $State.Body += @(
        "Host $AliasName"
        "    HostName $($Target.HostName)"
        "    User $($Target.User)"
        "    Port $($Target.Port)"
        '    IdentityFile ~/.ssh/id_ed25519_sshx'
        '    IdentitiesOnly yes'
        '    ServerAliveInterval 30'
        '    ServerAliveCountMax 3'
        ''
    ) -join $nl
}

function Ensure-Key {
    New-Item -ItemType Directory -Force -Path $SshDir | Out-Null
    if (-not (Test-Path -LiteralPath $KeyFile)) {
        Write-Host '[sshx] Preparing a dedicated SSH key...'
        # Windows PowerShell 5.1 drops empty native arguments unless explicitly quoted.
        $emptyPassphrase = if ($PSVersionTable.PSVersion.Major -lt 7) { '""' } else { '' }
        & ssh-keygen -q -t ed25519 -f $KeyFile -C sshx-key -N $emptyPassphrase
        if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed.' }
    }
    if (-not (Test-Path -LiteralPath "$KeyFile.pub")) {
        throw "The public key $KeyFile.pub is missing. Restore it or move the incomplete key pair aside."
    }
}

function Install-PublicKey($Target) {
    $key = ([IO.File]::ReadAllText("$KeyFile.pub")).Trim()
    if ($key -notmatch '^[^\r\n]+$') { throw 'The public key is empty or contains multiple lines.' }
    $quote = [string][char]39
    $quotedKey = $quote + $key.Replace($quote, $quote + '\' + $quote + $quote) + $quote
    $remote = "umask 077 && mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && (grep -qxF $quotedKey ~/.ssh/authorized_keys || printf '%s\n' $quotedKey >> ~/.ssh/authorized_keys)"
    & ssh -p $Target.Port "$($Target.User)@$($Target.HostName)" $remote | Out-Host
    return ($LASTEXITCODE -eq 0)
}

function Parse-Target([string]$Target, [string]$PortOverride) {
    $parts = $Target -split '@', 2
    if ($parts.Count -eq 2) {
        $userName, $hostPart = $parts
    } else {
        $userName = if ($env:USERNAME) { $env:USERNAME } else { [Environment]::UserName }
        $hostPart = $parts[0]
    }
    $hostParts = $hostPart -split ':', 2
    $hostName = $hostParts[0]
    $port = if ($hostParts.Count -eq 2) { $hostParts[1] } else { '22' }
    if ($PortOverride) { $port = $PortOverride }
    $portNumber = 0
    if ($userName -notmatch '^[A-Za-z0-9_][A-Za-z0-9._-]*\$?$' -or
        $hostName -notmatch '^[A-Za-z0-9_][A-Za-z0-9._-]*$' -or
        $port -notmatch '^\d{1,5}$' -or -not [int]::TryParse($port, [ref]$portNumber) -or $portNumber -lt 1 -or $portNumber -gt 65535) {
        throw 'Invalid user, host, or port. Use a hostname or IPv4 address and a port from 1 to 65535.'
    }
    [pscustomobject]@{ User = $userName; HostName = $hostName; Port = [string]$portNumber }
}

function Connect-Alias([string]$AliasName) {
    if (-not $AliasName -or $AliasName.StartsWith('-')) { throw 'Invalid SSH alias.' }
    Write-Host '[sshx] Opening connection...'
    & ssh $AliasName
    exit $LASTEXITCODE
}

function Setup-AndConnect([string]$TargetText, [string]$AliasName, [string]$PortOverride) {
    $target = Parse-Target $TargetText $PortOverride
    $providedAlias = -not [string]::IsNullOrWhiteSpace($AliasName)
    if (-not $providedAlias) {
        $safeHost = $target.HostName -replace '[.:]', '-'
        $AliasName = if ($target.Port -eq '22') { "$($target.User)-$safeHost" } else { "$($target.User)-$safeHost-$($target.Port)" }
    }
    Assert-Alias $AliasName
    $state = Get-ConfigState
    $existing = Get-HostRecords $state | Where-Object { $_.User -eq $target.User -and $_.HostName -eq $target.HostName -and $_.Port -eq $target.Port -and $_.Alias } | Select-Object -First 1
    if ($existing -and ($existing.Alias -eq $AliasName -or -not $providedAlias)) {
        if (Test-OutsideAlias $state $existing.Alias) { throw "Alias '$($existing.Alias)' is also used outside the sshx-managed block." }
        Connect-Alias $existing.Alias
    }
    $old = Find-ManagedHost $state $AliasName
    if (Test-OutsideAlias $state $AliasName) { throw "Alias '$AliasName' is already used outside the sshx-managed block." }
    if ($old) {
        $answer = Read-Host "[sshx] Alias '$AliasName' exists. Overwrite it? [y/N]"
        if ($answer -notmatch '^(y|yes)$') { throw 'Cancelled; the existing alias was kept.' }
    }
    if (-not $existing) {
        Ensure-Key
        Write-Host "[sshx] Preparing $($target.User)@$($target.HostName); enter the remote password if requested."
        if (-not (Install-PublicKey $target)) { throw 'Could not install the public key. Check the address, credentials, and network.' }
    }
    if ($old) { Remove-Entry $state $AliasName }
    if ($existing -and $existing.Alias -ne $AliasName) { Remove-Entry $state $existing.Alias }
    Add-Entry $state $AliasName $target
    Save-ConfigState $state $state.Body
    Write-Host "[sshx] Saved connection: $AliasName"
    Connect-Alias $AliasName
}

try {
    if ($Arguments.Count -eq 0) { Show-Usage; exit 1 }
    if ($Arguments[0] -eq '-p') {
        if ($Arguments.Count -lt 3 -or $Arguments.Count -gt 4) { throw 'Usage: sshx -p port user@host [alias]' }
        $aliasName = if ($Arguments.Count -eq 4) { $Arguments[3] } else { '' }
        Setup-AndConnect $Arguments[2] $aliasName $Arguments[1]
    } else {
        switch ($Arguments[0]) {
            'help' { if ($Arguments.Count -ne 1) { throw 'Usage: sshx help' }; Show-Usage }
            'list' {
                if ($Arguments.Count -ne 1) { throw 'Usage: sshx list' }
                Write-Host 'sshx hosts:'
                Get-HostRecords (Get-ConfigState) | Where-Object { $_.Alias } | Sort-Object Alias | ForEach-Object { "  {0,-24} {1}@{2}:{3}" -f $_.Alias, $_.User, $_.HostName, $_.Port }
            }
            'rm' {
                if ($Arguments.Count -ne 2) { throw 'Usage: sshx rm alias' }
                $state = Get-ConfigState
                Remove-Entry $state $Arguments[1]
                Save-ConfigState $state $state.Body
                Write-Host "[sshx] Removed alias: $($Arguments[1])"
            }
            'mv' {
                if ($Arguments.Count -ne 3) { throw 'Usage: sshx mv old_alias new_alias' }
                Assert-Alias $Arguments[2]
                $state = Get-ConfigState
                $record = Find-ManagedHost $state $Arguments[1]
                if (-not $record) { throw "The sshx alias '$($Arguments[1])' was not found." }
                if ($record.Alias -eq $Arguments[2]) { break }
                if (Test-AnyAlias $state $Arguments[2]) { throw "Alias '$($Arguments[2])' is already in use." }
                $header = $state.Body.Substring($record.Start, $record.HeaderLength)
                $newHeader = [regex]::Replace($header, '(?i)(Host[ \t]+)\S+', ('$1' + $Arguments[2]))
                $state.Body = $state.Body.Substring(0, $record.Start) + $newHeader + $state.Body.Substring($record.Start + $record.HeaderLength)
                Save-ConfigState $state $state.Body
                Write-Host "[sshx] Renamed $($Arguments[1]) to $($Arguments[2])"
            }
            default {
                if ($Arguments.Count -gt 2) { throw 'Usage: sshx user@host [alias]' }
                if ($Arguments.Count -eq 1 -and $Arguments[0].Contains('.')) {
                    $state = Get-ConfigState
                    if (Find-ManagedHost $state $Arguments[0]) { Connect-Alias $Arguments[0] }
                }
                if ($Arguments[0].Contains('@') -or $Arguments[0].Contains('.')) {
                    $aliasName = if ($Arguments.Count -eq 2) { $Arguments[1] } else { '' }
                    Setup-AndConnect $Arguments[0] $aliasName ''
                } elseif ($Arguments.Count -eq 1) { Connect-Alias $Arguments[0] }
                else { throw 'Use user@host when specifying an alias for a host without a dot.' }
            }
        }
    }
} catch {
    [Console]::Error.WriteLine('[sshx] ' + $_.Exception.Message)
    exit 1
}
