<#
.SYNOPSIS
This script will configure Evergreen for installing software and updates inside a PVS vDisk
	
.DESCRIPTION
The purpose of the script is to configure the famous Evergreen script from Manuel Winkel (@deyda) to be used with the PVS Admin Toolkit

.NOTES

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-17
Purpose/Change:	
#>

# Variables
$EvergreenConfig = "$PSScriptRoot\Evergreen.xml"
$EvergreenSelection = New-Object PSObject

Write-Host "======== Evergreen configuration ========"
Write-Host `n

Write-Host "You need a share where we can find the Evergreen script!"
Write-Host `n
$EvergreenShare = Read-Host "Enter a valid UNC path for the Evergreen Powershell script (\\server\share)"
IF (!(Test-Path -Path "$EvergreenShare\Evergreen-Software Installer.ps1")) {
	Write-Host -ForegroundColor Red "Error, Evergreen.ps1 script not found! Check UNC path and run script again!"
	Read-Host "Press ENTER to exit"
	BREAK
}
Add-member -inputobject $EvergreenSelection -MemberType NoteProperty -Name "EvergreenShare" -Value $EvergreenShare -Force
$EvergreenSelection | Export-Clixml $EvergreenConfig