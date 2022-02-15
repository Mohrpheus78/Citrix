<#
.SYNOPSIS
This script will configure a hypervisor and the appropriate admin account to connect to the host and perform actions like start the PVS master VM
	
.DESCRIPTION
The purpose of the script is to configure a hypervisor an admin account with a password and store this information in text files, the password is encrypted

.NOTES

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2022-02-06
Purpose/Change:	
2022-02-06		Inital version
#>

function Show-Menu
{
    param (
        [string]$Title = 'Hypervisor'
    )
    Clear-Host
    Write-Host "======== $Title ========"
    Write-Host `n
    Write-Host "1: VMWare vSphere"
    Write-Host "2: Citrix Hypervisor (Xen)"
    Write-Host "3: Nutanix AHV"   
    Write-Host `n
}

# Hypervisor selection
Show-Menu -Title 'Hypervisor configuration'
$Selection = Read-Host "Which Hypervisor do you use?"

switch ($Selection)
 {
	'1' {
        $Hypervisor = 'ESX'
    } '2' {
        $Hypervisor = 'Xen'
    } '3' {
        $Hypervisor = 'AHV'
    } 
 }

$HypervisorConfig = "$PSScriptRoot\Hypervisor.xml"
$HypervisorSelection = New-Object PSObject
Add-member -inputobject $HypervisorSelection -MemberType NoteProperty -Name "Hypervisor" -Value $Hypervisor -Force

# Hypervisor name or IP address
Write-Host `n
Write-Host "Configure your hypervisor IP address/hostname (vCenter/ESXi/XenServer/AHV) once" `n
$HypervisorHost = Read-Host "IP address or hostname (DNS name resolution required)"
Add-member -inputobject $HypervisorSelection -MemberType NoteProperty -Name "Host" -Value $HypervisorHost -Force
$HypervisorSelection | Export-Clixml $HypervisorConfig

# Hypervisor admin account
Write-Host `n
Write-Host "Configure your Hypervisor admin account and password once, the password is encrypted and only valid for the current user account!" `n
IF ($Hypervisor -eq 'ESX') {
    Write-Host -ForegroundColor Yellow "Enter your vSphere Administrator account (DOMAIN\Admin) or ESXi Account"
	Read-Host "Press ENTER to continue..."
	Get-Credential -Message "Enter vSphere Administrator account (DOMAIN\Admin) or ESXi Account " | Export-CliXml  -Path "$PSScriptRoot\Credentials-ESX.xml"
    }
	
IF ($Hypervisor -eq 'Xen') {
    Write-Host -ForegroundColor Yellow "Enter your Domain Administrator account (DOMAIN\Admin) or root"
	Read-Host "Press ENTER to continue..."
	Get-Credential -UserName root -Message "Domain Administrator account (DOMAIN\Admin) or root " | Export-CliXml  -Path "$PSScriptRoot\Credentials-Xen.xml"
    }
	
IF ($Hypervisor -eq 'AHV') {
    #Write-Host -ForegroundColor Yellow "Enter your Domain Administrator account (DOMAIN\Admin) or root"
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
	}