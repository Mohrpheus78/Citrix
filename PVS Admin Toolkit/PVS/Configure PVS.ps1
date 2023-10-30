<#
.SYNOPSIS
This script will configure a PVS maintenance device
	
.DESCRIPTION
The purpose of the script is to define a PVS maintenance device if the VM name on the hypervisor is different to the Windows hostname 

.NOTES

Version:		2.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-06
Purpose/Change:	
2022-02-06		Inital version
2022-07-08		Added DHCP 
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
$PVSConfig = "$PSScriptRoot\PVS.xml"
$PVSSelection = New-Object PSObject
$DHCPConfig = "$PSScriptRoot\DHCP.xml"
$DHCPSelection = New-Object PSObject
$HypervisorConfig = Import-Clixml "$RootFolder\Hypervisor\Hypervisor.xml"
$Hypervisor = $HypervisorConfig.Hypervisor
$HypervisorHost = $HypervisorConfig.Host
$SiteName = (Get-PvsSite).SiteName


Write-Host "======== PVS configuration ========"
Write-Host `n

# VM name of PVS maintenance device
$MaintDevices = (Get-PvsDeviceInfo -SiteName $SiteName | Where-Object { $_.Type -eq 2 }).Name
#if ($MaintDevices.Count -gt 0) {
    Write-Host "Number of maintenance devices found: $($MaintDevices.Count)`n"
    Write-Host -ForegroundColor Yellow "Maintenance Devices:`n$MaintDeviceName"
    
    foreach ($Device in $MaintDevices) {
        Write-Host $Device
		$vDiskName = (Get-PvsDeviceInfo -DeviceName $Device).DiskLocatorName
        Write-Host "vDisks assigned: $vDiskName`n"
    }
#}
if ($MaintDevices.Count -gt 1) {
	Write-Host "`nFound more than one maintenance device`n"
}

$title = ""
$message = "Is the virtual machine name of the PVS maintenance device identical to the Windows hostname?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
	switch ($choice) {
		0 {
		$answer1 = 'Yes'       
		}
		1 {
		$answer1 = 'No'
		}
	}

	if ($answer1 -eq 'No') {
		if ($MaintDevices.Count -gt 1) {
			foreach ($Device in $MaintDevices) {
				$vDiskName = (Get-PvsDeviceInfo -DeviceName $Device).DiskLocatorName
				$MaintDeviceName = Read-Host "Enter VM name of the first PVS maintenance device '$device'"
				Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "MaintDeviceName-$vDiskName" -Value $MaintDeviceName -Force
			}
		}
		else {
			$MaintDeviceName = Read-Host "Enter VM name of the PVS maintenance device"
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "MaintDeviceName" -Value $MaintDeviceName -Force
		}
	}
Write-Host `n

# BIS-F configuration
$title = ""
$message = "Do you use Base Image Script Framework inside your PVD vDisk? (You really should! https://eucweb.com)"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
	switch ($choice) {
		0 {
		$BISF = 'Yes'       
		}
		1 {
		$BISF = 'No'
		}
	}
	
	if ($BISF -eq 'Yes') {
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "BISF" -Value "$BISF" -Force
		}

	if ($BISF -eq 'No') {
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "BISF" -Value "$BISF" -Force
		}
Write-Host `n

# Skip PVS Boot menu
$title = ""
$message = "Do you want to skip the PVS boot menu for your maintenance device? The VDA will not stop and wait for user input. This is required if you want to install Windows Updates unattended!"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
	switch ($choice) {
		0 {
		$SkipBootMenu = 'Yes'       
		}
		1 {
		$SkipBootMenu = 'No'
		}
	}

    if ($SkipBootMenu -eq 'Yes') {
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "SkipBootMenu" -Value "Yes" -Force
		}

	if ($SkipBootMenu -eq 'No') {
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "SkipBootMenu" -Value "No" -Force
		}
Write-Host `n
	
	if ($SkipBootMenu -eq 'Yes') {
		New-ItemProperty -Path "HKLM:\Software\Citrix\ProvisioningServices\StreamProcess" -Name 'SkipBootMenu' -Value '1' -PropertyType DWORD -Force | Out-Null
		$title = ""
		$message = "Do you want to restart the PVS streaming service for the changes to take effect? Attention, do this only if your vDisks are load balanced!"
		$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
		$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
		$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
		switch ($choice) {
			0 {
			$StreamingService = 'Yes'       
			}
			1 {
			$StreamingService = 'No'
			}
		}
		if ($StreamingService -eq 'Yes') {
			Write-Host -Foregroundcolor Yellow "Registry value 'HKLM\SOFTWARE\Citrix\ProvisioningServices\StreamProcess\SkipBootMenu' set to '1', restarting PVS Streaming service!"
			Restart-Service -Name StreamService -Force
			}

        if ($StreamingService -eq 'No') {
            Write-Host -Foregroundcolor Yellow "Remember restarting the PVS Streaming service for changes to take effect!"
            }
	}
Write-Host `n

# PVS configuration
$title = ""
$message = "Do you want to automatically create PVS devices and the corresponding virtual machines?"
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
	switch ($choice) {
		0 {
		$PVS = 'Yes'       
		}
		1 {
		$PVS = 'No'
		}
	}
	if ($PVS -eq 'Yes') {
		Write-Host `n
		
# DHCP server name or IP address
		Write-Host "Configure your DHCP server"`n
		if (Test-Path -Path $DHCPConfig) {
			$DHCPXML = Import-Clixml -Path $DHCPConfig
            if ($DHCPXML.Host) {
            Write-Host -ForegroundColor Cyan $DHCPXML.Host
			$title = ""
			$message = "DHCP host already configured, do you want to use this option?"
			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
				switch ($choice) {
					0 {
					$Answer2 = 'Yes'       
					}
					1 {
					$Answer2 = 'No'
					}
				}
				Write-Host `n
			}
		}
		if ($Answer2 -eq "Yes") {
			$DHCPHost = $DHCPXML.Host
			Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "Host" -Value $DHCPHost -Force
			}
		else {
			$DHCPHost = Read-Host "Enter the DNS name (FQDN) of your primary DHCP server"
			$DHCPHostCheck = Resolve-DnsName -Name $DHCPHost -EA SilentlyContinue
			IF ([string]::ISNullOrEmpty( $DHCPHostCheck) -eq $True) {
				Write-Host -Foregroundcolor Red "DHCP Host not found, check name and try again!"
				BREAK
			}
			Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "Host" -Value $DHCPHost -Force
			Write-Host `n
			}
	
		
# DHCP server scope
		Write-Host "Configure the DHCP server scope for your PVS devices (e.g. 172.16.10.0)"`n
		if (Test-Path -Path $DHCPConfig) {
			$DHCPXML = Import-Clixml -Path $DHCPConfig
			if ($DHCPXML.Scope) {
            Write-Host -ForegroundColor Cyan $DHCPXML.Scope
			$title = ""
			$message = "DHCP scope already configured, do you want to use this option?"
			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
				switch ($choice) {
					0 {
					$Answer3 = 'Yes'       
					}
					1 {
					$Answer3 = 'No'
					}
				}
				Write-Host `n
			}
		}
		if ($Answer3 -eq "Yes") {
			$DHCPScope = $DHCPXML.Scope
			Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "Scope" -Value $DHCPScope -Force
			}
		else {
			$DHCPScope = Read-Host "Enter DHCP scope"
			$DHCPScopeCheck = Get-DhcpServerv4Scope -ComputerName $DHCPHost -ScopeId $DHCPScope -EA SilentlyContinue
			IF ([string]::ISNullOrEmpty( $DHCPScopeCheck) -eq $True) {
				Write-Host -Foregroundcolor Red "DHCP scope not found, check scope name and try again!"
				BREAK
			}
			Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "Scope" -Value $DHCPScope -Force
			Write-Host `n
			}
						
# DHCP options
		# Check if option 66 is already defined in the scope options
		if (!(Get-DhcpServerv4OptionValue -ComputerName $DHCPHost -ScopeId $DHCPScope -OptionId 66 -EA SilentlyContinue)) {
		Write-Host "Configure the DHCP option 66 (TFTP Loadbalancer hostname)"`n
		if (Test-Path -Path $DHCPConfig) {
			$DHCPXML = Import-Clixml -Path $DHCPConfig
			if ($DHCPXML.TFTP) {
                Write-Host -ForegroundColor Cyan $DHCPXML.TFTP
				$title = ""
				$message = "DHCP Option 66 (TFTP Loadbalancer hostname) already configured, do you want to use this option?"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
					switch ($choice) {
						0 {
						$Answer4 = 'Yes'       
						}
						1 {
						$Answer4 = 'No'
						}
					}
					Write-Host `n
			}	
		}
			if ($Answer4 -eq "Yes") {
				$TFTPServer = $DHCPXML.TFTP
				Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "TFTPBootfile" -Value $TFTPServer -Force
				}
			else {
			Write-Host "Configure the DHCP option 66 (TFTP Loadbalancer hostname)"
			$TFTPServer = Read-Host "Enter a single hostname or Loadbalancer (not FQDN)"
			Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "TFTPBootfile" -Value $TFTPServer -Force
			Write-Host `n
			}
		}
		
		# Check if option 67 is already defined in the scope options
		if (!(Get-DhcpServerv4OptionValue -ComputerName $DHCPHost -ScopeId $DHCPScope -OptionId 67 -EA SilentlyContinue)) {
		Write-Host "Configure the DHCP option 67 (Boot file name, should be pvsnbpx64.efi)"`n
		if (Test-Path -Path $DHCPConfig) {
			$DHCPXML = Import-Clixml -Path $DHCPConfig
			if ($DHCPXML.TFTPBootfile) {
                Write-Host -ForegroundColor Cyan $DHCPXML.TFTPBootfile
				$title = ""
				$message = "DHCP Option 67 (Boot file name) already configured, do you want to use this option?"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
					switch ($choice) {
						0 {
						$Answer5 = 'Yes'       
						}
						1 {
						$Answer5 = 'No'
						}
					}
					Write-Host `n
			}
		}
			if ($Answer4 -eq "Yes") {
				$TFTPBootFile = $DHCPXML.TFTPBootfile
				Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "TFTPBootfile" -Value $TFTPBootFile -Force
				}
			else {
			$TFTPBootFile = Read-Host "Hit enter if you want to use the default EFI file 'pvsnbpx64.efi' or define another value"
			if(-not($TFTPBootFile)){
				$TFTPBootFile = "pvsnbpx64.efi"
				}
			Add-member -inputobject $DHCPSelection -MemberType NoteProperty -Name "TFTPBootfile" -Value $TFTPBootFile -Force
			Write-Host `n
			}
		}
		
# Hypervisor config
		# VM Template
		Write-Host "Configure the VM template for cloning the VDA clients"`n
		if (Test-Path -Path $PVSConfig) {
			$VDATemplateXML = Import-Clixml -Path $PVSConfig
			if ($VDATemplateXML.VDATemplate) {
            Write-Host -ForegroundColor Cyan $VDATemplateXML.VDATemplate
			$title = ""
			$message = "VDA Template already configured, do you want to use the template?"
			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
				switch ($choice) {
					0 {
					$Answer3 = 'Yes'       
					}
					1 {
					$Answer3 = 'No'
					}
				}
				Write-Host `n
			}
		}
		if ($Answer3 -eq "Yes") {
			$VDATemplate = $VDATemplateXML.VDATemplate
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "VDATemplate" -Value "$VDATemplate" -Force
			}
		else {
			$VDATemplate = Read-Host "Enter the name of VDA template"
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "VDATemplate" -Value "$VDATemplate" -Force
			Write-Host `n
			}
		
		# VM Host
		Write-Host "Configure the VM host for the VDA clients (you can later distribute the clients on your datacenter)"`n
		if (Test-Path -Path $PVSConfig) {
			$VMHostXML = Import-Clixml -Path $PVSConfig
			if ($VMHostXML.Host) {
            Write-Host -ForegroundColor Cyan $VMHostXML.Host
			$title = ""
			$message = "VM Host already configured, do you want to use the host?"
			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
				switch ($choice) {
					0 {
					$Answer3 = 'Yes'       
					}
					1 {
					$Answer3 = 'No'
					}
				}
				Write-Host `n
			}
		}
		if ($Answer3 -eq "Yes") {
			$VMHost = $VMHostXML.Host
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "Host" -Value "$VMHost" -Force
			}
		else {
			$VMHost = Read-Host "Enter the name of the hypervisor host (not FQDN)"
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "Host" -Value "$VMHost" -Force
			Write-Host `n
			}
		
		# VM Network
		Write-Host "Configure the VM network for your VDA clients (e.g. VM Network)"`n
		if (Test-Path -Path $PVSConfig) {
			$VMNetworkXML = Import-Clixml -Path $PVSConfig
			if ($VMNetworkXML.VMNetwork) {
            Write-Host -ForegroundColor Cyan $VMNetworkXML.VMNetwork
			$title = ""
			$message = "VM Network already configured, do you want to use the network?"
			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
				switch ($choice) {
					0 {
					$Answer3 = 'Yes'       
					}
					1 {
					$Answer3 = 'No'
					}
				}
				Write-Host `n
			}
		}
		if ($Answer3 -eq "Yes") {
			$VMNetwork = $VMNetworkXML.VMNetwork
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "VMNetwork" -Value "$VMNetwork" -Force
			}
		else {
			$VMNetwork = Read-Host "Enter the name of the VM network"
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "VMNetwork" -Value "$VMNetwork" -Force
			Write-Host `n
		}
		
		# VM Storage
		Write-Host "Configure the VM storage for your VDA clients"`n
		if (Test-Path -Path $PVSConfig) {
			$VMStorageXML = Import-Clixml -Path $PVSConfig
			if ($VMStorageXML.VMStorage) {
            Write-Host -ForegroundColor Cyan $VMNetworkXML.VMStorage
			$title = ""
			$message = "VM Storage already configured, do you want to use the storage?"
			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
				switch ($choice) {
					0 {
					$Answer3 = 'Yes'       
					}
					1 {
					$Answer3 = 'No'
					}
				}
				Write-Host `n
			}
		}
		if ($Answer3 -eq "Yes") {
			$VMStorage = $VMStorageXML.VMStorage
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "VMStorage" -Value "$VMStorage" -Force
			}
		else {
			$VMStorage = Read-Host "Enter the name of the VM storage (Datastore)"
			Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "VMStorage" -Value "$VMStorage" -Force
			Write-Host `n
			}

<#			
# AD config
		Write-Host "Configure the organizational unit (OU) for the PVS devices"`n
		$OU = Read-Host "Enter the name of the OU (e.g. Citrix/VDA/Worker)"
		Add-member -inputobject $PVSSelection -MemberType NoteProperty -Name "OU" -Value "$OU" -Force
		Write-Host `n
#>

# CSV
		$CSV = Get-Content -Path "$PSScriptRoot\VDA.csv" -EA SilentlyContinue
		Write-Host "Configure a CSV file in the subfolder 'PVS'"`n
		IF ($CSV) {
		Write-Host "VDA.csv example:"`n
		$CSV
		}
	}
		
$DHCPSelection | Export-Clixml $DHCPConfig
$PVSSelection | Export-Clixml $PVSConfig

Write-Host `n
Read-Host -Prompt "Press any key to exit..."