REM ****************************************
REM Skript zum Exportieren der vDisks (XML) 
REM Dennis Mohrmann, S&L
REM ****************************************

CLS
@ECHO OFF
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0Export PVS vDisk.ps1'"
