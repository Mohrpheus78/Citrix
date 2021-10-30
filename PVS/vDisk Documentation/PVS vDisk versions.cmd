REM ********************************************
REM Skript Launcher for PVS vDisk versions .ps1) 
REM Dennis Mohrmann <@mohrpheus78>
REM ********************************************

@ECHO OFF
CLS
%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -WindowStyle Maximized -NoLogo -ExecutionPolicy ByPass -File "%~dp0PVS vDisk versions.ps1" -outputpath "C:\Program Files (x86)\Scripts\vDisk Documentation"
pause

