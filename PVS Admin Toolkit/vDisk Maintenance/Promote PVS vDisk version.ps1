<#
.SYNOPSIS
This script will create a new PVS maintenance version from the vDisk you choose.
	
.DESCRIPTION
The purpose of the script is to create a new vDisk version from a list of available vDisk in your site.


.EXAMPLE
& '.\New PVS vDisk versionn.ps1' or use shortcut

.NOTES
If you want to change the root folder you have to modify the shortcut.

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-16
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
$RootFolder = Split-Path -Path $PSScriptRoot
$Date = Get-Date -UFormat "%d.%m.%Y"
$Log = "$RootFolder\Logs\Promote PVS vDisk version.log"

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
Write-Host -ForegroundColor Yellow "Promote vDisk version" `n

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

# vDisk in maintenance mode?
$CanPromote = ((Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName) | Select-Object -First 1).CanPromote
if (-not($CanPromote)) {
    Write-Host -ForegroundColor Red "Selected vDisk version is not in maintenance mode, aborting!"
	Read-Host "Press any key to exit"
    BREAK
    }

# Get maintenance version
$MaintVersion = (Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName | Where-Object {$_.CanPromote -eq 'True'}).Version
Write-Host `n

# Production or test mode?
$title = ""
$message = "Do you want to promote to production or test mode?"
$Prod = New-Object System.Management.Automation.Host.ChoiceDescription "&P"
$Test = New-Object System.Management.Automation.Host.ChoiceDescription "&T"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($Prod, $Test)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)

switch ($choice) {
    0 {
      $answer = 'P'       
      }
    1 {
      $answer = 'T'
      }
}
if ($answer -eq 'P') {
    Invoke-PvsPromoteDiskVersion -DiskLocatorName $vDiskName -StoreName $StoreName -SiteName $SiteName
    }
else {
    Invoke-PvsPromoteDiskVersion -DiskLocatorName $vDiskName -StoreName $StoreName -SiteName $SiteName -Test
    }

# Description
Write-Host -ForegroundColor Yellow `n"Please enter a description for the new vDisk version and hit enter"`n
$Description =  Read-Host
Set-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName -Version $MaintVersion -Description "$Description"

Write-Host -ForegroundColor Green `n"vDisk successfully promoted to version '$MaintVersion' with description '$Description', check logfile"`n

# Replicate vDisk to all PVS server in store
$title = ""
$message = "Do you want to replicate the new vDisk version?"
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

# Stop Logging
$ScriptEnd = Get-Date
$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds"

Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log
Copy-Item -Path $Log -Destination "$RootFolder\Logs\Promote PVS vDisk version-$vDiskName-$Date.log" -force
Remove-Item $Log -force

Read-Host "Press any key to exit"