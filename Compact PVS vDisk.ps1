# ****************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Defrag and shrink PVS vDisk
# ****************************************************

<#
.SYNOPSIS
This script will defrag and shrink the latest merged base PVS vDisk.
https://www.citrix.com/blogs/2015/01/19/size-matters-pvs-ram-cache-overflow-sizing/?_ga=1.24764090.1091830672.1452712354
	
.DESCRIPTION
The script will first find out what the latest merged base disk is (VHDX). After that the vDisk gets defragmented and shrinked.
At the end you will see the vDisk size before and after shrinking.
vDisk can't be in use while executing the script!

.PARAMETER vdiskpath
-vdiskpath "Path to PVS vDisks"
	
.EXAMPLE
."Compact PVS vDisk.ps1" -vdiskpath "D:\vDisks\CVAD"
    
.NOTES
Run as administrator after you create a new merged base disk that isn't in use yet.
Tested with UEFI partitions and standard partititions without system reserved partition
#>


[CmdletBinding()]

param
    (
     # Path to PVS VHDX files
     [Parameter(Mandatory = $true)]
     [ValidateNotNull()]
     [ValidateNotNullOrEmpty()]
     [String]$vdiskpath
    )
	
# FUNCTION Logging
# ========================================================================================================================================
function DS_WriteLog
{
	Param
		( 
		 [Parameter(Mandatory=$true, Position = 0)][ValidateSet("I","S","W","E","-",IgnoreCase = $True)][String]$InformationType,
		 [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text,
		 [Parameter(Mandatory=$true, Position = 2)][AllowEmptyString()][String]$LogFile
		)
 
    begin
    {
    }
 
    process
    {
     $DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)
     if ( $Text -eq "" )
     	{
         Add-Content $LogFile -value ("") # Write an empty line
	}
     Else
	{
	 Add-Content $LogFile -value ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
	}
    }
 
    end
    {
    }
}


# Logging

# Custom variables [edit]
$BaseLogDir = "$PSScriptRoot"				# [edit] add the location of your log directory here
$LogName = "Compact PVS vDisk" 		   		# [edit] enter the display name of the log
$LogFileName = ("$($LogName).log")
$LogFile = Join-path $BaseLogDir $LogFileName
# Create new log file (overwrite existing one)
New-Item $LogFile -ItemType "file" -force | Out-Null
DS_WriteLog "I" "START SCRIPT - $LogName" $LogFile
DS_WriteLog "-" "" $LogFile
# ========================================================================================================================================


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
	     Write-Output $Drives | Where-Object {-not(Test-Path -Path $_)}
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


# Do you run the script as admin?
# ========================================================================================================================================
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

if ($myWindowsPrincipal.IsInRole($adminRole))
   {
    # OK, runs as admin
    Write-Verbose "OK, script is running with Admin rights" -Verbose
    Write-Output ""
   }

else
   {
    # Script doesn't run as admin, stop!
    Write-Verbose "Error! Script is NOT running with Admin rights!" -Verbose
    BREAK
   }
# ========================================================================================================================================


# Scriptblock for defragmenting the PVS vDisk
# ========================================================================================================================================
# Get latest merged vDisk and vDisk Size
$vhd = (Get-ChildItem "$vdiskpath" -Recurse | Where-Object {$_.fullname -like "*.vhdx"} | Sort-Object LastWriteTime -Descending | Select-Object -First 1).name
$vhdsizebefore = (Get-ChildItem "$vdiskpath" -Recurse | Where-Object {$_.fullname -like "*.vhdx"} | Sort-Object LastWriteTime | Sort-Object -Descending  | Select-Object -First 1 @{n='Size';e={DisplayInBytes $_.length}}).Size

# Get next free drive
$FreeDrive = Get-NextFreeDriveLetter 
$FreeDriveLetter = $FreeDrive -replace ".$" # cut ":" 

# Mounting vDisk
$mount = vhdmount -v $vhd
if ($mount -eq "1")
    {
     DS_WriteLog "E" "Mounting vDisk: $vhd failed" $LogFile
     Write-Output "Mounting vDisk: $vhd failed"
     break
    }
DS_WriteLog "I" "Mounting vDisk: $vhd" $LogFile
Write-Output "Mounting vDisk: $vhd"
Write-Output ""

# Defrag
DS_WriteLog "I" "Running defrag on vDisk: $vhd" $LogFile
Write-Output "Running defrag on vDisk: $vhd"
try {
Start-Sleep 3
Start-Process "defrag.exe" -ArgumentList "$FreeDrive /H /U /V"
Start-Sleep 3
} catch {
DS_WriteLog "E" "An error occured while running defrag (error: $($Error[0]))" $LogFile       
}
DS_WriteLog "-" "" $LogFile
Write-Output ""

# Dismounting vDisk
$dismount = vhddismount -v $vhd
if ($dismount -eq "1")
    {
     DS_WriteLog "E" "Failed to dismount vDisk: $vhd" $LogFile
     Write-Output "Failed to dismount vDisk: $vhd"
     BREAK
    }
DS_WriteLog "I" "Dismounting vDisk: $vhd" $LogFile
Write-Output "Dismounting vDisk: $vhd"
Write-Output ""
DS_WriteLog "I" "Defrag of vDisk: $vhd finished" $LogFile
Write-Output "Defrag of vDisk: $vhd finished"

# ========================================================================================================================================


# Scriptblock for shrinking the PVS vDisk
# ========================================================================================================================================
# Generate tempfile for diskpart commands
$tempfile = ($env:TEMP + "\diskpart.txt")
		
# Delete temp diskpart file if exists
DS_WriteLog "I" "Delete temp diskpart file if exists" $LogFile
Write-Output "Delete temp diskpart file if exists"
Write-Output ""
try {
remove-item $tempfile -ea silentlycontinue
} catch {
DS_WriteLog "E" "An error occured while deleting temp file for diskpart commands (error: $($Error[0]))" $LogFile       
}

# Generate Diskpart commands and create file
DS_WriteLog "I" "Generate Diskpart commands and creating file" $LogFile
Write-Output "Generate Diskpart commands and creating file"
Write-Output ""
try {
Add-Content $tempfile ("select vdisk file=" + '"' + "$vdiskpath\$vhd" + '"')
Add-Content $tempfile "attach vdisk readonly"
Add-Content $tempfile "compact vdisk"
Add-Content $tempfile "detach vdisk"
Add-Content $tempfile "exit"
} catch {
DS_WriteLog "E" "An error occured while generating diskpart commands and creating file (error: $($Error[0]))" $LogFile       
}

# Generate diskpart command
$diskpartcommand = ("diskpart.exe /s " + $tempfile)
# Execute diskpart
DS_WriteLog "I" "Shrinking vDisk: $vhd" $LogFile
Write-Output "Shrinking vDisk: $vhd"
Write-Output ""
try {
$diskpartcommand | cmd.exe | Out-Null
} catch {
DS_WriteLog "E" "An error occured while shrinking vDisk: $vhd (error: $($Error[0]))" $LogFile       
}

# Compare PVS vDisk size
$vhdsizeafter = (Get-ChildItem "$vdiskpath" -Recurse | Where-Object {$_.fullname -like "*.vhdx"} | Sort-Object LastWriteTime | Sort-Object -Descending  | Select-Object -First 1 @{n='Size';e={DisplayInBytes $_.length}}).Size
DS_WriteLog "I" "Size of vDisk: $vhd before shrinking: $vhdsizebefore - Size of vDisk: $vhd after shrinking: $vhdsizeafter" $LogFile
Write-Output "Size of vDisk: $vhd before shrinking: $vhdsizebefore - Size of vDisk: $vhd after shrinking: $vhdsizeafter"
# ========================================================================================================================================
