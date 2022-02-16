<#
.SYNOPSIS
This script will import a scheduled task from a template to start Windows Updates on a PVS maintenance device.
	
.DESCRIPTION
The script will first ask you about admin credentials to import the task and create a new task based on a template xml file. 
	
.EXAMPLE
."Windows Updates Task.ps1"
    
.NOTES
Run as administrator! If you want to change the root folder you have to modify the shortcut.

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-11-18
Purpose/Change:	
2021-11-18		Inital version
2022-02-16		Added vDisk menu
#>

Write-Host -Foregroundcolor Yellow "Create a scheduled task to automatically install Windows Updates on your PVS vDisk"`n

# Get Admin credentials
$AdminUsername =  Read-Host "Enter domain name and a domain admin user name to run the task (Domain\Admin or Admin@domain.com)"
$AdminPassword = $password = Read-Host "Enter password" -AsSecureString
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $AdminUsername, $AdminPassword
$Password = $Credentials.GetNetworkCredential().Password 

# Check if PVS SnapIn is available
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
}

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
Write-Host `n
Write-Host "Available vDisks:" `n 
$ValidChoices = 1..($AllvDisks.Count)
$Menu = $AllvDisks | ForEach-Object {(($_.ID).toString() + "." + " " +  $_.Name + " " + "-" + " " + "Storename:" + " " + $_.Storename)}
$Menu | Out-Host
Write-Host
$vDisk = Read-Host -Prompt 'Select the vDisk you want to update via task'

$vDisk = $AllvDisks | Where-Object {$_.ID -eq $vDisk}
if ($vDisk.ID -notin $ValidChoices) {
	Write-Host -ForegroundColor Red "Selected vDisk not found, aborting!"
	Read-Host "Press any key to exit"
	BREAK
	}
$vDiskName = $vDisk.Name
$StoreName = $vDisk.StoreName
	
(Get-Content "$PSScriptRoot\Windows Updates vDisk-Template.xml" ) | Foreach-Object {
    $_ -replace "vDisk-Template", "$vDiskName" `
       -replace "Store-Template", "$StoreName" 
    } | Set-Content "$PSScriptRoot\Windows Updates vDisk $vDiskName.xml"
Try {
	Register-ScheduledTask -User "$AdminUsername" -Password "$Password" -Xml (Get-Content "$PSScriptRoot\Windows Updates vDisk $vDiskName.xml" | out-string) -TaskName "Windows Updates vDisk $vDiskName" -Force
	$Taskstate = (Get-ScheduledTask -TaskName "Windows Updates vDisk $vDiskName" | Select-Object State).State
}
catch {
	Write-Warning "Task state $Taskstate"
	write-warning "Error: $_."
}
Write-Host `n
Write-Host -ForegroundColor Yellow "Add a trigger to the task 'Windows Updates vDisk $vDiskName', the vDisk will be promoted to 'Test' after installing the updates!"`n
Read-Host "Press ENTER to exit"
