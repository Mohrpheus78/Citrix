<#
.SYNOPSIS
This script will start a PVS master from a new vDIsk version
	
.DESCRIPTION
The purpose of the script is to start a PVS master on a hypervisor you defined earlier and to boot it from a new vDisk version

.NOTES
The variables have to be present in the XML files, configure your hypervisor with the configuration menu first!

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-06
Purpose/Change:	
2022-02-06		Inital version
2022-02-10		Added Nutanix and changed credentials check
#>

$ScriptStart = Get-Date

# RunAs Admin
function Use-RunAs 
{    
    # Check if script is running as Administrator and if not elevate it
    # Use Check Switch to check if admin 
     
    param([Switch]$Check) 
     
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()` 
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
         
    IF ($Check) { return $IsAdmin }   
      
    IF ($MyInvocation.ScriptName -ne "") 
    {  
        IF (-not $IsAdmin)  
          {  
            try 
            {  
                $arg = "-WindowStyle Maximized -file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop'  
            } 
            catch 
            { 
                Write-Warning "Error - Failed to restart script elevated"  
                BREAK               
            } 
            exit 
        }  
    }  
} 

Use-RunAs

IF ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
	}

# Get PVS Site
$SiteName = (Get-PvsSite).SiteName

# Get PVS device in maintenance mode for the selected vDisk
$MaintDeviceNameWindows = (Get-PvsDeviceInfo -SiteName $SiteName | where-Object {$_.Type -eq 2 -and $_.DiskLocatorName -like "*$StoreName\$vDiskName*"}).Name
$MaintDeviceName = (Get-PvsDeviceInfo -SiteName $SiteName | where-Object {$_.Type -eq 2 -and $_.DiskLocatorName -like "*$vDiskName*"}).Name
$vDisks = (Get-PvsDeviceInfo -DeviceName $MaintDeviceName).DiskLocatorName
$vDisks = $vDisks.Split(",").Trim()

# Variables
$RootFolder = Split-Path -Path $PSScriptRoot
$Date = Get-Date -UFormat "%d.%m.%Y"
$StartMasterLog = "$RootFolder\Logs\Start-Master-$MaintDeviceName.log"
$HypervisorConfig = Import-Clixml "$RootFolder\Hypervisor\Hypervisor.xml"
$Hypervisor = $HypervisorConfig.Hypervisor
$PVSConfig = Import-Clixml "$RootFolder\PVS\PVS.xml"

# Start logging
Start-Transcript $StartMasterLog | Out-Null

# Check if more than one vDisk is attached
$SkipBootMenu = $PVSConfig.SkipBootMenu
IF ($vDisks.Count -gt 1) {
    Write-Host -ForegroundColor Red "Attention! $MaintDeviceName has more than one vDisks attached! Check if $MaintDeviceName is able to boot!"`n
	IF ($SkipBootMenu -eq 'Yes') {
		IF (!("$StoreName\$vDiskName" -contains $vDisks[0])) {
		Write-Host -ForegroundColor Red "Error, you selected vDisk $StoreName\$vDiskName but '$MaintDeviceName' will boot vDisk"$vDisks[0]"!"`n
			IF (-not(Test-Path variable:Task) -or $Task -eq $false) {
			Read-Host "Press any key to exit"
			}
			BREAK
		}
	}
}

# Citrix XenServer
IF ($Hypervisor -eq "Xen") {
	# Check XenServer PS Module
	IF (!(Get-Module -ListAvailable -Name XenServerPSModule)) {
	Write-Host -ForegroundColor Red "No XenServer Powershell module found, aborting! Please copy module to 'C:\Program Files\WindowsPowerShell\Modules'"
	Read-Host "Press any key to exit"
	BREAK
	}
	Import-Module XenServerPSModule | Out-Null
	$Xen = $HypervisorConfig.Host
	$Credential = Import-CliXml -Path "$RootFolder\Hypervisor\Credentials-$env:username-Xen.xml"	
	Try {
		Connect-XenServer -url https://$Xen -Creds $Credential -NoWarnNewCertificates -SetDefaultSession | Out-Null
	}
	Catch {
		 Write-Warning "Error: $_."
		 Write-Host -ForegroundColor Red "Unable to connect to configured XenServer '$Xen', check your configuration!"
		 Read-Host
		 BREAK
	}
	IF (-not(Get-XenVM | Where-Object {$_.name_label -eq "$MaintDeviceName"})) {
		$MaintDeviceName = $PVSConfig.MaintDeviceName
	}
		IF (Get-XenVM | Where-Object {$_.name_label -eq "$MaintDeviceName" -and $_.power_state -eq "Halted" -and $_.is_a_template -eq $False}) {
			Do {
				Write-Host `n
				Write-Output "Starting VM '$MaintDeviceName'"
				Invoke-XenVM -Name "$MaintDeviceName" -XenAction Start | Out-Null
				} Until (Get-XenVM | Where-Object {$_.name_label -eq "$MaintDeviceName" -and $_.power_state -eq "Running"}) 
				Write-Host `n
				Write-Output "'$MaintDeviceName' successfully powered on"
		}
}

# VMWare vSphere
IF ($Hypervisor -eq "ESX") {
	# Check VMWare PS Module
	IF (!(Get-Module -ListAvailable -Name VMware.PowerCLI)) {
	Write-Host -ForegroundColor Red "No VMWare Powershell module found, aborting! Please install module to 'C:\Program Files\WindowsPowerShell\Modules'"
	Read-Host "Press any key to exit"
	BREAK
	}
	$ESX = $HypervisorConfig.Host
	$Credential = Import-CliXml -Path "$RootFolder\Hypervisor\Credentials-$env:username-ESX.xml"
	Try {
		Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false | Out-Null
		Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false | Out-Null
		Connect-VIServer -server $ESX -Credential $Credential
	}
	Catch {
		Write-Warning "Error: $_."
		Write-Host -ForegroundColor Red "Unable to connect to configured XenServer '$ESX', check your configuration!"
		Read-Host
		BREAK
	}
	IF (-not(Get-VM | Where-Object {$_.Name -eq "$MaintDeviceName"})) {
		$MaintDeviceName = $PVSConfig.MaintDeviceName
	}		
	IF (Get-VM -Name "$MaintDeviceName" | Where-Object {$_.PowerState -eq "PoweredOff"}) {
		Do {
			Write-Host `n
			Write-Output "Starting VM '$MaintDeviceName'"
			Start-VM -VM "$MaintDeviceName" | Out-Null
			} Until (Get-VM | Where-Object {$_.Name -eq "$MaintDeviceName" -and $_.PowerState -eq "PoweredOn"})
			Write-Host `n
			Write-Output "'$MaintDeviceName' successfully powered on"
	}
	
}

# Nutanix AHV
IF ($Hypervisor -eq "AHV") {
	# Check Nutanix PS Module
	IF ($PSVersionTable.PSVersion -lt "7.0") {
		Write-Host -ForegroundColor Red "You need Powershell 7.0 or higher to use the Nutanix Powershell module, please install the recent version of Powershell"
		Read-Host "Press any key to exit"
		BREAK
	}
	IF (!(Get-Module -ListAvailable -Name Nutanix.Cli)) {
	Write-Host -ForegroundColor Red "No Nutanix Powershell module found, aborting! Please install module to 'C:\Program Files\WindowsPowerShell\Modules'"
	Read-Host
	BREAK
	}
	Import-Module Nutanix.Prism.PS.Cmds -Prefix NTNX 
	$AHV = $HypervisorConfig.Host
	$AHVAdmin = Get-Content "$RootFolder\Hypervisor\Admin-AHV.txt"
	$AHVPassword = Get-Content "$RootFolder\Hypervisor\Password-AHV.txt"
	
	Try {
		Connect-NutanixCluster -Server $AHV -UserName $AHVAdmin -Password $AHVPassword -AcceptInvalidSSLCerts
		IF (-not(Get-NTNXVirtualMachine | Where-Object {$_.Name -eq "$MaintDeviceName"})) {
			$MaintDeviceName = "$PVSConfig.MaintDeviceName"
		}		
		$UUID = (Get-NTNXVirtualMachine -Name "$MaintDeviceName").Uuid
		IF (Get-NTNXVirtualMachine -Name "$MaintDeviceName" | Where-Object {$_.PowerState -eq "OFF"}) {
			Do {
				Write-Host `n
				Write-Output "Starting VM '$MaintDeviceName'"
				Start-NTNXVM -Uuid $UUID | Out-Null
				} Until (Get-NTNXVirtualMachine | Where-Object {$_.Name -eq "$MaintDeviceName" -and $_.PowerState -eq "ON"})
				Write-Host `n
				Write-Output "'$MaintDeviceName' successfully powered on"
		}
	}
	Catch {
		Write-Warning "Error: $_."
		Write-Host -ForegroundColor Red "Unable to connect to configured XenServer '$AHV', check your configuration!"
		Read-Host
		BREAK
	}
}

# Wait until VM is up
$connectiontimeout = 0
Do {
	Write-Host `n
    Write-Host "Waiting for '$MaintDeviceNameWindows' to boot..." `n
    Start-Sleep 8
    $connectiontimeout++
   } until (Test-NetConnection "$MaintDeviceNameWindows.$ENV:USERDNSDOMAIN" -Port 5985 | Where-Object {$_.TcpTestSucceeded -or $connectiontimeout -ge 10})
IF ($connectiontimeout -eq 15) {
    Write-Host -ForegroundColor Red "Something is wrong, server not reachable, check the status of $MaintDeviceNameWindows, hit any key to exit"
	# Stop Logging
	$ScriptEnd = Get-Date
	$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
	$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
	Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds" `n
	Stop-Transcript #| Out-Null
	$Content = Get-Content -Path $StartMasterLog | Select-Object -Skip 18
	Set-Content -Value $Content -Path $StartMasterLog
	Rename-Item -Path $StartMasterLog -NewName "Start-Master-VM-$MaintDeviceNameWindows-$Date.log"
	Read-Host
	BREAK
    }
else {
      Start-Sleep -seconds 15
      Write-Host -ForegroundColor Green "Server '$MaintDeviceNameWindows' finished booting" `n
      }

IF (!($WindowsUpdates -or $Evergreen)) {
# Connect to master?
$title = ""
	$message = "Do you want to connect to the master VM via RDP?"
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
		$connectiontimeout = 0
		Do {
			Write-Host `n
			Write-Host "Check if '$MaintDeviceNameWindows' is ready to connect..." `n
			Start-Sleep 5
			$connectiontimeout++
		   } until (Test-NetConnection "$MaintDeviceNameWindows.$ENV:USERDNSDOMAIN" -Port 3389 | Where-Object {$_.TcpTestSucceeded -or $connectiontimeout -ge 5})
		   start-process mstsc.exe -ArgumentList "/f /admin /v:$MaintDeviceNameWindows"
		IF ($connectiontimeout -eq 10) {
			Write-Host -ForegroundColor Red "Something is wrong, server not reachable, check the status of $MaintDeviceNameWindows"
			}
	}
}

# Stop Logging
$ScriptEnd = Get-Date
$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds" `n
Stop-Transcript #| Out-Null
$Content = Get-Content -Path $StartMasterLog | Select-Object -Skip 18
Set-Content -Value $Content -Path $StartMasterLog
Rename-Item -Path $StartMasterLog -NewName "Start-Master-VM-$MaintDeviceNameWindows-$Date.log" -Force -EA SilentlyContinue

# Install Windows Updates
IF ($WindowsUpdates -eq "True") {
	."$PSScriptRoot\Windows Updates.ps1"
	}

# Launch Evergreen
IF ($Evergreen -eq "True") {
	."$PSScriptRoot\Evergreen.ps1"
	}
