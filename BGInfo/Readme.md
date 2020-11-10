# BGInfo Powershell script and template

The package contains the BGInfo64.exe a BGI template file and two powershell scripts. 
The purpose of the scripts is to determine values, e.g. the size of the FSLogix container or the codec currently used in the Citrix session. These values are written into a specific registry key, which in turn is stored and displayed in the bginfo template.
You can of course adapt and expand the scripts. The path to the files must be adapted in the scripts.
You can display the information as a background image or as a tray icon in the systray which is displayed when required. The parameters for this differ in the two scripts.

![1](https://github.com/Mohrpheus78/Citrix/blob/main/BGInfo/Images/BGInfo-Taskbar.png)