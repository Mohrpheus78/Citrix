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

# Variables
$RootFolder = Split-Path -Path $PSScriptRoot 
$Date = Get-Date -UFormat "%d.%m.%Y"
$Log = "$RootFolder\Logs\Create PVS VM.log"
$HypervisorConfig = Import-Clixml "$RootFolder\Hypervisor\Hypervisor.xml"
$Hypervisor = $HypervisorConfig.Hypervisor
$PVSConfig = Import-Clixml "$RootFolder\PVS\PVS.xml"

# Start logging
Start-Transcript $Log | Out-Null

# Citrix XenServer
IF ($Hypervisor -eq "Xen") {
	# Check XenServer PS Module
	IF (!(Get-Module -ListAvailable -Name XenServerPSModule)) {
	Write-Host -ForegroundColor Red "No XenServer Powershell module found, aborting! Please copy module to 'C:\Program Files\WindowsPowerShell\Modules'"
	Read-Host "Press any key to exit"
	BREAK
	}

# Connect to Xen host
$Xen = $HypervisorConfig.Host
$Credential = Import-CliXml -Path "$RootFolder\Hypervisor\Credentials-Xen.xml"	
Try {
	Connect-XenServer -url https://$Xen -Creds $Credential -NoWarnNewCertificates -SetDefaultSession | Out-Null
}
Catch {
	write-warning "Error: $_."
	}

# Create VM's
Write-Host -ForegroundColor Yellow "Creating virtual machines"
$CSVpath = "$RootFolder\PVS\VDA.csv"
$csv = Import-Csv $CSVpath -Delimiter ";"
$csvHostnames = $CSV.Hostname

	foreach ($Hostnames in $CSV) {
		$Hostname = $Hostnames.Hostname
		$Mac = $Hostnames.Mac
		
		IF (!(Get-XenVM | Where-Object {$_.is_a_template -eq $False -and $_.is_a_snapshot -eq $False -and $_.domid -ne 0 -and $_.name_label -eq $Hostname})) {
			Invoke-XenVM -Name $PVSConfig.VDATemplate -XenAction Copy -NewName $Hostname -SR $PVSConfig.VMStorage
			Set-XenVM -Name $Hostname
			Invoke-XenVM -Name $Hostname -XenAction Provision
			(Get-XenVM -Name $Hostname).VIFs | Remove-XenVIF
			$VIF = Get-XenNetwork -Name $PVSConfig.VMNetwork
			$VM_ref=Get-XenVM -Name $Hostname | Select-Object -ExpandProperty opaque_ref
			New-XenVIF -VM $VM_ref -Network $VIF -MAC $Mac -Device 0
			$VM = Get-XenVM | Where-Object {$_.is_a_template -eq $False -and $_.is_a_snapshot -eq $False -and $_.domid -ne 0 -and $_.name_label -eq $Hostname}
			$VMName = $VM.name_label
			$VDI = $VM.VBDs | ForEach-Object { Get-XenVBD $_.opaque_ref | Where-Object {$_.type -notlike "CD"} } | ForEach-Object {Set-XenVDI -Ref $_.VDI -NameLabel ("$VMName" + "_D_Cache")}
			Write-Host -ForegroundColor Green "New virtual machines successfully created, check logfile '$log'"`n
			}
		ELSE {
			Write-Host -ForegroundColor Red "Virtual machine '$Hostname' already exists, skipping!"`n
		}
	}
}

# VMWare vSphere
IF ($Hypervisor -eq "ESX") {
	# Check VMWare PS Module
	IF (!(Get-Module -ListAvailable -Name VMware.PowerCLI)) {
	Write-Host -ForegroundColor Red "No VMWare Powershell module found, aborting! Please install module to 'C:\Program Files\WindowsPowerShell\Modules'"
	Read-Host "Press any key to exit"
	BREAK
	}
$ESX = $HypervisorConfig.Host
$Credential = Import-CliXml -Path "$RootFolder\Hypervisor\Credentials-ESX.xml"
Try {
	Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false | Out-Null
	Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false | Out-Null
	Connect-VIServer -server $ESX -Credential $Credential
}
Catch {
	write-warning "Error: $_."
	}

# Create VM's
Write-Host -ForegroundColor Yellow "Creating virtual machines"
$CSVpath = "$RootFolder\PVS\VDA.csv"
$csv = Import-Csv $CSVpath -Delimiter ";"
$csvHostnames = $CSV.Hostname

	foreach ($hostnames in $CSV) { 
		$Hostname = $Hostnames.Hostname
		$Mac = $Hostnames.Mac
		
		IF (!(Get-VM | Where-Object {$_.Name -eq $Hostname})) {
			New-VM -Name $Hostname -Template $PVSConfig.VDATemplate -Datastore $PVSConfig.VMStorage -VMHost $PVSConfig.Host
			Get-VM $Hostname | Get-NetworkAdapter | Where-Object {$_.NetworkName -eq $PVSConfig.VMNetwork } | Set-NetworkAdapter -MacAddress $Mac -Confirm:$false
			Write-Host -ForegroundColor Green "New virtual machines successfully created, check logfile '$log'"`n
		}
		ELSE {
			Write-Host -ForegroundColor Red "Virtual machine '$Hostname' already exists, skipping!"`n
		}
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
Rename-Item -Path $Log -NewName "Create PVS VM-$Hypervisor-$Date.log" -EA SilentlyContinue



