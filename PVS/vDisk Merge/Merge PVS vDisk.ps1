﻿<#
.SYNOPSIS
This script will merge a PVS vDisk you choose
	
.DESCRIPTION
The purpose of the script is to merge vDisk versions to a merged base and promote the new base to production. After that the vDisk will be replicated to all other PVS servers in 
the site that hosts this vDisk
   
.PARAMETER
No parameters required

.EXAMPLE
& '.\Merge PVS vDisk.ps1'

.NOTES

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-16
Purpose/Change:	
2021-10-16		Inital version
2021-10-26		changes to menu
2021-10-27		changed description
#>

# Variables
$FolderBack = Split-Path -Path $PSScriptRoot
$Date = Get-Date -UFormat "%d.%m.%Y"
$Log = "$PSScriptRoot\Merge PVS vDisks-$Date.log"

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

# Do you run the script as admin?
# ========================================================================================================================================
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

if ($myWindowsPrincipal.IsInRole($adminRole))
   {
    # OK, runs as admin
    Write-Verbose "OK, script is running with Admin rights" -Verbose
    Write-Output ""
   }

else
   {
    # Script doesn't run as admin, stop!
    Write-Verbose "Error! Script is NOT running with Admin rights!" -Verbose
    BREAK
   }
# ========================================================================================================================================

Write-Host -ForegroundColor Yellow "Merge PVS vDisk" `n

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
$vDisk = Read-Host -Prompt 'Select vDisk to merge'

$vDisk = $AllvDisks | Where-Object {$_.ID -eq $vDisk}
if ($vDisk.ID -notin $ValidChoices) {
    Write-Host -ForegroundColor Red "Selected vDisk not found, aborting!"
    BREAK
    }

$vDiskName = $vDisk.Name
$StoreName = $vDisk.StoreName

# Merge selected vDisk if possible
$CanMerge = ((Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName) | Select -First 1 | Where-Object {$_.CanMerge -eq 'False'})
if (-not($CanMerge)) {
    Write-Host -ForegroundColor Red "Current vDisk version is a merged base or in private mode, aborting!"
    BREAK
    }

else {
    Merge-PvsDisk -DiskLocatorName "$vDiskName" -StoreName "$StoreName" -SiteName "$SiteName" -NewBase
    }

# Wait until merging is finished
Do {
    Write-Host -ForegroundColor Green "Merging, please wait..."
    $MergeTask = (Get-PvsTask | select -Last 1).State
    Start-Sleep 8
    }
Until ($MergeTask -eq 2)

# Promote vDisk to production
Invoke-PvsPromoteDiskVersion -DiskLocatorName "$vDiskName" -StoreName "$StoreName" -SiteName "$SiteName"

# Get version number of base
$LastVersion = (Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName).Version | select -First 1

# Enter description "Merged Base" into merged base disk 
Set-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName -Version $LastVersion -Description "Merged Base"

# Export vDisk (XML file)
Export-PvsDisk -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName -EA SilentlyContinue

# Replicate vDisk to all PVS server in store
$title = "Replicate vDisks"
$message = "Do you want to replicate the merged base diskt?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)

switch ($choice) {
    0 {
      $answer = 'Yes'       
      }
    1 {
      $answer = 'No'
      }
}

if ($answer -eq 'Yes') {
     $AllPVSServer = Get-PvsServer -StoreName $StoreName -SiteName $SiteName | Select-Object ServerName
     foreach ($PVSServer in $AllPVSServer | Where-Object {$_.ServerName -ne "$env:COMPUTERNAME"}) {
         $LocalStorePath  = (Get-PvsStore -StoreName "$StoreName").Path
         $RemoteStorePath = $LocalStorePath -replace (":","$")
         $PVSServer = $PVSServer.ServerName
         robocopy.exe "$LocalStorePath" "\\$PVSServer\$RemoteStorePath" /COPYALL /XD WriteCache /XF *.lok /ETA /SEC  
         }

# Check Replication state
Get-PvsDiskVersion -Name $vDiskName -SiteName $SiteName -StoreName $StoreName | Where-Object {$_.GoodInventoryStatus -eq $true} | Sort-Object -Property Version | ForEach-Object {write-host -foregroundcolor Green ("Version: " + $_.Version + " Replication state: " + $_.GoodInventoryStatus)}
Get-PvsDiskVersion -Name $vDiskName -SiteName $SiteName -StoreName $StoreName | Where-Object {$_.GoodInventoryStatus -eq $false} | Sort-Object -Property Version | ForEach-Object {write-host -foregroundcolor Red ("Version: " + $_.Version + " Replication state: " + $_.GoodInventoryStatus)}
}

# Create HTML Report
$title = "Create Report"
$message = "Do you want to create a HTML report?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)

switch ($choice)
    {
    0 {
       $answer = 'Yes'       
      }
    1 {
       $answer = 'No'
      }
    }

if ($answer -eq 'Yes')
{
    & "$FolderBack\vDisk Documentation\PVS vDisk versions.ps1" -outputpath "$ENV:USERPROFILE\Desktop"
}

Write-Host -ForegroundColor Green "Ready! Merged base version is version $LastVersion" `n

$ScriptEnd = Get-Date
$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds"

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log