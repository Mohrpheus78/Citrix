# Citrix client notification
First of all, I'm no powershell expert, so I'm sure there is room for improvements!

This script will check which Citrix client is installed on the endpoint (Platform and version). You define a minimum client version and if the clients endpoint version is lower, the user gets a toast notificaton that the client is out of date (or whatever you want). You can also inform the user that a HTML5 isn't supported.  
The script will first find the current session id of the user and what client platform/version is used inside this session. The display language is determined to display the notification in the correct language. The toast notification appears longer than the default vaulue (line 83). You can also change this value to "Short".

## How To
Attention: Requires the BurntToast Powershell Module! https://github.com/Windos/BurntToast  
Use
```
Install-Module -Name BurntToast
```
to install the module on your Citrix VDA.  

BurntToast needs an AppId to display the notifications, default is Windows Powershell. BurntToast will check the start menu for the shortcut, no message is shown if Powershell cannot be found.
The script runs in the user context and in many cases admins hide the Powershell shortcuts from the start menu, so you have to define your own AppId.
To define you own AppId you have to place a shortcut in the start menu and use this as your AppId. (e.g. a png file). The name of the AppId will be displayed at the bottom of the notification.
To find out how to define the AppID, run
```
Get-StartApps
```
You get a list of possible values. Here you get more informations about the AppID:  
https://docs.microsoft.com/en-us/windows/win32/shell/appids  
https://toastit.dev/2018/02/04/burnttoast-appid-installer/  

Place the script in a local folder on the VDA, together with the CWA.png file and a "Logging" folder with write permissions for the users. Run the script as a logon script or with Citrix WEM external task.  

You can override the versions with these parameters:  
-WindowsClientMin "21.02.0.29" -MacClientMin "20.12.0.3" -LinuxClientMin "21.1.0.14"  

In a RDS environment you should configure the following group policies if you run logon scripts:  

**Administrative Templates > Computer Configuration**  
*System/Group Policy*  
Allow asynchronous user Group Policy processing when logging on through Remote Desktop Services: Enabled  

*System/Logon*  
Always wait for the network at computer startup and logon: Disabled  

*System/Scripts*  
Run startup scripts asynchronously: Disabled  
Run Windows PowerShell scripts first at user logon, logoff: Enabled  

## Possible Citrix WorkspaceApp versions
Of course there are more version, these are examples!
##### Windows client CR versions
20.9.6.34 (2009.6), 20.10.0.20 (2010), 20.12.0.39 (2012), 20.12.1.42 (2012.1), 21.02.0.25 (2102)
##### Windows client LTSR version
19.12.3000.6 (19.12.3000.6)
##### Mac client versions
20.07.0.6 (2007), 20.08.0.3 (2008), 20.9.0.17 (2009), 20.10.0.16 (2010), 20.12.0.3 (2012), 21.02.0.29 (2102)
##### Linux client versions
20.9.0.15 (2009), 20.10.0.6 (2010), 21.1.0.14 (2011), 20.12.0.12 (2012)

## BurntToast parameters
- $BTAppIcon defines the icon that will be used for the notification.
- $BTAppID defines the AppID (must be present in the users start menu). You can use a dummy, but make sure you place a shortcut in the start menu first.
- $BTAudio defines the sound (https://docs.microsoft.com/en-us/uwp/schemas/tiles/toastschema/element-audio)
- Of course you can change the notification text, just change the $BTText1, $BTText2 and $BTText3 variables. 
You can also change the language with the $Language variable. 

## Execution
- Powershell logonscript  
Script Name:  
C:\Program Files (x86)\SuL\Scripts\Notifications\Citrix Client notification.ps1  
Script parameters:  
-WindowsClientMin "20.12.1.42" -MacClientMin "20.12.0.3"  

- WEM external task  
Path: powershell.exe  
Arguments:  
-executionpolicy bypass -file "C:\Program Files (x86)\Scripts\Citrix Client notification.ps1"  

## Logging
A log for each client gets written to the "Logging" folder (which must exist!). The log file will be overwritten.

## Examples
![HTML client](https://github.com/Mohrpheus78/Citrix/blob/main/Citrix%20Client%20notification/Images/HTML.png)
![MAC client](https://github.com/Mohrpheus78/Citrix/blob/main/Citrix%20Client%20notification/Images/Mac.png)
