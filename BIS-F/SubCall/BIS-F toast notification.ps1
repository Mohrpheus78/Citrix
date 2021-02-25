# ****************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Toast notification if BIS-F personalization is ready
# 2/2
# ****************************************************

<#
.SYNOPSIS
This script is part of another script (BIS-F Personalization ready.ps1 )that calls this one. This script will show a toast notificaton to the currently logged in user,
that BIS-F personalizationis ready. Use with Base Image Script Framework, place the script in a subfolder called SubCall in the folder
"C:\Program Files (x86)\Base Image Script Framework (BIS-F)\Framework\SubCall\Personalization\Custom"
	
.DESCRIPTION
The script will first find out what locale settings the user has configured and then show the toast notification.
   
.NOTES
This script is part of the script "BIS-F Personalization ready.ps1" that calls this script.
#>


# Variables
$Language = (Get-Culture).Name

# Notification
Add-Type -AssemblyName System.Windows.Forms 
$global:balloon = New-Object System.Windows.Forms.NotifyIcon
$path = (Get-Process -id $pid).Path
$balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path) 
$balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
IF ($Locale -eq "de-DE") {
	$balloon.BalloonTipText = 'Die Personalisierung ist abgeschlossen!'} # adjust text
	ELSE {
	$balloon.BalloonTipText = 'Personalization finished!'} # adjust text here
$balloon.BalloonTipTitle = "Base Image Script Framework" 
$balloon.Visible = $true 
$balloon.ShowBalloonTip(15000) # adjust sec.