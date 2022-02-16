<#
.SYNOPSIS
This script will defrag and shrink the latest merged base PVS vDisk.
https://www.citrix.com/blogs/2015/01/19/size-matters-pvs-ram-cache-overflow-sizing/?_ga=1.24764090.1091830672.1452712354
	
.DESCRIPTION
The script will first find out what the latest merged base disk is (VHDX). After that the vDisk gets defragmented and shrinked.
At the end you will see the vDisk size before and after shrinking.
vDisk can't be in use while executing the script!
	
.EXAMPLE
."Shrink PVS vDisk.ps1"
    
.NOTES
Run as administrator after you create a new merged base disk that isn't in use yet.
Tested with UEFI partitions and standard partititions without system reserved partition.
Sometimes the "detach disk" command from diskpart doesn't work as expected, so the vDisk is still mounted, so the dismount command runs again
after diskpart.
If you want to change the root folder you have to modify the shortcut.

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-16
Purpose/Change:	
2021-01-19		Inital version
2021-10-28		no parameter needed anymore
#>

$ScriptStart = Get-Date

# RunAs Admin
function Use-RunAs 
{    
    # Check if script is running as Administrator and if not elevate it
    # Use Check Switch to check if admin 
     
    param([Switch]$Check) 
     
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()` 
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
         
    if ($Check) { return $IsAdmin }   
      
    if ($MyInvocation.ScriptName -ne "") 
    {  
        if (-not $IsAdmin)  
          {  
            try 
            {  
                $arg = "-WindowStyle Maximized -file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop'  
            } 
            catch 
            { 
                Write-Warning "Error - Failed to restart script elevated"  
                break               
            } 
            exit 
        }  
    }  
} 

Use-RunAs

# Variables
$RootFolder = Split-Path -Path $PSScriptRoot
$Date = Get-Date -UFormat "%d.%m.%Y"
$Log = "$RootFolder\Logs\Shrink PVS vDisk.log"

# Start logging
Start-Transcript $Log | Out-Null

# FUNCTION Get next free drive letter
# ========================================================================================================================================
function Get-NextFreeDriveLetter
{
    [CmdletBinding()]
    param
        (
         [string[]]$ExcludeDriveLetter = ('A-F', 'Z'), # Drives to exclude
         [switch]$Random,
         [switch]$All
        )
    
    $Drives = Get-ChildItem -Path Function:[a-z]: -Name
 
    if ($ExcludeDriveLetter)
        {
         $Drives = $Drives -notmatch "[$($ExcludeDriveLetter -join ',')]"
        }
 
    if ($Random)
        {
         $Drives = $Drives | Get-Random -Count $Drives.Count
        }
 
    if (-not($All))
        {
         foreach ($Drive in $Drives)
            {
             if (-not(Test-Path -Path $Drive))
                {
                 return $Drive
                }
            }   
        }
    else
	    {
	     Write-Host $Drives | Where-Object {-not(Test-Path -Path $_)}
	    }
}
# ========================================================================================================================================


# FUNCTION Convert number to human readable format
# ========================================================================================================================================
function DisplayInBytes($num) 
{
    $suffix = "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
    $index = 0
    while ($num -gt 1kb) 
    {
        $num = $num / 1kb
        $index++
    } 

    "{0:N1} {1}" -f $num, $suffix[$index]
}
# ========================================================================================================================================


# FUNCTION Mount VHDX
# ========================================================================================================================================
function vhdmount($v)
{
	try
	{
	 $VHDNumber = Mount-DiskImage -ImagePath "$vdiskpath\$vhd" -NoDriveLetter -Passthru -ErrorAction Stop | Get-DiskImage
	 $partition = (Get-Partition -DiskNumber $VHDNumber.Number | Where-Object {$_.Type -eq "Basic" -or $_.Type -eq "IFS"})
	 Set-Partition -PartitionNumber $partition.PartitionNumber -DiskNumber $VHDNumber.Number -NewDriveLetter $FreeDriveLetter
	 return "0"
	} catch
	 {
	 return "1"
	 }
}
# ========================================================================================================================================


# FUNCTION Dismount VHDX
# ========================================================================================================================================
function vhddismount($v)
{
	try
	{
	 Dismount-DiskImage -ImagePath "$vdiskpath\$vhd" -ErrorAction stop
     	 return "0"
    	} catch
     	 {
      	  return "1"
     	 }
}
# ========================================================================================================================================


# Scriptblock for defragmenting the PVS vDisk
# ========================================================================================================================================
# Check if PVS SnapIn is available
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
	}

Write-Host -ForegroundColor Yellow "Shrink PVS vDisk" `n

# Get PVS SiteName
$SiteName = (Get-PvsSite).SiteName

# Get all vDisks
$AllvDisks = Get-PvsDiskInfo -SiteName $SiteName

# Add property "ID" to object
$ID = 1
$AllvDisks | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name "ID" -Value $ID 
    $ID += 1
    }

# Show menu to select vDisk
Write-Host "Available vDisks:" `n 
$ValidChoices = 1..($AllvDisks.Count)
$Menu = $AllvDisks | ForEach-Object {(($_.ID).toString() + "." + " " +  $_.Name + " " + "-" + " " + "Storename:" + " " + $_.Storename)}
$Menu | Out-Host
Write-Host
$vDisk = Read-Host -Prompt 'Select vDisk to shrink'

$vDisk = $AllvDisks | Where-Object {$_.ID -eq $vDisk}
if ($vDisk.ID -notin $ValidChoices) {
    Write-Host -ForegroundColor Red "Selected vDisk not found, aborting!"
	Read-Host "Press any key to exit"
    BREAK
    }

$vDiskName = $vDisk.Name
$StoreName = $vDisk.StoreName

$LatestVersion = (Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName).Version | Select-Object -First 1
$MergedBaseVersion = ((Get-PvsDiskVersion -DiskLocatorName $vDiskName -SiteName $SiteName -StoreName $StoreName) | Where-Object {$_.Type -eq '4' -and $_.Access -eq 0} | select-Object -First 1)
IF ($MergedBaseVersion.Version -ne $LatestVersion) {
    Write-Host -ForegroundColor Red "No actual merged base version found, you select an older merged base version, aborting!"
    Read-Host "Press any key to exit"
    BREAK
    }
$vhd = $MergedBaseVersion.DiskFileName
$vdiskpath  = (Get-PvsStore -StoreName "$StoreName").Path

# $vhdsizebefore = (Get-ChildItem "$vdiskpath" -Recurse | Where-Object {$_.fullname -like "*.vhdx"} | Sort-Object LastWriteTime | Sort-Object -Descending  | Select-Object -First 1 @{n='Size';e={DisplayInBytes $_.length}}).Size
$vhdsizebefore = "{0:N0} MB" -f (((Get-ChildItem "$vdiskpath" -Recurse | Where-Object {$_.fullname -like "*.vhdx"} | Sort-Object LastWriteTime | Sort-Object -Descending  | Select-Object -First 1) | measure Length -s).Sum /1MB)

# Get next free drive
$FreeDrive = Get-NextFreeDriveLetter 
$FreeDriveLetter = $FreeDrive -replace ".$" # cut ":" 

# Mounting vDisk
$mount = vhdmount -v $vhd
if ($mount -eq "1")
    {
     Write-Host "Mounting vDisk: $vhd failed"
	 Read-Host "Press any key to exit"
     BREAK
    }
Write-Host `n"Mounting vDisk: $vhd"`n

# Defrag
Write-Host "Running defrag on vDisk: $vhd"`n
Start-Sleep 3
Start-Process "defrag.exe" -ArgumentList "$FreeDrive /X /G /H /U /V" -wait
Start-Sleep 3

# Sdelete
Write-Host "Running sdelete on vDisk: $vhd"`n
Start-Process "$PSScriptRoot\sdelete64.exe" -ArgumentList "-z -c $FreeDrive" -wait
Start-Sleep 3

# Dismounting vDisk
$dismount = vhddismount -v $vhd
if ($dismount -eq "1")
    {
     Write-Host "Failed to dismount vDisk: $vhd"
	 Read-Host "Press any key to exit"
     BREAK
    }
Write-Host "Dismounting vDisk: $vhd"`n
Write-Host "Defrag of vDisk: $vhd finished"`n

# ========================================================================================================================================


# Scriptblock for shrinking the PVS vDisk
# ========================================================================================================================================
# Generate tempfile for diskpart commands
$tempfile = ($env:TEMP + "\diskpart.txt")
		
# Delete temp diskpart file if exists
Write-Host "Delete temp diskpart file if exists"`n
remove-item $tempfile -ea silentlycontinue

# Generate Diskpart commands and create file
Write-Host "Generate Diskpart commands and creating file"`n
Add-Content $tempfile ("select vdisk file=" + '"' + "$vdiskpath\$vhd" + '"')
Add-Content $tempfile "attach vdisk readonly"
Add-Content $tempfile "compact vdisk"
Add-Content $tempfile "detach vdisk"
Add-Content $tempfile "exit"

# Generate diskpart command
$diskpartcommand = ("diskpart.exe /s " + $tempfile)
# Execute diskpart
Write-Host "Shrinking vDisk: $vhd"`n
$diskpartcommand | cmd.exe 

# Dismounting vDisk after shrinking if diskpart can't detach the vDisk
$dismount = vhddismount -v $vhd
if ($dismount -eq "1")
    {
     Write-Host "Failed to dismount vDisk: $vhd"
	 Read-Host "Press any key to exit"
     BREAK
    }
Write-Host "Dismounting vDisk: $vhd"`n


# Compare PVS vDisk size
# $vhdsizeafter = (Get-ChildItem "$vdiskpath" -Recurse | Where-Object {$_.fullname -like "*.vhdx"} | Sort-Object LastWriteTime | Sort-Object -Descending  | Select-Object -First 1 @{n='Size';e={DisplayInBytes $_.length}}).Size
$vhdsizeafter = "{0:N0} MB" -f (((Get-ChildItem "$vdiskpath" -Recurse | Where-Object {$_.fullname -like "*.vhdx"} | Sort-Object LastWriteTime | Sort-Object -Descending  | Select-Object -First 1) | measure Length -s).Sum /1MB)
Write-Host "Size of vDisk: $vhd before shrinking: $vhdsizebefore - Size of vDisk: $vhd after shrinking: $vhdsizeafter"`n
# ========================================================================================================================================

Write-Host -ForegroundColor Green "Ready! vDisk $vDiskName successfully shrinked, check logfile $log" `n

$ScriptEnd = Get-Date
$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds"

# Stop Logging
Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log
Move-Item $Log "Shrink PVS vDisk-$vDiskName-$Date.log" -Force

Read-Host `n "Press any key to exit"