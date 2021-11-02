<#
.SYNOPSIS
This script will generate a XML export of your vDisk in the same folder.
	
.DESCRIPTION
The purpose of the script is to generate y XML backup file to be able to recreate a vDisk chain if you restore vDisk versions

.EXAMPLE
& '.\Export PVS vDisk.ps1' or use the shortcut

.NOTES
If you want to change the root folder you have to modify the shortcut.  

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
2021-11-01		added RunAs Admin function
2021-11-02		Changed log path and notes
#>


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
                break               
            } 
            exit 
        }  
    }  
} 

Use-RunAs

# Variables
$FolderBack = Split-Path -Path $PSScriptRoot
$Date = Get-Date -UFormat "%d.%m.%Y"
$Log = "$FolderBack\Logs\Export PVS vDisks-$Date.log"

# Start logging
Start-Transcript $Log | Out-Null

# PVS Powershell SnapIn laden
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
try { Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop }
catch { write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
}

Write-Host -Foregroundcolor Yellow "vDisk export running..."

# Get PVS site
$SiteName = (Get-PvsSite).SiteName

# Get all vDisks and stores
$AllvDisks = @(Get-PvsDiskInfo -SiteName $SiteName | Select-Object -Property Name, Storename)

# Export (XML) all vDisks
foreach ($vdisk in $AllvDisks) {
	Export-PvsDisk -DiskLocatorName $AllvDisks.Name -SiteName $SiteName -StoreName $AllvDisks.Storename
	}
Write-Host -Foregroundcolor Green "ready, check logfile $log"

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log

Read-Host `n "Press any key to exit"
