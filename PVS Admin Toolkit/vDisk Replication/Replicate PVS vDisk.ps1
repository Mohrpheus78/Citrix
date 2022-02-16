<#
.SYNOPSIS
This script will replicate a PVS vDisk you choose from your PVS site.
	
.DESCRIPTION
The purpose of the script is to replicate vDisk versions to all other PVS servers in the site that hosts this vDisk

.EXAMPLE
& '.\Replicate PVS vDisk.ps1' or use shortcut.

.NOTES
If you want to change the root folder you have to modify the shortcut.

.NOTES
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-27
Purpose/Change:	
2021-10-27		Inital version
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
$Log = "$RootFolder\Replicate PVS vDisks.log"

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

# Replicate vDisks
Write-Host -ForegroundColor Yellow "Replicate PVS vDisk" `n

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
$vDisk = Read-Host -Prompt 'Select vDisk to replicate'

$vDisk = $AllvDisks | Where-Object {$_.ID -eq $vDisk}
if ($vDisk.ID -notin $ValidChoices) {
    Write-Host -ForegroundColor Red "Selected vDisk not found, aborting!"
	Read-Host "Press any key to exit"
    BREAK
    }

# Get vDisk name and store
$vDiskName = $vDisk.Name
$StoreName = $vDisk.StoreName

# Check if vDisk is already replicated
$Replication = @(Get-PvsDiskVersion -Name $vDiskName -SiteName $SiteName -StoreName $StoreName | Select-Object -Property GoodInventoryStatus)
if ($Replication -match "False") {

# Export vDisk (XML file)
Export-PvsDisk -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName -EA SilentlyContinue

# Replicate vDisk to all PVS server in store
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

Write-Host -ForegroundColor Green `n"Ready! vDisk $vDiskName replicated" `n
}

else {
    Write-Host -ForegroundColor Green "All vDisk versions replicated, no replication needed!"
    }

$ScriptEnd = Get-Date
$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds"

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log
Move-Item $Log "Replicate PVS vDisks-$vDiskName-$Date.log" -force

Read-Host `n "Press any key to exit"



