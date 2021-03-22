# *****************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Check Citrix Client version and notify user to update
# *****************************************************

<#
.SYNOPSIS
This script will check if the MS Teams Citrix Optimization is working after starting Teams.  After 25 sec. (launch time of Teams) the user gets a toast notificaton if the optimization is NOT active.
A log for each client gets written to the "Logging" folder (which must exist with write permissions for users!)
You need to create a shortcut for the user to launch the script. Replace the shortcut with the standard Teams shortcut.
	
.DESCRIPTION
The script will first find the current session ID and the clientname of the user and what client platform/version is used in this session. The display language is determined to display
the notification in the correct language. The toast notification appears longer than the default value (line 138). 
   
.PARAMETER
No parameter required

.EXAMPLE
WEM action
Command line:
powershell.exe

Working directory:
C:\Program Files (x86)\Microsoft\Teams\current

Parameters:
-executionpolicy bypass -windowstyle hidden -file "C:\Program Files (x86)\Scripts\Check Teams optimization.ps1"


.NOTES
Attention:
Requires a shortcut for the users to launch Teams (see information above)
Requires the BurntToast Powershell Module! https://github.com/Windos/BurntToast
Use "Install-Module -Name BurntToast" to install the module.
BurntToast needs an AppId to display the notifications, default is Windows Powershell. BurntToast will check the start menu for the shortcut, no message is shown if Powershell cannot be found.
In many cases admins hide the Powershell shortcuts from the start menu, so you have to define your own AppId.
To define you own AppId you have to place a shortcut in the start menu and use this as your AppId. The name of the AppId will be displayed at the bottom of the notification.
To find out how to define the AppID, run "Get-StartApps". You get a list of possible values.
In this case I use MS Teams as AppID, a shortcut to this powershell script must exist in the start menu!
You get more information about the AppID here https://docs.microsoft.com/en-us/windows/win32/shell/appids and here https://toastit.dev/2018/02/04/burnttoast-appid-installer/.
 
Place the script in a local folder on the VDA, together with the Teams.png file. Create a folder "Logging" with write permissions for the users. 


Version:		1.1
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-02-19
Purpose/Change:	
2021-03-01		Inital version
2021-03-02		Added notes
2021-03-04		Added notes
2021-03-16		Changed notes
#>

#====================================================================================
Function WriteLog {
	
[CmdletBinding()]

Param( 
      [Parameter(
	  Mandatory=$true, Position = 1)]
	  [AllowEmptyString()][String]$Text,
      [Parameter(
	  Mandatory=$true, Position = 2)]
	  [AllowEmptyString()][String]$LogFile
)
 
begin {}
 
process {
		 if ( $Text -eq "" ) {
			Add-Content $LogFile -value ("") # Write an empty line
        } Else {
			Add-Content $LogFile -value ($Text)
        }
	}

end {}
}
#====================================================================================

# Lanch MS Teams and wait 25 seconds to check the status
Start-Process -FilePath "${env:ProgramFiles(x86)}\Microsoft\Teams\current\Teams.exe"
Start-Sleep -s 25

# General variables
$DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)
$Language = [CultureInfo]::InstalledUICulture.Name
$CitrixSessionID = Get-ChildItem -Path "HKCU:\Volatile Environment" -Name
$CitrixClientName = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Client_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Name
[version]$CitrixClientVersion = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Client_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Version
[version]$WindowsClientMin = "19.7.0.15"
[version]$MacClientMin = "20.12.0.3"
[version]$LinuxClientMin = "20.06.0.15"
$TeamsOptimization = (Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_VirtualChannel_Webrtc_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID}) | Select-Object -ExpandProperty Component_VersionTypescript
$TeamsVersion = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Teams Machine*"}).DisplayVersion

# Citrix Client platform
$ClientProductId=(Get-ItemProperty HKLM:\Software\Citrix\ICA\Session\$CitrixSessionID\Connection -name ClientProductId).ClientproductId
if ($ClientProductId -eq 1) {$ClientPlatform="Windows"}
if ($ClientProductId -eq 81) {$ClientPlatform="Linux"}
if ($ClientProductId -eq 82) {$ClientPlatform="Mac"}
if ($ClientProductId -eq 257) {$ClientPlatform="HTML5"}

# BurntToast variables
$BTAppIcon = New-BTImage -Source "$PSScriptRoot\Teams.png" -AppLogoOverride
$BTAppId = "Microsoft.AutoGenerated.{3AE24D7D-8256-0005-FE22-8D36C3639CCC}" # MS Teams shortcut for this script
$BTAudio = New-BTAudio -Source ms-winsoundevent:Notification.IM
if ($Language -eq "de-DE") {
		$BTText1 = New-BTText -Text "MS Teams ist NICHT optimiert!"
        $BTText2 = New-BTText -Text "Citrix Client Version $CitrixClientVersion ($ClientPlatform)."
		$BTText3 = New-BTText -Text "Bitte IT Helpdesk kontaktieren"
	}
	else {
		$BTText1 = New-BTText -Text "MS Teams is NOT optimized!"
        $BTText2 = New-BTText -Text "Citrix client version $CitrixClientVersion ($ClientPlatform)."
		$BTText3 = New-BTText -Text "Please contact IT Helpdesk"
	}

# Client platform
switch ($ClientPlatform)
{
	'Windows'	{
				if ($CitrixClientVersion -lt $WindowsClientMin) {
				$BTText3 = New-BTText -Text "Your Citrix client is not supported"}
				}
				
	'Mac'		{
				if ($CitrixClientVersion -lt $MacClientMin) {
				$BTText3 = New-BTText -Text "Your Citrix client is not supported"}
				}
				
	'Linux'		{
				if ($CitrixClientVersion -lt $LinuxClientMin) {
				$BTText3 = New-BTText -Text "Your Citrix client is not supported"}
				}
}

$BTBinding = New-BTBinding -Children $BTText1, $BTText2, $BTText3 -AppLogoOverride $BTAppIcon
$BTVisual = New-BTVisual -BindingGeneric $BTBinding
$BTContent = New-BTContent -Visual $BTVisual -Audio $BTAudio -Duration Long
New-BTAppId -AppId $BTAppId
	
# Logging
$LogFile = "$PSScriptRoot\Logging\$CitrixClientName-MS Teams Optimization.log"
New-Item $LogFile -ItemType "file" -force | Out-Null
WriteLog "START SCRIPT" $LogFile
WriteLog "$DateTime" $LogFile
WriteLog "Clientname: $CitrixClientName" $LogFile
WriteLog "Platform: $ClientPlatform" $LogFile
WriteLog "Current client version: $CitrixClientVersion" $LogFile

# BurntToast Notification if NOT optimized!
if ($TeamsOptimization -eq "0.0.0.0") {
	Submit-BTNotification -Content $BTContent -AppId $BTAppId
	WriteLog "Teams NOT optimized " $LogFile
}
else	{
		WriteLog "Teams optimized " $LogFile
}


