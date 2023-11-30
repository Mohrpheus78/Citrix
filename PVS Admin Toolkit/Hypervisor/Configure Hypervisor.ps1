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

# Variablen
$RootFolder = Split-Path -Path $PSScriptRoot
$HypervisorConfig = "$PSScriptRoot\Hypervisor.xml"
$HypervisorSelection = New-Object PSObject
$CredentialConfig = (Get-ChildItem -Path $PSScriptRoot -Filter Credentials-$env:username*.xml).Name
$CredentialSelection = New-Object PSObject

# Show Menu
function Show-Menu
{
    param (
        [string]$Title = 'Hypervisor'
    )
    Clear-Host
    Write-Host "======== $Title ========"
    Write-Host `n
    Write-Host "1: VMWare ESX"
    Write-Host "2: XenServer (Citrix Hypervisor)"
    #Write-Host "3: Nutanix AHV"   
    Write-Host `n
}

# Hypervisor selection
Write-Host -ForegroundColor Cyan "Checking current configuration..."`n
IF (Test-Path -Path $HypervisorConfig) {
	Write-Host -ForegroundColor Cyan "Configuration found:"
	$HypervisorXML = Import-Clixml -Path $HypervisorConfig
	$Hypervisor = $HypervisorXML.Hypervisor
	$HypervisorHost = $HypervisorXML.Host
	
	IF ($HypervisorXML.Hypervisor) {
		Write-Host -ForegroundColor Yellow "Hypervisor - $Hypervisor"
		Write-Host -ForegroundColor Yellow "Host - $HypervisorHost"
		$title = ""
		$message = "Hypervisor type already configured, do you want to use the hypervisor type '$Hypervisor'?"
		$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
		$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
		$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
			switch ($choice) {
				0 {
				$Answer1 = 'Yes'       
				}
				1 {
				$Answer1 = 'No'
				}
			}
			Write-Host `n
	}
}
	IF ($Answer1 -eq "Yes") {
			$Hypervisor = $HypervisorXML.Hypervisor
			Add-member -inputobject $HypervisorSelection -MemberType NoteProperty -Name "Hypervisor" -Value $Hypervisor -Force
			}

	ELSE {
		Show-Menu -Title 'Hypervisor configuration'
		$Selection = Read-Host "Which Hypervisor do you use?"
		switch ($Selection)
			{
				'1' {$Hypervisor = 'ESX'}
				'2' {$Hypervisor = 'Xen'}
				#'3' {$Hypervisor = 'AHV'} 
			}
		Add-member -inputobject $HypervisorSelection -MemberType NoteProperty -Name "Hypervisor" -Value $Hypervisor -Force
			
		<#
		# Prepare for module installation
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		IF (!(Test-Path -Path "C:\Program Files\PackageManagement\ProviderAssemblies\nuget")) {
			Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies }
		try {
			set-PSRepository -Name PSGallery -InstallationPolicy Trusted }
		catch {
			Write-Output "Error: $($PSItem.ToString())"
			Write-Host "Something went wrong, check your PSGallery settings or proxy settings"
			Read-Host "Presse ENTER to exit"
			BREAK
		}
		#>

		# Hypervisor name or IP address
		Write-Host "Configure your hypervisor IP address or hostname (vCenter/ESXi/XenServer/AHV) once"
		$HypervisorHost = Read-Host "IP address or hostname (DNS name resolution required)"
		Add-member -inputobject $HypervisorSelection -MemberType NoteProperty -Name "Host" -Value $HypervisorHost -Force
		$HypervisorSelection | Export-Clixml $HypervisorConfig
	}
	
# Hypervisor admin account
Write-Host -ForegroundColor Cyan "Checking current credentials..."
IF (([string]::ISNullOrEmpty( $CredentialConfig) -eq $False) -or ($Answer1 -eq "Yes")) {
	IF (!(Get-ChildItem -Path $PSScriptRoot -Filter Credentials-$env:username*.xml)) {
		Write-Host -ForegroundColor Cyan "No credentials found, configure your credentials"
	}
	ELSE {
		Write-Host -ForegroundColor Cyan "Credentials found:"
		$CredentialsXML = Import-Clixml -Path $PSScriptRoot\$CredentialConfig
		$Username = $CredentialsXML.UserName
		
		IF ($CredentialsXML.UserName) {
		Write-Host -ForegroundColor Yellow "Credentials - $Username"
		$title = ""
		$message = "Username already configured, do you want to use the account '$Username' with the current credentials?`nIf you want to use other credentials or change the current password, select 'No'"
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
			IF ($Answer2 -eq "Yes") {
			$Username = $CredentialsXML.UserName
			Add-member -inputobject $CredentialSelection -MemberType NoteProperty -Name "UserName" -Value $UserName -Force	
			}
			ELSE {
			Write-Host -ForegroundColor Yellow "Configure your Hypervisor admin account and password once, the password is encrypted and only valid for the current user account!"
			}
		}	
	}
}

	IF (!(Get-ChildItem -Path $PSScriptRoot -Filter Credentials-$env:username*.xml) -or ($Answer2 -eq "No")) {
	
		IF ($Hypervisor -eq 'ESX') {
			Write-Host `n
			Write-Host -ForegroundColor Yellow "Enter your vSphere Administrator account (DOMAIN\Admin) or ESXi Account"
			Read-Host "Press ENTER to continue..."
			IF ($CredentialsXML.UserName) {
				Write-Host "Do you want to keep the current user '$UserName'?"
				$User = Read-Host "( Y / N )"
				IF ($User -eq 'Y') {
					Get-Credential -UserName $UserName -Message "Enter vSphere Administrator account (DOMAIN\Admin) or ESXi Account " | Export-CliXml  -Path "$PSScriptRoot\Credentials-$env:username-ESX.xml"
				#Add-member -inputobject $CredentialSelection -MemberType NoteProperty -Name "UserName" -Value $UserName -Force
				}	
			}
				ELSE {
					Get-Credential -UserName $ENV:UserName@$ENV:UserDNSDomain -Message "Enter vSphere Administrator account (DOMAIN\Admin) or ESXi Account " | Export-CliXml  -Path "$PSScriptRoot\Credentials-$env:username-ESX.xml"
				}
				# Install Powershell module
				IF (!(Get-Module -ListAvailable -Name VMWare.PowerCLI)) {
					try { 
						Install-Module VMWare.PowerCLI -Scope AllUsers -Force
					}
					catch { 
					Write-Host -ForegroundColor Red "Error - Failed to install VMWare PowerCLI module (Error: $($Error[0])), download and install the VMWare PowerCLI module!"
					Read-Host
					break               
					} 
				}
				Write-Host -ForegroundColor Yellow "Importing VMWare Powershell module, please wait..."	
				try {
					Import-Module -Name VMWare.PowerCLI
				}
				catch { 
					Write-Host -ForegroundColor Red "Error - Failed to import VMWare PowerCLI module (Error: $($Error[0]))"
					Read-Host
					break
				}
		}
					
		IF ($Hypervisor -eq 'Xen') {
			Write-Host `n
			Write-Host -ForegroundColor Yellow "Enter your Domain Administrator account (DOMAIN\Admin) or root"
			Read-Host "Press ENTER to continue..."
			Get-Credential -UserName root -Message "Domain Administrator account (DOMAIN\Admin) or root " | Export-CliXml  -Path "$PSScriptRoot\Credentials-$env:username-Xen.xml"
			# Check Powershell module
			IF (!(Get-Module -ListAvailable -Name XenServerPSModule)) {
				Write-Host -ForegroundColor Red "XenServer Powershell module 'XenServerPSModule' not found, download the XenServer SDK and install the module: https://www.xenserver.com/downloads"
				Read-Host
				break
			}
		}
		
		<#		
		IF ($Hypervisor -eq 'AHV') {
			#Write-Host -ForegroundColor Yellow "Enter your Domain Administrator account (DOMAIN\Admin) or root"
			Write-Host `n
			$AHVAdmin = Read-Host "Enter your Domain Administrator account (DOMAIN\Admin) or AHV Admin account"
			$AHVPassword = Read-Host "Password"
			$AHVAdminFile = "$PSScriptRoot\Admin-AHV.txt"
			$AHVAdmin | Out-File $AHVAdminFile
			$KeyFile = "$PSScriptRoot\AES.key"
			$Key = New-Object Byte[] 24
			[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
			$Key | out-file $KeyFile
			$AHVPasswordFile = "$PSScriptRoot\Password-AHV.txt"
			$KeyFile = "$PSScriptRoot\AES.key"
			$Key = Get-Content $KeyFile
			$AHVPassword = $AHVPassword | ConvertTo-SecureString -AsPlainText -Force
			$AHVPassword | ConvertFrom-SecureString -key $Key | Out-File $AHVPasswordFile
			Read-Host "Press ENTER to continue..."
			# Install Powershell module
			IF ($PSVersionTable.PSVersion -lt "7.0") {
				Write-Host -ForegroundColor Red "You need Powershell 7.0 or higher to use the Nutanix Powershell module, please install the recent version of Powershell"
				Read-Host "Press ENTER to exit"
				BREAK
			}
			IF (!(Get-Module -ListAvailable -Name Nutanix.Cli)) {
				Install-Module Nutanix.Cli -Scope AllUsers -Force
			}
		}
		#>
}
