<#
.SYNOPSIS
This script will automatically install all avaialable windows updates on a device and will automatically reboot if needed, after reboot,
windows updates will continue to run until no more updates are available.

.DESCRIPTION
The purpose of the script is to remotely install Windows Updates inside a new PVS vDisk and to promote the vDisk to Test

.NOTES
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-18
#>


# Variables
$RootFolder = Split-Path -Path $PSScriptRoot
$Date = Get-Date -UFormat "%d.%m.%Y"
$HypervisorConfig = Import-Clixml "$RootFolder\Hypervisor\Hypervisor.xml"
$Hypervisor = $HypervisorConfig.Hypervisor
$PVSConfig = Import-Clixml "$RootFolder\PVS\PVS.xml"
$BISF = $PVSConfig.BISF
$WULog = "$RootFolder\Logs\Windows Update.log"


# FUNCTION Logging
#========================================================================================================================================
Function DS_WriteLog {
    
    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory=$true, Position = 0)][ValidateSet("I","S","W","E","-",IgnoreCase = $True)][String]$InformationType,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text
    )
 
    begin {
    }
 
    process {
     $DateTime = (Get-Date -format yyyy-MM-dd) + " " + (Get-Date -format HH:mm:ss)
	
	 IF (-not(Test-Path -Path $WULog)) 
		{
			New-Item -Path $WULog -ItemType File -Force | out-null
		}
	 
		
        if ( $Text -eq "" ) {
            Add-Content $WULog -value ("") # Write an empty line
        } Else {
         Add-Content $WULog -value ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
		 Write-Host ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
        }
    }
 
    end {
    }
}

# Check free size
$FreeSize = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
	(Get-Volume -DriveLetter C) | ForEach-Object {[math]::Round($_.SizeRemaining / 1GB, 1)}
}
IF ($FreeSize -lt 5) {
		Write-Host `n
		Write-Host -ForegroundColor Red "Attention, not enough free space on drive C: to perform the updates, please free up space, free space is $FreeSize GB!"`n
		Write-Host "$MaintDeviceName ist still running, please shut down the server! Press Enter to exit"
		Read-Host
		DS_WriteLog "E" "Attention, not enough free space on drive C: to perform the updates, please free up space, free space is $FreeSize GB!"
		Rename-Item -Path $WULog -NewName "Windows Update-$MaintDeviceName-$Date.log"
		BREAK
	}
	
ELSE {
Write-Host -ForegroundColor Green "Enough free space ($FreeSize GB) on drive C: to perform the updates, please wait..."`n

#Check PSWindowsUpdate module
DS_WriteLog "I" "Checking PSWindowsUpdate Module..."
$PSWindowsUpdate = invoke-command -ComputerName $MaintDeviceName -ScriptBlock {Get-Module -ListAvailable -Name PSWindowsUpdate}
IF ($PSWindowsUpdate -eq $null) {
	DS_WriteLog "E" "No PSWindowsUpdate Powershell module found, trying to install PSWindowsUpdate module..."
	#write-host -ForegroundColor Red "No PSWindowsUpdate Powershell module found, trying to install PSWindowsUpdate module..."
	DS_WriteLog "I" "Trying to install PSWindowsUpdate Module..."
	invoke-command -ComputerName $MaintDeviceName -ScriptBlock {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		IF (!(Test-Path -Path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget")) {Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies}
		IF (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {Install-Module PSWindowsUpdate -Force}
		}
}
$PSWindowsUpdate = invoke-command -ComputerName $MaintDeviceName -ScriptBlock {Get-Module -ListAvailable -Name PSWindowsUpdate}
IF ($PSWindowsUpdate -eq $null) {
	DS_WriteLog "E" "Installation of PSWindowsUpdate Powershell module failed! Please install PSWindowsUpdate module to 'C:\Program Files\WindowsPowerShell\Modules'"
	#write-host -ForegroundColor Red "Installation of PSWindowsUpdate Powershell module failed! Please install PSWindowsUpdate module to 'C:\Program Files\WindowsPowerShell\Modules'"
	DS_WriteLog "I" "Shutting down VM, delete the vDisk maintenence version after shutdown!"
	#write-host -ForegroundColor Red "Shutting down VM, delete the vDisk maintenence version after shutdown!"
	Read-Host "Press ENTER to shutdown VM..."
	invoke-command -ComputerName $MaintDeviceName -ScriptBlock {shutdown -s -t 5 -f}
	BREAK
	}

# Update PSWindowsUpdate module
DS_WriteLog "I" "Trying to update PSWindowsUpdate Module..."
Write-Host `n
$LocalPSWindowsUpdate = invoke-command -ComputerName $MaintDeviceName -ScriptBlock {(Get-Module -Name PSWindowsUpdate -ListAvailable | Select-Object -First 1).Version}
$CurrentPSWindowsUpdate = invoke-command -ComputerName $MaintDeviceName -ScriptBlock {(Find-Module -Name PSWindowsUpdate -Repository PSGallery).Version}
IF (($LocalPSWindowsUpdate -lt $CurrentPSWindowsUpdate))
{
    invoke-command -ComputerName $MaintDeviceName -ScriptBlock {Update-Module PSWindowsUpdate -force}
}

# Import PSWindowsUpdate module
DS_WriteLog "I" "Import PSWindowsUpdate module"
Write-Host `n
invoke-command -ComputerName $MaintDeviceName -ScriptBlock {Import-Module PSWindowsUpdate -force}

Do{
   #Reset Timeouts
	$ConnectionTimeout = 0
	$UpdateTimeout = 0
     
	#Starts up a remote powershell session to the computer
	Do {
		$session = New-PSSession -ComputerName $MaintDeviceName
		Write-Host `n"Connecting to '$MaintDeviceName'"`n
		Start-Sleep -seconds 10
		$connectiontimeout++
	} Until ($session.state -match "Opened" -or $connectiontimeout -ge 10)

    #Retrieves a list of available updates
	Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
		$ServiceName = 'wuauserv'
		$Service = Get-Service -Name $ServiceName
		while ($Service.Status -ne 'Running')
			{	
			Set-Service -Name $ServiceName -Startup Automatic
			Start-Service $ServiceName
			Write-host "Windows Update service is starting"
			Start-Sleep -seconds 10
			$Service.Refresh()
			if ($Service.Status -eq 'Running')
				{
				Write-Host "Windows Update service is now running" `n
				}
			}
			Write-Host "FSLogix rules will be temporarily moved, if there are any..."`n
			New-Item -Path "C:\Program Files\FSLogix\Apps\Rules" -Name WU -ItemType Directory -EA SilentlyContinue | Out-Null
			Move-Item -Path "C:\Program Files\FSLogix\Apps\Rules\*.*" "C:\Program Files\FSLogix\Apps\Rules\WU" | Out-Null
	}
	Start-Sleep -seconds 10
	DS_WriteLog "I" "Checking for new updates available on '$MaintDeviceName'"
	#Write-Host -ForegroundColor Yellow "Checking for new updates available on '$MaintDeviceName'"`n
	Write-Host `n
	invoke-command -session $session -scriptblock {
		# Add updates, you don't want to search for
		$HideList = "KB4481252", "KB4023307", "KB4017094", "KB4013867", "KB4535680"
		Get-WindowsUpdate -KBArticleID $HideList -Hide -Confirm:$false
	}
	$Updates = invoke-command -session $session -scriptblock {Get-WindowsUpdate -NotCategory 'Drivers' -Criteria "Type='Software' AND IsInstalled=0" -AcceptAll -Verbose}
	Write-Host `n
	DS_WriteLog "I" ("Found " + $Updates.count + " Updates:")
   	#Counts how many updates are available
    $UpdateNumber = ($Updates.kb).count
	# Write updates to Log
	foreach ($Update in $Updates) {
			DS_WriteLog "I" ($Update.KB + " " + $Update.Title)
			}
						
	#If there are available updates proceed with installing the updates and then reboot the remote machine
	if ($Updates -ne $Null){
		#Remote command to install windows updates, creates a scheduled task on remote computer
		Write-Host `n
		DS_WriteLog "I" "Trying to install Updates..."
		Write-Host `n
        invoke-command -ComputerName $MaintDeviceName -ScriptBlock { Invoke-WUjob -ComputerName localhost -Script "Install-WindowsUpdate -NotCategory 'Drivers' -AcceptAll | Out-File C:\PSWindowsUpdate.log" -Confirm:$false -RunNow}
        #Show update status until the amount of installed updates equals the same as the amount of updates available
        Start-Sleep -Seconds 5
            Do {
				$UpdateStatus = Get-Content \\$MaintDeviceName\c$\PSWindowsUpdate.log
                Write-Host "Installing updates, please wait..."`n
				Start-Sleep -Seconds 90
                $ErrorActionPreference = 'SilentlyContinue'
                $InstalledNumber = ([regex]::Matches($updatestatus, "Installed" )).count
                $FailedNumber = ([regex]::Matches($updatestatus, "Failed" )).count
                $ErrorActionPreference = 'Continue'
                $UpdateTimeout++
               } Until ( ($installednumber + $Failednumber) -eq $updatenumber -or $updatetimeout -ge 180)
            #Restarts the remote computer and waits till it starts up again
			Write-Host `n
			DS_WriteLog "I" "Finished!"
			Write-Host -ForegroundColor Green "Finished!"
			Start-Sleep -Seconds 5
			Write-Host -ForegroundColor Yellow "Restarting '$MaintDeviceName'"
			Restart-Computer -Wait -ComputerName $MaintDeviceName -Force
    }
} Until ($Updates -eq $Null)
}

DS_WriteLog "I" "Windows is now up to date on '$MaintDeviceName'"
Write-Host -ForegroundColor Green "Windows is now up to date on '$MaintDeviceName'"`n
Get-Content \\$MaintDeviceName\c$\PSWindowsUpdate.log
Write-Host `n
DS_WriteLog "I" "Moving FSLogix rules back to rules folder..."
Write-Host "Moving FSLogix rules back to rules folder"`n
invoke-command -computername $MaintDeviceName -ScriptBlock {Move-Item -Path "C:\Program Files\FSLogix\Apps\Rules\WU\*.*" "C:\Program Files\FSLogix\Apps\Rules" | Out-Null}

#Copy log to PVS server
if (Test-Path -Path "\\$MaintDeviceName\c$\PSWindowsUpdate.log") {
	Copy-Item "\\$MaintDeviceName\c$\PSWindowsUpdate.log" $WULog | Rename-Item "$WULog\PSWindowsUpdate.log" -NewName "WindowsUpdate-$MaintDeviceName-$vDiskName-$MaintVersion-$Date.log"
	}

# Shutdown VM with BIS-F
DS_WriteLog "I" "Shutdown VM with BIS-F"
IF ($BISF -eq "YES") {
	# Get PVS cache drive letter
	$CacheDrive = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
		(Get-WmiObject -Class Win32_logicaldisk -Filter "DriveType = '3'" | Where-Object {$_.DeviceID -ne "C:"}).DeviceID
		}
	$CacheDrive = $CacheDrive -replace (":","$")
	$BISFLogLocation = Invoke-Command -ComputerName $MaintDeviceName -ScriptBlock {
		(Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Login Consultants\BISF" -Name LIC_BISF_CLI_LS -ErrorAction SilentlyContinue).LIC_BISF_CLI_LS 		
		}
		Write-Host "BIS-F Log location is '$BISFLogLocation'"`n
		
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
			Write-Host "BIS-F Log is '$BISFLog'"
			$BISFStatus = Get-Content "\\$MaintDeviceName\$CacheDrive\BISFLogs\$BISFLog"
			Get-Content "\\$MaintDeviceName\$CacheDrive\BISFLogs\$BISFLog" | select-object -Last 1
			Start-Sleep -Seconds 1
			$Finished = ([regex]::Matches($BISFStatus, "End Of Script" ))	
		} Until ($Finished.Value -eq "End of Script")
	}
	ELSE {
		Do {
			$BISFLog = ((Get-ChildItem -Path "$BISFLogLocation\$MaintDeviceName") | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
			Write-Host "BIS-F Log is '$BISFLog'"
			$BISFStatus = Get-Content "$BISFLogLocation\$MaintDeviceName\$BISFLog"
			Get-Content "$BISFLogLocation\$MaintDeviceName\$BISFLog" | Select-Object -Last 1
			Start-Sleep -Seconds 1
			$Finished = ([regex]::Matches($BISFStatus, "End Of Script" ))	
		} Until ($Finished.Value -eq "End of Script")
	}
}

#Shutdown VM without using BIS-F
ELSE {
	  DS_WriteLog "I" "Shutdown VM without using BIS-F"
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
Set-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName -Version $MaintVersion -Description "Windows Updates"

# Replicate vDisk to all PVS server in store
Write-Host -ForegroundColor Yellow "Replicate vDisk to all PVS server in store" `n
$AllPVSServer = Get-PvsServer -StoreName $StoreName -SiteName $SiteName | Select-Object ServerName
     foreach ($PVSServer in $AllPVSServer | Where-Object {$_.ServerName -ne "$env:COMPUTERNAME"}) {
         $LocalStorePath  = (Get-PvsStore -StoreName "$StoreName").Path
         $RemoteStorePath = $LocalStorePath -replace (":","$")
         $PVSServer = $PVSServer.ServerName
         robocopy.exe "$LocalStorePath" "\\$PVSServer\$RemoteStorePath" /COPYALL /XD WriteCache /XF *.lok /ETA /SEC
         }

# Check Replication state
Write-Host -ForegroundColor Yellow "Check Replication state" `n
Get-PvsDiskVersion -Name $vDiskName -SiteName $SiteName -StoreName $StoreName | Where-Object {$_.GoodInventoryStatus -eq $true} | Sort-Object -Property Version | ForEach-Object {write-host -foregroundcolor Green ("Version: " + $_.Version + " Replication state: " + $_.GoodInventoryStatus)}
Get-PvsDiskVersion -Name $vDiskName -SiteName $SiteName -StoreName $StoreName | Where-Object {$_.GoodInventoryStatus -eq $false} | Sort-Object -Property Version | ForEach-Object {write-host -foregroundcolor Red ("Version: " + $_.Version + " Replication state: " + $_.GoodInventoryStatus)}
Write-Host -ForegroundColor Green `n"Ready! vDisk $vDiskName replicated" `n

DS_WriteLog "I" "Ready, start device in test mode to check vDisk!"
Rename-Item -Path $WULog -NewName "Windows Update-$MaintDeviceName-$Date.log" -Force -EA SilentlyContinue
Write-Host -ForegroundColor Green "Ready, start device in test mode to check vDisk!"

# Replicate vDisk
Write-Host -ForegroundColor Yellow "Executing vDisk replication script" `n
."$Rootfolder\vDisk Replication\Replicate PVS vDisk.ps1"