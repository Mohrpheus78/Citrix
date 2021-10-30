# Shrink PVS vDisk
The script will find all available vDisks and next find out what the latest merged base disk is (VHDX). After that the vDisk gets defragmented and shrinked. At the end you will see the vDisk size before and after shrinking. vDisk can't be in use while executing the script!

## Example
Launch on PVS server: ."Shrik PVS vDisk.ps1" or use the CMD file
    
## Notes
Run as administrator after you create a new merged base disk that isn't in use yet. Tested with UEFI partitions and standard partititions without system reserved partition. Sometimes the "detach disk" command from diskpart doesn't work as expected, so the vDisk is still mounted, so the dismount command runs again after diskpart
Place the folder with all files inside the folder "C:\Program Files (x86)\Scripts", so that you can use the shortcut.

## Examples
![Versions](https://github.com/Mohrpheus78/Citrix/blob/main/PVS/vDisk%20Shrink/Images/PVS-Shrink.png)