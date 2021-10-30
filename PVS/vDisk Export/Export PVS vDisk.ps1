<#
.SYNOPSIS
This script will generate a XML export of your vDisk in the same folder.
	
.DESCRIPTION
The purpose of the script is to generate y XML backup file to be able to recreate a vDisk chain if you restore vDisk versions

.EXAMPLE
& '.\Export PVS vDisk.ps1' or use the shortcut

.NOTES
#>

# Variables
$Date = Get-Date -UFormat "%d.%m.%Y"
$Log = "$PSScriptRoot\Export PVS vDisks-$Date.log"

# Start logging
Start-Transcript $Log | Out-Null

# PVS Powershell SnapIn laden
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
try { Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop }
catch { write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
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

Write-Host -Foregroundcolor Yellow "vDisk export running..."

# Get PVS site
$SiteName = (Get-PvsSite).SiteName

# Get all vDisks and stores
$AllvDisks = @(Get-PvsDiskInfo -SiteName $SiteName | Select-Object -Property Name, Storename)

# Export (XML) all vDisks
foreach ($vdisk in $AllvDisks) {
Export-PvsDisk -DiskLocatorName $AllvDisks.Name -SiteName $SiteName -StoreName $AllvDisks.Storename }

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log