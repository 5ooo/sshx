function Get-SshxCompletions([string]$Word) {
    $config = Join-Path (Join-Path $HOME '.ssh') 'config'
    $aliases = if (Test-Path -LiteralPath $config) {
        $inside = $false
        foreach ($line in Get-Content -LiteralPath $config -Encoding UTF8) {
            if ($line -eq '# >>> sshx hosts >>>') { $inside = $true; continue }
            if ($line -eq '# <<< sshx hosts <<<') { break }
            if ($inside -and $line -match '^\s*Host\s+(\S+)\s*$') { $Matches[1] }
        }
    }
    @('help', 'list', 'rm', 'mv', '-p') + @($aliases) | Sort-Object -Unique |
        Where-Object { $_.StartsWith($Word, [StringComparison]::OrdinalIgnoreCase) } |
        ForEach-Object { New-Object System.Management.Automation.CompletionResult($_, $_, 'ParameterValue', $_) }
}
Register-ArgumentCompleter -CommandName sshx -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    Get-SshxCompletions $wordToComplete
}
Register-ArgumentCompleter -Native -CommandName sshx, sshx.cmd -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    Get-SshxCompletions $wordToComplete
}
