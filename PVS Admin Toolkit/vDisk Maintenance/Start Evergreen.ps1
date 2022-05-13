<#
.SYNOPSIS
This script will launch the "New PVS vDisk script", start the master and execute the Evergreen software update script to install software updates inside the a new vDisk version

.DESCRIPTION
The purpose of the script is to launch other scripts to execute Evergreen inside a new vDisk version


.NOTES
The variables have to be present in the XML files, configure Evergreen with the configuration menu first!

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-06
Purpose/Change:	
2022-02-17		Inital version
#>

param
    (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$vDiskName,
		
		[Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$StoreName,
		
		[Parameter(Mandatory = $false)]
        [switch]$Task
	)
	

# Variables
$Date = Get-Date -UFormat "%d.%m.%Y"
$RootFolder = Split-Path -Path $PSScriptRoot
$Log = "$RootFolder\Logs\Start Evergreen.log"
$Evergreen = "True"

# Start logging
Start-Transcript $Log | Out-Null

# RunAs Admin
function Use-RunAs 
{    
    # Check if script is running as Administrator and if not elevate it
    # Use Check Switch to check if admin 
     
    param([Switch]$Check) 
     
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()` 
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
         
    if ($Check) { return $IsAdmin }   
      
    if ($MyInvocation.ScriptName -ne "") 
    {  
        if (-not $IsAdmin)  
          {  
            try 
            {  
                $arg = "-WindowStyle Maximized -file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop'  
            } 
            catch 
            { 
                Write-Warning "Error - Failed to restart script elevated"  
                BREAK               
            } 
            exit 
        }  
    }  
} 

Use-RunAs

# Launch script
Write-Host -ForegroundColor Yellow "Executing Evergreen script inside a maintenance version" `n
."$PSScriptRoot\New PVS vDisk version.ps1"

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log
Rename-Item -Path $Log -NewName "Start-Evergreen-$Date.log"