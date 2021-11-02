# PVS vDisk merge
The purpose of the script is to merge vDisk versions to a merged base and promote the new base to production. After that the vDisk will be replicated to all other PVS servers in 
the site that hosts this vDisk if you want. You can also generate a HTML report of your vDisk versions. In this case you also have to place the "vDisk Documentation" folder in the scripts folder.

## Example
& '.\Merge PVS vDisk.ps1' or use shortcut.

## NOTES
If you want to change the root folder you have to modify the shortcut.

## Examples
![Versions](https://github.com/Mohrpheus78/Citrix/blob/main/PVS%20Admin%20Toolkit/vDisk%20Merge/Images/PVS-merge.png)