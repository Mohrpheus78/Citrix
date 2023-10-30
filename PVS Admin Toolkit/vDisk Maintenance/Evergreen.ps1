<#
.SYNOPSIS
This script will automatically install all avaialable software updates on a device with the help of the Evergreen scripot from Manuel Winkkel (@deyda). The server will automatically reboot if needed, after reboot
BIS-F will be launched to seal the image if you want. At the end the new vDisk will be promoted to test. 

.DESCRIPTION
The purpose of the script is to remotely install software updates with the Evergreen script. 
IMPORTANT: You have to create a list with the software components you want to install. Launch Evergreen, make a selection and save. Rename the saved file as "NAME_OF_MASTER-Install.txt"

.NOTES
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-17
#>

# Variables
$Date = Get-Date -UFormat "%d.%m.%Y"
$RootFolder = Split-Path -Path $PSScriptRoot
$HypervisorConfig = Import-Clixml "$RootFolder\Hypervisor\Hypervisor.xml"
$Hypervisor = $HypervisorConfig.Hypervisor
$PVSConfig = Import-Clixml "$RootFolder\PVS\PVS.xml"
$BISF = $PVSConfig.BISF
$EvergreenConfig = Import-Clixml "$RootFolder\Evergreen\Evergreen.xml"
$EvergreenShare = $EvergreenConfig.EvergreenShare

# Check free space on drive C:
$FreeSize = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
		(Get-Volume -DriveLetter C) | ForEach-Object {[math]::Round($_.SizeRemaining / 1GB, 1)}
}
IF ([int]$FreeSize -lt 5) {
		Write-Host `n
		Write-Host -ForegroundColor Red "Attention, not enough free space on drive C: to perform the updates, please free up space, free space is $FreeSize GB!"`n
		Write-Host "$MaintDeviceName ist still running, please shut down the server! Press Enter to exit"
		Read-Host
		BREAK
	}
	
ELSE {
	Write-Host -ForegroundColor Green "Enough free space ($FreeSize GB) on drive C: to perform the updates, please wait..."`n
	Do {
		#Reset Timeouts
		$ConnectionTimeout = 0
		$Evergreen = 0

		#Starts up a remote powershell session to the computer
		Do {
			$session = New-PSSession -ComputerName $MaintDeviceName
			Write-Host "Reconnecting to $MaintDeviceName" `n
			Start-Sleep -seconds 10
			$connectiontimeout++
		} Until ($session.state -match "Opened" -or $connectiontimeout -ge 10)

		# Create a new task for Evergreen
		Write-Host -ForegroundColor Yellow "Create scheduled task for launching Evergreen"
			Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
				Get-ScheduledTask -TaskName "Evergreen" -EA SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
			}
			Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
				$Installer = "$Using:EvergreenShare\Evergreen-Software Installer.ps1"
				$Options = @(
				"-file"
				"`"$Installer`""
				"-noGUI"
				"-SoftwareToAutoInstall"
				)
				$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "$Options"
				$User = "NT AUTHORITY\SYSTEM"
				Register-ScheduledTask -TaskName "Evergreen" -User $User -Action $Action -RunLevel Highest –Force | Out-Null
			}

		# Run Evergreen task
		Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Start-ScheduledTask -TaskName "Evergreen" | Out-Null}
		Start-Sleep -seconds 3
		Write-Host "Evergreen is running..."`n
		Do {
			$EvergreenLog = (Get-ChildItem -Path "$EvergreenShare\Software\_Install Logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
			#$EvergreenStatus = Get-Content "$EvergreenShare\_Install Logs\$EvergreenLog"
			Get-Content "$EvergreenShare\Software\_Install Logs\$EvergreenLog" | Select-Object -Last 1  | Select-String -Pattern Installing -ErrorAction SilentlyContinue
			Start-Sleep -Seconds 5
			$Finished = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
				(Get-ScheduledTask -TaskName 'Evergreen').State
				}
		} Until ($Finished.Value -eq "Ready")
		Write-Host -ForegroundColor Green "Finished..."`n
		$EvergreenLog = (Get-ChildItem -Path "$EvergreenShare\Software\_Install Logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
		$Updates = Get-Content -Path "$EvergreenShare\Software\_Install Logs\$EvergreenLog" | Select-String -Pattern Installing
		$Updates = ($Updates -replace ("Uninstalling","") -replace ("Installing","") | Select-Object -Unique) -join ","
		Write-Host "Updates installed: $Updates"`n
		$Evergreen = 1
		Write-Host -ForegroundColor Yellow "Restarting '$MaintDeviceName'"`n
		Start-Sleep -Seconds 6
		Restart-Computer -Wait -ComputerName $MaintDeviceName -Force
		
	} Until ($Evergreen -eq 1)
}

# Sealing VM with BIS-F
IF ($BISF -eq "YES") {
	# Get PVS cache drive letter
	$CacheDrive = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
		(Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | Where-Object {$_.DeviceID -ne "C:"}).DeviceID
		}
	$CacheDrive = $CacheDrive -replace (":","$")
	$BISFLogLocation = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
		(Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Login Consultants\BISF" -Name LIC_BISF_CLI_LS -ErrorAction SilentlyContinue).LIC_BISF_CLI_LS 		
		}

	Write-Host -ForegroundColor Yellow "Starting BIS-F to seal the image"`n
	$BISFTask = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Get-ScheduledTask -TaskName "BIS-F" -ErrorAction SilentlyContinue}
	IF ($BISFTask -eq $Null) {
		copy-item "C:\Program Files (x86)\PVS Admin Toolkit\vDisk Maintenance\BIS-F.xml" "\\$MaintDeviceName\admin$\Temp" 
		invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Register-ScheduledTask -Xml (Get-Content "C:\Windows\Temp\BIS-F.xml" | out-string) -TaskName "BIS-F"}
		}
	Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {Start-ScheduledTask -TaskName "BIS-F" | Out-Null}
	Start-Sleep -seconds 30
	Write-Host "BIS-F is running..."`n
	
	IF ([string]::ISNullOrEmpty( $BISFLogLocation) -eq $True) {
		Do {
			$BISFLog = ((Get-ChildItem -Path "\\$MaintDeviceName\$CacheDrive\BISFLogs") | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
			$BISFStatus = Get-Content "\\$MaintDeviceName\$CacheDrive\BISFLogs\$BISFLog"
			Get-Content "\\$MaintDeviceName\$CacheDrive\BISFLogs\$BISFLog" | select-object -Last 1
			Start-Sleep -Seconds 1
			$Finished = ([regex]::Matches($BISFStatus, "End Of Script" ))	
		} Until ($Finished.Value -eq "End of Script")
	}
	ELSE {
		Do {
			$BISFLog = ((Get-ChildItem -Path "$BISFLogLocation\$MaintDeviceName") | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
			$BISFStatus = Get-Content "$BISFLogLocation\$MaintDeviceName\$BISFLog"
			Get-Content "$BISFLogLocation\$MaintDeviceName\$BISFLog" | Select-Object -Last 1
			Start-Sleep -Seconds 1
			$Finished = ([regex]::Matches($BISFStatus, "End Of Script" ))	
		} Until ($Finished.Value -eq "End of Script")
	}
}

#Shutdown VM without using BIS-F
ELSE {
	  invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {shutdown -s -t 1 -f}
}

# Wait for shutdown
# Citrix XenServer
IF ($Hypervisor -eq "Xen") {
	Do {
		Write-Host -ForegroundColor Yellow "VM '$MaintDeviceName' is shutting down..."`n
		$Powerstate = (Get-XenVM | Where-Object {$_.name_label -eq "$MaintDeviceName"})
		Start-Sleep -seconds 10
		} Until ($Powerstate.power_state -eq "Halted")
}

# VMWare vSphere
IF ($Hypervisor -eq "ESX") {
	Do {
		Write-Host -ForegroundColor Yellow "VM '$MaintDeviceName' is shutting down..."`n
		$Powerstate = (Get-VM | Where-Object {$_.Name -eq "$MaintDeviceName"})
		Start-Sleep -seconds 10
		} Until ($Powerstate.PowerState -eq "PoweredOff")
}

# Nutanix AHV
IF ($Hypervisor -eq "AHV") {
	Do {
		Write-Host -ForegroundColor Yellow "VM '$MaintDeviceName' is shutting down..."`n
		$Powerstate = (Get-NTNXVirtualMachine | Where-Object {$_.Name -eq "$MaintDeviceName"})
		Start-Sleep -seconds 10
		} Until ($Powerstate.PowerState -eq "OFF")
}
Write-Host -ForegroundColor Green "'$MaintDeviceName' shutdown" `n
	
#Promote vDisk to Test
Write-Host -ForegroundColor Yellow "Promoting vDisk '$vDiskName' version $MaintVersion to test mode" `n
Invoke-PvsPromoteDiskVersion -DiskLocatorName $vDiskName -StoreName $StoreName -SiteName $SiteName -Test
Set-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName -Version $MaintVersion -Description "Update $Updates"
Write-Host -ForegroundColor Green "Ready, start device in test mode to check vDisk!"

# Replicate vDisk
Write-Host -ForegroundColor Yellow "Executing vDisk replication script" `n
."$Rootfolder\vDisk Replication\Replicate PVS vDisk.ps1"

