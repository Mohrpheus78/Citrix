REM ***********************************************************
REM Skript zum Erstellen einen HTML Reports der vDisk Versionen
REM Dennis Mohrmann, S&L
REM ***********************************************************

@ECHO OFF
CLS
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Maximized -NoLogo -ExecutionPolicy ByPass -File "%~dp0PVS vDisk versions.ps1" -outputpath "C:\Program Files (x86)\SuL\Scripts\vDisk Documentation"
pause

