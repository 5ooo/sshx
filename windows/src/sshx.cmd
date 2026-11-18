@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0sshx-main.ps1" %*
exit /b %ERRORLEVEL%
