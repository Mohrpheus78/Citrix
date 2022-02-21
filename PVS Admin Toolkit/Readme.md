# Citrix PVS Admin Toolkit
Useful scripts for your Citrix PVS environment, manage PVS with powershell.
Put all files and folders to "C:\Program Files (x86)\PVS Admin Toolkit" on your PVS servers, start the main script (PVS Admin Toolkit.ps1) and launch all the other tasks from the systray icon. If you want to change the root folder of the cripts, you have to modify the shortcuts.

1. Configure your hypervisor, start "Hypervisor configuration" from the PVS Toolkit Configuration menu. Enter a IP address or hostname of your Citrix Xen host, VMWare vCenter/ESXi or Nutanix cluster and enter valid admin credentials to connect to the hypervisor, Nutanix is still in beta phase!
2. Launch "PVS configuration" from the PVS Toolkit Configuration menu to configure your PVS environment
3. Install the Powershell modules for your choosen hypervisor on your PVS server (Citrix XenServer SDK, VMWare Power.CLI or Nutanix.CLI )
4. If you want to install Windows Updates inside your vDisk, first install the "PSWindowsUpdate" Powershell module on your PVS master
5. If you want to use the Evergreen script from Manuel Winkel (deyda) you have to configure a file share which contains the script and the software and an install list for your maintenance device. Save the list in the following format: "NAME_OF_MASTER-Install.txt". For more information how to use Evergreen check Manuel's website: https://www.deyda.net/index.php/de/evergreen-script-de/

All values will be stored in XML files to be used as variables. Credentials will be encrypted and can only be used by the same user again. 

## vDisk Maintenance
The script will create a new vDisk version and promote this version to test or production mode.

## Windows Update
The script will automatically install Windows Updates in the vDisk you selected, a new vDisk version will be created and the PVS maintenance device will be booted, after that Windows Updates will be installed and the VM is sealed and shut down with BIS-F if you use it. You can also create scheduled tasks to fully automate this process and install Windows Updates while you sleep :-). 

## Evergreen
The script will automatically install software and  updates in the vDisk you selected with the great Evergreen script frpom Manuel Winkel. A new vDisk version will be created and the PVS maintenance device will be booted, after that software will be installed from a list (TXT file) and the VM is restarted, sealed and shut down with BIS-F if you use it. You can also create scheduled tasks to fully automate this process and use the Evergreen script while you sleep :-). 
## vDisk Shrink
The script will find all available vDisks and next find out what the latest merged base disk is (VHDX). After that the vDisk gets defragmented and shrinked. At the end you will see the vDisk size before and after shrinking. vDisk can't be in use while executing the script! Very useful after cleaning WinSXS folder with BIS-F for example. 

## vDisk Documentation
This script will generate a HTML report of your current vDisk versions and place it in a folder you define.

## vDisk Export
This script will generate a XML export of your vDisk in the same folder.

## vDisk Replication
This script will replicate a PVS vDisk with all version files to all other PVS servers that host this vDisk.

## vDisk Merge
This script will merge a PVS vDisk you choose.

# Example

![Toolkit](https://github.com/Mohrpheus78/Citrix/blob/main/PVS%20Admin%20Toolkit/PVSAdminToolkit.png)
![Toolkit](https://github.com/Mohrpheus78/Citrix/blob/main/PVS%20Admin%20Toolkit/WU.png)