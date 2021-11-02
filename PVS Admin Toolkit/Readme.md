# Citrix PVS Admin Toolkit
Useful scripts for your Citrix PVS environment, manage PVS with powershell.

## vDisk Shrink
The script will find all available vDisks and next find out what the latest merged base disk is (VHDX). After that the vDisk gets defragmented and shrinked. At the end you will see the vDisk size before and after shrinking. vDisk can't be in use while executing the script!

## vDisk Documentation
This script will generate a HTML report of your current vDisk versions and place it in a folder you define.

## vDisk Export
This script will generate a XML export of your vDisk in the same folder.

## vDisk Replication
This script will replicate a PVS vDisk with all version files to all other PVS servers that host this vDisk.

## vDisk Merge
This script will merge a PVS vDisk you choose.

## vDisk Maintenance
The script will create new vDisk versions and promote these versions to test or production mode.

![Toolkit](https://github.com/Mohrpheus78/Citrix/blob/main/PVS%20Admin%20Toolkit/PVSAdminToolkit.png)