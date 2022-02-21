<#
.SYNOPSIS
This script will automatically install all avaialable windows updates on a device and will automatically reboot if needed, after reboot,
windows updates will continue to run until no more updates are available.

.DESCRIPTION
The purpose of the script is to remotely install Windows Updates


.NOTES

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-11-11
Purpose/Change:	
2021-11-11		Inital version
#>


# Variables
$Date = Get-Date -UFormat "%d.%m.%Y"
#IF (!(Test-Path -Path "D:\Logs\Windows Update")) {New-Item -Path "D:\Logs" -Name "Windows Update" -ItemType Directory}
#$WULogPath = "D:\Logs\Windows Update"
$RootFolder = Split-Path -Path $PSScriptRoot
$Log = "$RootFolder\Logs\Application Update.log"

# Start logging
Start-Transcript $Log | Out-Null


   #Reset Timeouts
	$ConnectionTimeout = 0
	$UpdateTimeout = 0
     
	#Starts up a remote powershell session to the computer
	Do {
		$session = New-PSSession -ComputerName $MaintDeviceName
		Write-Host "Reconnecting to $MaintDeviceName" `n
		sleep -seconds 10
		$connectiontimeout++
	} Until ($session.state -match "Opened" -or $connectiontimeout -ge 10)

#Start Updater with task
Write-Host -ForegroundColor Yellow "Starting Updater" `n
$UpdateTask = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Get-ScheduledTask -TaskName "SuL-Updater" -ErrorAction SilentlyContinue}
IF ($UpdateTask -eq $Null) {
	copy-item "C:\Program Files (x86)\Scripts\vDisk Maintenance\SuL-Updater.xml" "\\$MaintDeviceName\admin$\Temp" 
	invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Register-ScheduledTask -Xml (Get-Content "C:\Windows\Temp\SuL-Updater.xml" | out-string) -TaskName "SuL-Updater"}
	}
Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Start-ScheduledTask -TaskName "SuL-Updater"}

Write-Host -ForegroundColor Green "Updates installed"

#Start BIS-F with task
IF (Test-Path -Path "\\$MaintDeviceName\admin$\Temp") {
	copy-item "C:\Program Files (x86)\Scripts\vDisk Maintenance\BIS-F.xml" "\\$MaintDeviceName\admin$\Temp"
	Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Register-ScheduledTask -Xml (Get-Content "C:\Windows\Temp\BIS-F.xml" | out-string) -TaskName "BIS-F"}
}

Write-Host -ForegroundColor Yellow "Starting BIS-F to seal the image"
Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Start-ScheduledTask -TaskName BIS-F}

#Promote vDisk to Test
Do {
	$CanShutdown = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {(Get-ScheduledTask -TaskName BIS-F)}
    $BISFLog = (Get-ChildItem -Path '\\vda-master-2022\d$\BISFLogs' | Select -Last 1).Name
    Get-Content \\$MaintDeviceName\D$\BISFLogs\$BISFLog | select-object -last 1
    sleep -seconds 1
   } Until
	($CanShutdown.State -eq "Ready")
	
#Promote vDisk to Test
sleep -seconds 60
Invoke-PvsPromoteDiskVersion -DiskLocatorName $MaintVersion -StoreName $StoreName -SiteName $SiteName -Test
Set-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName -Version $MaintVersion -Description "Windows Updates"

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log


