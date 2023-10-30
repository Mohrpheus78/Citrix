<#
.SYNOPSIS
This script will configure a hypervisor and the appropriate admin account to connect to the host and perform actions like start the PVS master VM
	
.DESCRIPTION
The purpose of the script is to configure a hypervisor an admin account with a password and store this information in text files, the password is encrypted

.NOTES

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-06
#>

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

# Check if PVS SnapIn is available
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
	}

# Variables
$RootFolder = Split-Path -Path $PSScriptRoot 
$Date = Get-Date -UFormat "%d.%m.%Y"
$Log = "$RootFolder\Logs\Create PVS devices.log"
$PVSConfig = Import-Clixml "$RootFolder\PVS\PVS.xml"
$DHCPConfig = Import-Clixml "$RootFolder\PVS\DHCP.xml"

# Start logging
Start-Transcript $Log | Out-Null

$ScriptStart = Get-Date

# Check if PVS SnapIn is available
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
	}

# Get PVS servers
$PVSServerIP = Get-PvsServer | Select-Object IP
$PVSServer1 = $PVSServerIP[0]
$PVSServer2 = $PVSServerIP[1]
$IPPVSServer1 = ($PVSServer1.Ip).IPAddressToString
$IPPVSServer2 = ($PVSServer2.Ip).IPAddressToString
$PVSServers = ($IPPVSServer1 + ',' + $IPPVSServer2).tostring()
# Get PVS site
$SiteName = (Get-PvsSite).SiteName

# New devices
Write-Host -ForegroundColor Yellow "New PVS devices" `n

# Get all collections
$AllCollections = Get-PvsCollection -SiteName $SiteName

# Add property "ID" to object
$ID = 1
$AllCollections | ForEach-Object {
    $_ | Add-Member -MemberType NoteProperty -Name "ID" -Value $ID 
    $ID += 1
    }

	# Show menu to select vDisk
	Write-Host "Available device collections:" `n 
	$ValidChoices = 1..($AllCollections.Count)
	$Menu = $AllCollections | ForEach-Object {(($_.ID).toString() + "." + " " +  $_.Name)}
    #$Menu = $AllCollections
	$Menu | Out-Host
	Write-Host
	$Collection = Read-Host -Prompt 'Select the device collection for your new devices'

	$Collection = $AllCollections | Where-Object {$_.ID -eq $Collection}
	if ($Collection.ID -notin $ValidChoices) {
		Write-Host -ForegroundColor Red "Selected store not found, aborting!"
		Read-Host "Press any key to exit"
		BREAK
		}
	
	$CollectionName = $Collection.Name
	Write-Host ""

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
	$vDisk = Read-Host -Prompt 'Select the vDisk for your new devices'

	$vDisk = $AllvDisks | Where-Object {$_.ID -eq $vDisk}
	if ($vDisk.ID -notin $ValidChoices) {
		Write-Host -ForegroundColor Red "Selected vDisk not found, aborting!"
		Read-Host "Press any key to exit"
		BREAK
		}
	$vDiskName = $vDisk.Name
	$StoreName = $vDisk.StoreName
	Write-Host ""

# Get AD OU
if (Get-WindowsFeature | Where-Object {$_.Name -match "RSAT-AD-PowerShell" -and $_.Installed -match "false"}) {
		Install-WindowsFeature -Name "RSAT-AD-PowerShell"}
$PVSDevice = (Get-PvsDevice -SiteName $SiteName -CollectionName $CollectionName | Select-Object -First 1).DeviceName
$OU = (Get-ADComputer -Identity $PVSDevice -Properties CanonicalName).CanonicalName
$OU = $OU -replace "$env:USERDNSDOMAIN/"," " -replace "/$PVSDevice"," "

# Read CSV
$CSVpath = "$RootFolder\PVS\VDA.csv"
$csv = Import-Csv $CSVpath -Delimiter ";"
$csvHostnames = $CSV.Hostname

# DHCP reservation
Write-Host -ForegroundColor Yellow "Configuring DHCP reservations"
foreach ($Hostnames in $CSV) {
	$Hostname = $Hostnames.Hostname
	$Mac = $Hostnames.Mac
	$MacReplace = $Mac -replace (":", "")
	$IP = $Hostnames.IP

	IF (!(Get-DhcpServerv4Reservation -ComputerName $DHCPConfig.Host -ScopeId $DHCPConfig.Scope | Where-Object {$_.ipaddress -eq $IP})) {
		Add-DhcpServerv4Reservation -ComputerName $DHCPConfig.Host -ScopeId $DHCPConfig.Scope -IPAddress $IP -ClientId $MacReplace -Description $Hostname -Name $Hostname -Type Dhcp
		if ($DHCPConfig.TFTP) {
			Set-DhcpServerv4OptionValue -ComputerName $DHCPConfig.Host -ReservedIP $IP -OptionId 66 -Value $DHCPConfig.TFTP -ErrorAction SilentlyContinue
			}
		if ($DHCPConfig.TFTPBootfile) {
		Set-DhcpServerv4OptionValue -ComputerName $DHCPConfig.Host -ReservedIP $IP -OptionId 67 -Value $DHCPConfig.TFTPBootfile -ErrorAction SilentlyContinue
			}
		if ($DHCPConfig.TFTPBootfile -eq "pvsnbpx64.efi") {
		Set-DhcpServerv4OptionValue -ComputerName $DHCPConfig.Host -ReservedIP $IP -OptionId 11 -Value $PVSServers.split(",") -ErrorAction SilentlyContinue
		}
		Write-Host -ForegroundColor Green "DHCP reservations  successfully created, check logfile '$log'"`n
	}
	ELSE {
		Write-Host -ForegroundColor Red "DHCP reservation for '$Hostname' already exists, skipping!"`n
		}
}
# Replicate to failover partner
Invoke-DhcpServerv4FailoverReplication -ComputerName $DHCPConfig.Host -ScopeID $DHCPConfig.Scope -force -EA SilentlyContinue | Out-Null


# Create PVS devices and computer AD accounts
Write-Host -ForegroundColor Yellow "Creating PVS devices and computer AD accounts"
foreach ($Hostnames in $CSV) {
	$Hostname = $Hostnames.Hostname
	$Mac = $Hostnames.Mac
	$MacReplace = $Mac -replace (":", "-")
		
	IF (!(Get-PvsDevice | Where-Object {$_.Name -eq $Hostname})) {
		New-PvsDevice -SiteName $SiteName -CollectionName $CollectionName -DeviceName $Hostname -DeviceMac $MacReplace | Out-Null
		Add-PvsDeviceToDomain -DeviceName $Hostnames.Hostname -Domain $ENV:userdnsdomain -OrganizationUnit $OU  | Out-Null
		Add-PvsDiskLocatorToDevice -DiskLocatorName $vDiskName -DeviceName $Hostnames.Hostname -SiteName $SiteName -StoreName $StoreName
		Write-Host -ForegroundColor Green "New PVS devices successfully created, check logfile '$log'"`n
	}
	ELSE {
		Write-Host -ForegroundColor Red "PVS device '$Hostname' already exists, skipping!"`n
		}
}


# Stop Logging
$ScriptEnd = Get-Date
$ScriptRuntime =  $ScriptEnd - $ScriptStart | Select-Object TotalSeconds
$ScriptRuntimeInSeconds = $ScriptRuntime.TotalSeconds
Write-Host -ForegroundColor Yellow "Script was running for $ScriptRuntimeInSeconds seconds"`n

Stop-Transcript | Out-Null
$Content = Get-Content -Path $Log | Select-Object -Skip 18
Set-Content -Value $Content -Path $Log
Rename-Item -Path $Log -NewName "Create PVS devices-$CollectionName-$Date.log" -EA SilentlyContinue

& "$RootFolder\PVS\Create PVS VM.ps1"

Read-Host "Press any key to exit"