<#
.SYNOPSIS
This script will launch the "New PVS vDisk script", start the master and launch the Windows Update script to automatically install all avaialable windows updates on a device and will automatically reboot if needed.
After reboot Windows updates will continue to run until no more updates are available.

.DESCRIPTION
The purpose of the script is to launch the Windows Update script

.NOTES

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-06
Purpose/Change:	
2022-02-06		Inital version
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
$Log = "$RootFolder\Logs\Start Windows Updates.log"
$WindowsUpdates = "Yes"

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
Write-Host -ForegroundColor Yellow "Installing Windows Updates into a maintenance version" `n
."$PSScriptRoot\New PVS vDisk version.ps1"

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log
Copy-Item -Path $Log -Destination "$RootFolder\Windows Updates-$MaintDeviceName-$Date.log" -force
Remove-Item $Log -Force