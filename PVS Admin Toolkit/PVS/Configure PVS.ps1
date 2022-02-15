<#
.SYNOPSIS
This script will configure a PVS maintenance device
	
.DESCRIPTION
The purpose of the script is to define a PVS maintenance device if the VM name on the hypervisor is different to the Windows hostname 

.NOTES

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-06
Purpose/Change:	
2022-02-06		Inital version
#>

# Variables
$PVSConfig = "$PSScriptRoot\PVS.xml"
$PVSSelection = New-Object PSObject

# VM name of PVS maintenance device
$title = ""
$message = "Is the virtual machine name of the PVS maintenance device identical to the Windows hostname?"
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

	if ($answer -eq 'No') {
		$MaintDeviceName = Read-Host "Enter VM name of the PVS maintenance device"
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "MaintDeviceName" -Value $MaintDeviceName -Force
		}
Write-Host `n

# VM name of PVS maintenance device
$title = ""
$message = "Do you use Base Image Script Framework inside your PVD vDisk? (You really should! https://eucweb.com)"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
	switch ($choice) {
		0 {
		$BISF = 'Yes'       
		}
		1 {
		$BISF = 'No'
		}
	}
	
	if ($BISF -eq 'Yes') {
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "BISF" -Value "$BISF" -Force
		}

	if ($BISF -eq 'No') {
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "BISF" -Value "$BISF" -Force
	}
Write-Host `n

# Skip PVS Boot menu
$title = ""
$message = "Do you want to skip the PVS boot menu for your maintenance device? Required if you want to install Windows Updates via scheduled task!"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
	switch ($choice) {
		0 {
		$SkipBootMenu = 'Yes'       
		}
		1 {
		$SkipBootMenu = 'No'
		}
	}
	
	if ($SkipBootMenu -eq 'Yes') {
		New-ItemProperty -Path "HKLM:\Software\Citrix\ProvisioningServices\StreamProcess" -Name 'SkipBootMenu' -Value '1' -PropertyType DWORD -Force | Out-Null
		$title = ""
		$message = "Do you want to restart the PVS streaming service for the changes to take effect?"
		$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
		$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
		$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
		switch ($choice) {
			0 {
			$StreamingService = 'Yes'       
			}
			1 {
			$StreamingService = 'No'
			}
		}
	
		if ($StreamingService -eq 'Yes') {
			Restart-Service -Name StreamService -Force
			Write-Host -Foregroundcolor Yellow "Registry value 'HKLM\SOFTWARE\Citrix\ProvisioningServices\StreamProcess\SkipBootMenu' set to '1' and PVS Streaming service successfully restarted"
			}
	}
Write-Host `n

$PVSSelection | Export-Clixml $PVSConfig