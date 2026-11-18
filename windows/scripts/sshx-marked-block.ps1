# Edit marked blocks without re-encoding unrelated profile or SSH configuration bytes.
function Set-SshxMarkedBlock {
    param([string]$Path, [string]$Begin, [string]$End, [string]$Content, [switch]$Remove)

    if (-not [IO.File]::Exists($Path) -and $Remove) { return }
    [byte[]]$bytes = @()
    if ([IO.File]::Exists($Path)) { $bytes = [IO.File]::ReadAllBytes($Path) }
    $offset = 0
    $encoding = [Text.Encoding]::GetEncoding(28591)
    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0xff -and $bytes[1] -eq 0xfe -and $bytes[2] -eq 0 -and $bytes[3] -eq 0) {
        $encoding = New-Object Text.UTF32Encoding($false, $false, $true); $offset = 4
    } elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0 -and $bytes[1] -eq 0 -and $bytes[2] -eq 0xfe -and $bytes[3] -eq 0xff) {
        $encoding = New-Object Text.UTF32Encoding($true, $false, $true); $offset = 4
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xff -and $bytes[1] -eq 0xfe) {
        $encoding = New-Object Text.UnicodeEncoding($false, $false, $true); $offset = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xfe -and $bytes[1] -eq 0xff) {
        $encoding = New-Object Text.UnicodeEncoding($true, $false, $true); $offset = 2
    }
    $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    $starts = [regex]::Matches($text, '(?m)^' + [regex]::Escape($Begin) + '\r?$')
    $ends = [regex]::Matches($text, '(?m)^' + [regex]::Escape($End) + '\r?$')
    if ($starts.Count -ne $ends.Count -or $starts.Count -gt 1 -or ($starts.Count -eq 1 -and $starts[0].Index -ge $ends[0].Index)) {
        throw "The sshx markers in $Path are incomplete or duplicated. Repair them before continuing."
    }
    if ($Remove -and $starts.Count -eq 0) { return }
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { [Environment]::NewLine }
    if ($starts.Count -eq 1) {
        $blockEnd = $ends[0].Index + $ends[0].Length
        if ($blockEnd -lt $text.Length -and $text[$blockEnd] -eq "`n") { $blockEnd++ }
        $before = $text.Substring(0, $starts[0].Index)
        $after = $text.Substring($blockEnd)
    } else {
        $before = $text
        if ($before.Length -gt 0 -and -not $before.EndsWith("`n")) { $before += $nl }
        $after = ''
    }
    $insert = if ($Remove) { '' } else { $Begin + $nl + $Content.Replace("`r`n", "`n").Replace("`n", $nl).TrimEnd("`r", "`n") + $nl + $End + $nl }
    $newBytes = $encoding.GetBytes($before + $insert + $after)
    $output = New-Object byte[] ($offset + $newBytes.Length)
    if ($offset -gt 0) { [Array]::Copy($bytes, 0, $output, 0, $offset) }
    [Array]::Copy($newBytes, 0, $output, $offset, $newBytes.Length)
    $directory = [IO.Path]::GetDirectoryName($Path)
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporary = Join-Path $directory ('.sshx-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = "$temporary.bak"
    try {
        [IO.File]::WriteAllBytes($temporary, $output)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, $backup) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        if ([IO.File]::Exists($backup)) { [IO.File]::Delete($backup) }
    }
}
