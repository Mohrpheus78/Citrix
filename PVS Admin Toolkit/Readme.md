# Citrix PVS Admin Toolkit
Useful scripts for your Citrix PVS environment, manage PVS with powershell. Put all files and folders to "C:\Program Files (x86)\PVS Admin Toolkit" on your PVS servers and start the main script (PVS Admin Toolkit.ps1). You can launch the other scripts from the systray icon. If you want to change the root folder of the scripts, you have to modify the shortcuts.

1. Configure your hypervisor, start "Hypervisor configuration" from the PVS Toolkit Configuration menu. Enter a IP address or hostname of your Citrix Xen host, VMWare vCenter/ESXi or Nutanix cluster.
2. Configure your PVS environment, start "PVS configuration" from the PVS Toolkit Configuration menu and answer the queastions. 
All values will be stored in XML files to be used as variables. Credentials will be encrypted and can only be used by the same user again. 

## vDisk Maintenance
The script will create new vDisk versions and promote these versions to test or production mode.

## Windows Update
The script will automaticcaly install Windows Updates in the vDisk you selected, a new vDisk version will be created and the PVS maintenance device will be booted, after that Windows Updates will be installed and the VM is sealed and shut down with BIS-F if you use it. You can also create scheduled tasks to fully automate this process and install Windows Updates while you sleep :-). 
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