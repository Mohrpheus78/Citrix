<#
.SYNOPSIS
This script will remove all logs file in the Logs folder if more than 30 items are present
	
.DESCRIPTION

.NOTES

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-12-20
#>

$LogsCount = (Get-ChildItem -Path $PSScriptRoot\Logs| Measure-Object).Count
IF ($LogsCount -gt 30) {
	
	# Remove logs?
	$title = ""
	$message = "The number of log files is more than 30, do you want to remove the logs?"
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
		Get-ChildItem -Path $PSScriptRoot\Logs | Remove-Item -Force
		Write-Host -ForegroundColor Yellow `n"$LogsCount log files successfully removed"
		Read-Host
	}
	else {
		Write-Host -ForegroundColor Yellow `n"Log file deletion canceled"
		Read-Host
	}
}
ELSE {
	Write-Host -ForegroundColor Yellow `n"Number of logs ($LogsCount) is below the threshold"
	Read-Host
}
