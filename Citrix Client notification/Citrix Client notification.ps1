# *****************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Check Citrix Client version and notify user to update
# *****************************************************

<#
.SYNOPSIS
This script will check which Citrix client is installed on the endpoint (Platform and version). You define a minimum version, if the clients endpoint version is lower, the user gets
a toast notificaton that the client is out of date (or whatever you want). You can also inform the user that a HTML5 client is in use and that this client isn't supported.
A log for each client gets written to the "Logging" folder (which must exist!)
	
.DESCRIPTION
The script will first find the current session id and the cientname of the user and what client platform/version is used in this session. The display language is determined to display
the notification in the correct language. The toast notification appears longer than the default value (line 112). 
   
.PARAMETER -WindowsClientMin
You can override the predifined versions
- WindowsClientMin "20.12.0.39"
.PARAMETER -MacClientMin
You can override the predifined versions
-MacClientMin "20.12.0.3"
.PARAMETER -LinuxClientMin
You can override the predifined versions
-LinuxClientMin "21.1.0.14"
.PARAMETER -MailButton
This one is mandatory, if you want to give the user the possibility to generate a mail for the support submit "True", otherwise "False"
-MailButton True

.EXAMPLE
Powershell logonscript:
Script Name:
C:\Program Files (x86)\SuL\Scripts\Notifications\Citrix Client notification.ps1
Script parameters:
-WindowsClientMin "20.12.1.42" -MacClientMin "20.12.0.3"

WEM external task:
Path: powershell.exe
Arguments:
-executionpolicy bypass -file "C:\Program Files (x86)\Scripts\Citrix Client notification.ps1"

.NOTES
Attention: Requires the BurntToast Powershell Module! https://github.com/Windos/BurntToast
Use "Install-Module -Name BurntToast" to install the module.
BurntToast needs an AppId to display the notifications, default is Windows Powershell. BurntToast will check the start menu for the shortcut, no message is shown if Powershell cannot be found.
In many cases admins hide the Powershell shortcuts from the start menu, so you have to define your own AppId.
To define you own AppId you have to place a shortcut in the start menu and use this as your AppId. (e.g. a png file). The name of the AppId will be displayed at the bottom of the notification.
To find out how to define the AppID, run "Get-StartApps". You get a list of possible values.
You get more informatiosn about the AppID here https://docs.microsoft.com/en-us/windows/win32/shell/appids and here https://toastit.dev/2018/02/04/burnttoast-appid-installer/.

Place the script in a local folder on the VDA, together with the CWA.png file. Create a folder "Logging" with write permissions for the users. 
Run the script as a logon script or with Citrix WEM external task.

Windows client CR versions: 21.3.1.25 (2103.1), 21.5.0.48 (2105), 21.6.0.47 (2106), 21.8.0.4026 (2108)
Windows client LTSR version: 19.12.3000.6, 19.12.4000.19, 19.12.5000.3
Mac client versions: 21.06.0.31 (2106), 21.07.0.4 (2107), 21.8.1.20 (2108.1)
Linux client versions: 21.4.0.11 (2104), 21.6.0.28 (2106), 21.8.0.40 (2108)

Version:		1.1
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-02-19
Purpose/Change:	
2021-02-20		Inital version
2021-02-21		Added Language, Added BurntToast text
2021-02-22		Added BurntToast text
2021-02-23		Added Linux client
2021-02-28		Added logging
2021-03-04		Added mail button
2021-09-27		Changed client versions
#>

[CmdletBinding()]

param(     
      [Parameter(
	  Mandatory = $false)]
	  [version]$WindowsClientMin = "21.8.0.4026", # define minimum client version here
	       
      [Parameter(
	  Mandatory = $false)]  
      [version]$MacClientMin = "21.8.1.20", # define minimum client version here
	  
	  [Parameter(
	  Mandatory = $false)]  
      [version]$LinuxClientMin = "21.8.0.40", # define minimum client version here

      [Parameter(
      Mandatory = $true)]
      [ValidateNotNull()]
      [ValidateNotNullOrEmpty()]
      [String]$MailButton
)

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

# General variables
$DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)
$Language = [CultureInfo]::InstalledUICulture.Name
$CitrixSessionID = Get-ChildItem -Path "HKCU:\Volatile Environment" -Name
$CitrixClientName = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Client_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Name
[version]$CitrixClientVersion = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Client_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Version

# Citrix Client platform
$ClientProductId=(Get-ItemProperty HKLM:\Software\Citrix\ICA\Session\$CitrixSessionID\Connection -name ClientProductId).ClientproductId
if ($ClientProductId -eq 1) {$ClientPlatform="Windows"}
if ($ClientProductId -eq 81) {$ClientPlatform="Linux"}
if ($ClientProductId -eq 82) {$ClientPlatform="Mac"}
if ($ClientProductId -eq 257) {$ClientPlatform="HTML5"}

# BurntToast variables
$BTAppIcon = New-BTImage -Source "$PSScriptRoot\CWA.png" -AppLogoOverride
$BTAppId = "{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}\SuL\Scripts\Notifications\CWA.png"
$BTAudio = New-BTAudio -Source ms-winsoundevent:Notification.IM
if ($Language -eq "de-DE") {
		$BTText1 = New-BTText -Text "Ihr Citrix Client ist nicht aktuell!"
        $BTText2 = New-BTText -Text "$ClientPlatform Client Version $CitrixClientVersion."
        $BTText3 = New-BTText -Text "Sie finden den aktuellen Client unter https://workspace.app"
	}
	else {
		$BTText1 = New-BTText -Text "Your Citrix Client is out of date!"
        $BTText2 = New-BTText -Text "$ClientPlatform Client Version $CitrixClientVersion."
        $BTText3 = New-BTText -Text "You find the current client on https://workspace.app"
	}
		
if ($ClientPlatform -eq "HTML5") {
	if ($Language -eq "de-DE") {
		$BTText1 = New-BTText -Text "Sie benutzen den Citrix HTML client!"
        $BTText2 = New-BTText -Text "Bitte einen vollwertigen Citrix Client installieren."
        $BTText3 = New-BTText -Text "Sie finden einen aktuellen Client unter https://workspace.app"
	}
	else {
		$BTText1 = New-BTText -Text "You use the Citrix HTML client!"
        $BTText2 = New-BTText -Text "Please install a suitable client for your device."
        $BTText3 = New-BTText -Text "You find a current client on https://workspace.app"
	}
}

$BTBinding = New-BTBinding -Children $BTText1, $BTText2, $BTText3 -AppLogoOverride $BTAppIcon
$BTVisual = New-BTVisual -BindingGeneric $BTBinding
$BTContent = New-BTContent -Visual $BTVisual -Audio $BTAudio -Duration Long
# Mailbutton
if ($MailButton -eq "true") {
    $MailBody = "User: $ENV:username%0D%0AClient: $CitrixClientName%0D%0A$ClientPlatform Client version: $CitrixClientVersion"
    $MailSubject = "Citrix Client check"
    $MailContent = "mailto:helpdesk@domain.com?Subject=$MailSubject&Body=$MailBody"
    $BTButton = New-BTButton -Content "Contact Support" -Arguments $MailContent
    $BTAction = New-BTAction -Buttons $BTButton
    $BTContent = New-BTContent -Visual $BTVisual -Audio $BTAudio -Duration Long -Actions $BTAction
}
New-BTAppId -AppId $BTAppId
	
# Logging
$LogFile = "$PSScriptRoot\Logging\$CitrixClientName-Citrix client check.log"
New-Item $LogFile -ItemType "file" -force | Out-Null
WriteLog "START SCRIPT" $LogFile
WriteLog "$DateTime" $LogFile
WriteLog "Clientname: $CitrixClientName" $LogFile
WriteLog "Platform: $ClientPlatform" $LogFile

# Citrix client platform HTML5
if ($ClientPlatform -eq "HTML5") {
WriteLog "Platform: $ClientPlatform" $LogFile	
Submit-BTNotification -Content $BTContent -AppId $BTAppId	
}

switch ($ClientPlatform)
{
	'Windows'	{
                WriteLog "Minimum client version: $WindowsClientMin" $LogFile
                WriteLog "Current client version: $CitrixClientVersion" $LogFile
	                if ($CitrixClientVersion -lt $WindowsClientMin) {
		                Submit-BTNotification -Content $BTContent -AppId $BTAppId
	                    }
				}
				
	'Mac'		{
				WriteLog "Minimum client version: $MacClientMin" $LogFile
                WriteLog "Current client version: $CitrixClientVersion" $LogFile
	                if ($CitrixClientVersion -lt $MacClientMin) {
		                Submit-BTNotification -Content $BTContent -AppId $BTAppId
	                    }
				}
				
	'Linux'		{
				WriteLog "Minimum client version: $LinuxClientMin" $LogFile
                WriteLog "Current client version: $CitrixClientVersion" $LogFile
	                if ($CitrixClientVersion -lt $LinuxClientMin) {
		                Submit-BTNotification -Content $BTContent -AppId $BTAppId
	                    }
				}
}