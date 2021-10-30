REM *************************************************
REM Launcher for the Shrink PVS vDisk.ps1 script
REM Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
REM Defrag and shrink PVS vDisks
REM *************************************************

@ECHO OFF
CLS
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Maximized -NoLogo -ExecutionPolicy ByPass -File "%~dp0Shrink PVS vDisk.ps1"
