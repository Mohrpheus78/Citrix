# Compact PVS vDisk

The script will first find out what the latest merged base disk is (VHDX). After that the vDisk gets defragmented and shrinked. At the end you will see the vDisk size before and after shrinking. vDisk can't be in use while executing the script!

## Parameter
-vdiskpath "Path to PVS vDisks"
	
## Example
."Compact PVS vDisk.ps1" -vdiskpath "D:\vDisks\CVAD"
    
## Notes
Run as administrator after you create a new merged base disk that isn't in use yet. Tested with UEFI partitions and standard partititions without system reserved partition. Sometimes the "detach disk" command from diskpart doesn't work as expected, so the vDisk is still mounted, so the dismount command runs again after diskpart