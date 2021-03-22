# MS Teams optimization check
First of all, I'm no powershell expert, so I'm sure there is room for improvements!

This script will check if the MS Teams Citrix Optimization is working after starting Teams.  After 25 sec. (launch time of Teams) the user gets a toast notificaton if the optimization is NOT active. A log for each client gets written to the "Logging" folder (which must exist with write permissions for users!). You need to create a shortcut for the user to launch the script. Replace the shortcut with the standard Teams shortcut.
The script will first find the current session ID and the clientname of the user and what client platform/version is used in this session. The display language is determined to display the notification in the correct language. The toast notification appears longer than the default value (line 140). 

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

Place the script in a local folder on the VDA, together with the Teams.png file and a "Logging" folder with write permissions for the users. Run the script as a shortcut (replace with MS Teams shortcut)  

## Execution
Replace Teams shortcut with a custom shortcut.

Example for WEM action:
Command line:
powershell.exe

Working directory:
C:\Program Files (x86)\Microsoft\Teams\current

Parameters:
-executionpolicy bypass -windowstyle hidden -file "C:\Program Files (x86)\Scripts\Check Teams optimization.ps1"

## Logging
A log for each client gets written to the "Logging" folder (which must exist!). The log file will be overwritten.

## Examples
![Teams](https://github.com/Mohrpheus78/Citrix/blob/main/Teams%20Optimization%20check/Images/Teams%201.png)
![Notification](https://github.com/Mohrpheus78/Citrix/blob/main/Teams%20Optimization%20check/Images/Teams%202.png)


