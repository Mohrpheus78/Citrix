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
$Time = Get-Date -DisplayHint Time | foreach {$_ -replace ":", "-"}
$NewvDiskLog = "$RootFolder\Logs\New PVS vDisk version-$Time.log"
write-host $StartMaster

# Start logging
Start-Transcript $NewvDiskLog | Out-Null

$ScriptStart = Get-Date

# Check if PVS SnapIn is available
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
}

# New version
Write-Host -ForegroundColor Yellow "New vDisk version" `n

# Get PVS SiteName
$SiteName = (Get-PvsSite).SiteName

# Get all vDisks
IF (-not(Test-Path variable:Task) -or $Task -eq $false) {
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
}

# Create new vDisk version if possible
IF (-not(Test-Path variable:Task) -or $Task -eq $false) {
	$CanPromote = ((Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName) | Select-Object -First 1).CanPromote
	if ($CanPromote) {
		Write-Host -ForegroundColor Red "Current vDisk version is alreadey a in 'Maintenance' mode or in 'Test' mode!"`n
		
		$title = ""
		$message = "Do you want to use this version?"
		$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
		$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
		$choice=$host.ui.PromptForChoice($title, $message, $options, 0)

		switch ($choice) {
			0 {
			$answer1 = 'Yes'       
			}
			1 {
			$answer1 = 'No'
			}
		}

		if ($answer1 -eq 'Yes') {
			# Stop Logging
			$ScriptEnd = Get-Date
			$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
			$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
			Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds"`n

			Stop-Transcript | Out-Null
			$Content = Get-Content -Path $NewvDiskLog | Select-Object -Skip 18
			Set-Content -Value $Content -Path $NewvDiskLog
			Rename-Item -Path $NewvDiskLog -NewName "New PVS vDisk version-vDisk $vDiskName-Version $MaintVersion-$Date.log" -Force -EA SilentlyContinue
		}

		if ($answer1 -eq 'No') {
			Read-Host "Press any key to exit"
			BREAK
		}
	}
	else {
		# New maintenance version
		New-PvsDiskMaintenanceVersion -DiskLocatorName $vDiskName -StoreName $StoreName -SiteName $SiteName | Out-Null
		$MaintVersion = (Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName | Select-Object -First 1).Version
		Write-Host -ForegroundColor Green `n"New Version '$MaintVersion' successfully created, check logfile '$NewvDiskLog'"`n
	}
}
else {
	# New maintenance version if launched with task
	New-PvsDiskMaintenanceVersion -DiskLocatorName $vDiskName -StoreName $StoreName -SiteName $SiteName | Out-Null
	$MaintVersion = (Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName | Select-Object -First 1).Version
	Write-Host -ForegroundColor Green `n"New Version '$MaintVersion' successfully created, check logfile '$NewvDiskLog'"`n
}	

	
# Start Master VM? Default Yes if doing Windows Updates
IF ((Test-Path variable:Task) -or ($WindowsUpdates -eq $True) -or ($Task -eq $true)) {
	."$PSScriptRoot\Start Master.ps1"
}
Else {
	$title = ""
	$message = "Do you want to start the master VM?"
	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
	$choice=$host.ui.PromptForChoice($title, $message, $options, 0)

	switch ($choice) {
		0 {
		$answer2 = 'Yes'       
		}
		1 {
		$answer2 = 'No'
		}
	}

	if ($answer2 -eq 'Yes') {
		."$PSScriptRoot\Start Master.ps1"
	}
}

IF (-not(Test-Path variable:Task) -or ($Task -eq $false)) {
	Read-Host "Press any key to exit"
}
	
# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $NewvDiskLog | Select-Object -Skip 18
Set-Content -Value $Content -Path $NewvDiskLog
Rename-Item -Path $NewvDiskLog -NewName "New PVS vDisk version-$vDiskName-$Date.log" -Force -EA SilentlyContinue
