@echo off
setlocal EnableExtensions

set "SCRIPT_PATH=%~dp0src\ChallengeTokenRemover.ps1"
title Challenge Token Remover

if not exist "%SCRIPT_PATH%" (
    echo [ERROR] The PowerShell script was not found:
    echo         "%SCRIPT_PATH%"
    echo.
    pause
    exit /b 2
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -NoPause
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
    echo The operation did not complete successfully. Exit code: %EXIT_CODE%
)
pause
exit /b %EXIT_CODE%
