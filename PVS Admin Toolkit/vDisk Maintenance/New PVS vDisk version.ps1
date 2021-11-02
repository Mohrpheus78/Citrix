<#
.SYNOPSIS
This script will create a new PVS maintenance version from the vDisk you choose.
	
.DESCRIPTION
The purpose of the script is to create a new vDisk version from a list of available vDisk in your site.


.EXAMPLE
& '.\New PVS vDisk versionn.ps1' or use shortcut

.NOTES
If you want to change the root folder you have to modify the shortcut.

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-16
Purpose/Change:	
2021-10-16		Inital version
2021-10-26		changes to menu
2021-10-27		changed description

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
$Log = "$FolderBack\Logs\New PVS vDisk version-$Date.log"

# Start logging
Start-Transcript $Log | Out-Null

$ScriptStart = Get-Date

# Check if PVS SnapIn is available
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
	}

# Merge vDisks
Write-Host -ForegroundColor Yellow "New vDisk version" `n

# Get PVS SiteName
$SiteName = (Get-PvsSite).SiteName

# Get all vDisks
$AllvDisks = Get-PvsDiskInfo -SiteName $SiteName

# Add property "ID" to object
$ID = 1
$AllvDisks | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name "ID" -Value $ID 
    $ID += 1
    }

# Show menu to select vDisk
Write-Host "Available vDisks:" `n 
$ValidChoices = 1..($AllvDisks.Count)
$Menu = $AllvDisks | ForEach-Object {(($_.ID).toString() + "." + " " +  $_.Name + " " + "-" + " " + "Storename:" + " " + $_.Storename)}
$Menu | Out-Host
Write-Host
$vDisk = Read-Host -Prompt 'Select vDisk'

$vDisk = $AllvDisks | Where-Object {$_.ID -eq $vDisk}
if ($vDisk.ID -notin $ValidChoices) {
    Write-Host -ForegroundColor Red "Selected vDisk not found, aborting!"
	Read-Host "Press any key to exit"
    BREAK
    }

$vDiskName = $vDisk.Name
$StoreName = $vDisk.StoreName

# Create new vDisk version if possible
$CanPromote = ((Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName) | Select-Object -First 1).CanPromote
if ($CanPromote) {
    Write-Host -ForegroundColor Red "Current vDisk version is alreadey a in maintenance mode, aborting!"
	Read-Host "Press any key to exit"
    BREAK
    }

# New maintenance version
New-PvsDiskMaintenanceVersion -DiskLocatorName $vDiskName -StoreName $StoreName -SiteName $SiteName | Out-Null
$MaintVersion = (Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName | Select-Object -First 1).Version
Write-Host -ForegroundColor Green `n"New Version '$MaintVersion' successfully created, check logfile $log"`n

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log

Read-Host "Press any key to exit"