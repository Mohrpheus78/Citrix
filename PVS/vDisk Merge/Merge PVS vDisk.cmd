REM ****************************
REM Skript zum Mergen der vDisks 
REM Dennis Mohrmann, S&L
REM ****************************

@ECHO OFF
CLS
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Maximized -NoLogo -ExecutionPolicy ByPass -File "%~dp0Merge PVS vDisk.ps1"
pause

