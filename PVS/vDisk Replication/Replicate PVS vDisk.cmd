REM ****************************************************
REM Skript zum Kopieren der vDisk auf weitere PVS Server
REM Dennis Mohrmann, S&L
REM ****************************************************

@ECHO OFF
CLS
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Maximized -NoLogo -ExecutionPolicy ByPass -File "%~dp0Replicate PVS vDisk.ps1"
pause