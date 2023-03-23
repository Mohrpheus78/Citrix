# *******************************************************************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# BGInfo powered by Powershell
# 05/12/19	DM	Initial release
# 06/12/19	DM	Added FSLogix
# 09/12/19	DM	Added deviceTRUST
# 11/12/19	DM	Initial public release
# 11/12/19	DM	Changed method to get session id
# 18/06/20	DM  	Added MTU Size, WEM and VDA Agent version
# 26/06/20	DM	Added FSLogix Version
# 26/06/20	DM	Changed BGInfo process handling
# 20/10/20	DM	Added percent for FSL
# 21/10/20	DM	Added WEM Cache date
# 09/11/20  	DM  	Added Regkeys for IP and DNS (Standard method didn't work wirh Citrix Hypervisor)
# *******************************************************************************************************

<#
    .SYNOPSIS
        Shows information about the user Citrix environment as BGInfo wallpaper
		
    .Description
        Execute as logon script or WEM external task to show useful informations about the user environment
		
    .EXAMPLE
	WEM:
	Path: powershell.exe
	Arguments: -executionpolicy bypass -file "C:\Program Files (x86)\SuL\Citrix Management Tools\BGInfo\BGInfo.ps1"
	.FSLogix Profile Size Warning.ps1
	    
    .NOTES
	Execute as WEM external task (also after reconnect to refresh the information), logonscript or task at logon
	Edit the $BGInfoDir (Directory with BGInfo.exe) and $BGInfoFile (BGI file to load)
#>

# *******************
# Scripts starts here
# *******************

# Source directory for BGInfo/BGInfo File (customize)
$BGInfoDir = 'C:\Program Files (x86)\SuL\Citrix Management Tools\BGInfo'
$BGInfoFile = 'User.bgi'

# Regkey for setting the values (BGinfo gets informations from this source, don't edit!)
$RegistryPath = "HKCU:\BGInfo"
New-Item -Path $RegistryPath -EA SilentlyContinue


# ********************
# General Informations
# ********************
$IPAddress = (Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.status -ne "Disconnected"}).IPv4Address.IPAddress
New-ItemProperty -Path $RegistryPath -Name "IPAddress" -Value $IPAddress -Force
$DNSServer = (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.DefaultIPGateway -ne $null}).DNSServerSearchOrder
New-ItemProperty -Path $RegistryPath -Name "DNSServer" -Value $DNSServer -Force


# ***************************
# Informations about Citrix #
# ***************************

# Citrix SessionID
$CitrixSessionID = Get-ChildItem -Path "HKCU:\Volatile Environment" -Name
New-ItemProperty -Path $RegistryPath -Name "SessionID" -Value $CitrixSessionID -Force

# Citrix Clientname
$CitrixClientName = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Client_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Name
New-ItemProperty -Path $RegistryPath -Name "Clientname" -Value $CitrixClientName -Force

# Citrix Client
$CitrixClientVer = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Client_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Version
New-ItemProperty -Path $RegistryPath -Name "Citrix Client Ver" -Value $CitrixClientVer -Force

# Citrix Client IP
$CitrixClientIP = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Client_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Address
New-ItemProperty -Path $RegistryPath -Name "Citrix Client IP" -Value $CitrixClientIP -Force

# HDX Protocol
$HDXProtocol = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_Network_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Component_Protocol
New-ItemProperty -Path $RegistryPath -Name "HDX Protocol" -Value $HDXProtocol -Force

# MTU
$MTUSize = (ctxsession -v | findstr "EDT MTU:" | Select-Object -Last 1).split(":")[1].trimstart()
New-ItemProperty -Path $RegistryPath -Name "MTU Size" -Value $MTUSize -Force

# Rendezvous
$Rendezvous = ((ctxsession -v | findstr "Rendezvous") | Select-Object -Last 1).split(":")[1].trimstart()
New-ItemProperty -Path $RegistryPath -Name "Rendezvous" -Value $Rendezvous -Force


# BGInfo #
# Start BGInfo
Start-Process -FilePath "$BGInfoDir\Bginfo64.exe" -ArgumentList @('/nolicprompt','/timer:0',"`"$BGInfoDir\$BGInfoFile`"") 
