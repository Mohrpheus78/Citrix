# *******************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# BGInfo powered by Powershell
# 05/12/19	DM	Initial release
# 06/12/19	DM	Added FSLogix
# 09/12/19	DM	Added deviceTRUST
# 11/12/19	DM	Initial public release
# 11/12/19	DM	Changed method to get session id
# 18/06/20	DM  Added MTU Size, WEM and VDA Agent version
# 26/06/20	DM	Added FSLogix Version
# 26/06/20	DM	Changed BGInfo process handling
# *******************************************************

<#
    .SYNOPSIS
        Shows information about the user Citrix environment as BGInfo taskbar icon
		
    .Description
        Execute as logon script or WEM external task to show useful informations about the user environment
		
    .EXAMPLE
	WEM:
	Path: powershell.exe
	Arguments: -executionpolicy bypass -file "C:\Program Files (x86)\SuL\Citrix Management Tools\BGInfo\BGInfo-Taskbar-Taskbar.ps1"
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
$BGInfoFile = 'Citrix.bgi'

# Regkey for setting the values (BGinfo gets informations from this source, don't edit!)
$RegistryPath = "HKCU:\BGInfo"
New-Item -Path $RegistryPath -EA SilentlyContinue


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

# HDX Video Codec
$HDXCodec = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_VirtualChannel_Thinwire_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Component_VideoCodecUse
New-ItemProperty -Path $RegistryPath -Name "HDX Codec" -Value $HDXCodec -Force

# HDX Video Codec Type
$HDXCodecType = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_VirtualChannel_Thinwire_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Component_Monitor_VideoCodecTypeCurrent
New-ItemProperty -Path $RegistryPath -Name "HDX Codec Type" -Value $HDXCodecType -Force

# HDX Visual Quality
$VisualQuality = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_VirtualChannel_Thinwire_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Policy_VisualQuality
New-ItemProperty -Path $RegistryPath -Name "HDX Visual Quality" -Value $VisualQuality -Force

# HDX Visual Lossless Compression
$VisualLosslessCompression = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_VirtualChannel_Thinwire_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Policy_AllowVisuallyLosslessCompression
New-ItemProperty -Path $RegistryPath -Name "HDX Visual Lossless Compression" -Value $VisualLosslessCompression -Force

# HDX Colorspace
$HDXColorspace = Get-WmiObject -Namespace root\citrix\hdx -Class Citrix_VirtualChannel_Thinwire_Enum | Where-Object {$_.SessionID -eq $CitrixSessionID} | Select-Object -ExpandProperty Component_VideoCodecColorspace
New-ItemProperty -Path $RegistryPath -Name "HDX Colorspace" -Value $HDXColorspace -Force

# HDX Web Camera
$HDXWebCamera = Get-ItemProperty -Path "HKCU:\SOFTWARE\Citrix\HdxRealTime\"
$HDXWebCamera = Get-ItemProperty -Path "HKCU:\SOFTWARE\Citrix\HdxRealTime\"
$HDXWebCamera = $HDXWebCamera.'Filter Name'
$HDXWebCamera = $HDXWebCamera -replace '@.*$'
New-ItemProperty -Path $RegistryPath -Name "HDX Web Camera" -Value $HDXWebCamera -Force

# MTU
$MTUSize = (ctxsession -v | findstr "EDT MTU:" | select -Last 1).split(":")[1].trimstart()
New-ItemProperty -Path $RegistryPath -Name "MTU Size" -Value $MTUSize -Force

# WEM Version
$WEM = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -like "*Citrix Workspace Environment*"}).DisplayVersion | Select-Object -Last 1
New-ItemProperty -Path $RegistryPath -Name "WEM Version" -Value $WEM -Force

# WEM Agent logon
$WEMAgentLastRun = Get-EventLog -LogName 'WEM Agent Service' -Message '*Starting Logon Processing for User*' -Newest 1 |Select-Object -ExpandProperty TimeGenerated
New-ItemProperty -Path $RegistryPath -Name "WEMAgentLastRun" -Value $WEMAgentLastRun -Force


# ****************************
# Informations about FSLogix #
# ****************************

# Profilesize
$ProfileSize = "{0:N2} GB" -f ((Get-ChildItem $ENV:USERPROFILE -Force -Recurse -EA SilentlyContinue | measure Length -s).Sum /1GB)
New-ItemProperty -Path $RegistryPath -Name "Profile Size" -Value $ProfileSize -Force

# FSLogix Profile Status
$FSLProfileStatus = Get-Volume -FriendlyName *Profile-$ENV:USERNAME* | Where-Object { $_.DriveType -eq 'Fixed'} | Select-Object -ExpandProperty HealthStatus
New-ItemProperty -Path $RegistryPath -Name "FSL Profile Status" -Value $FSLProfileStatus -Force

# FSLogix Profile Size
$FSLProfileSize = Get-Volume -FileSystemLabel *Profile-$ENV:USERNAME* | Where-Object { $_.DriveType -eq 'Fixed'} | ForEach-Object {[string]::Format("{0:0.00} GB", $_.Size / 1GB)}
New-ItemProperty -Path $RegistryPath -Name "FSL Profile Size" -Value $FSLProfileSize -Force

# FSLogix Profile Size Remaining
$FSLProfileSizeRemaining = Get-Volume -FileSystemLabel *Profile-$ENV:USERNAME* | Where-Object { $_.DriveType -eq 'Fixed'} | ForEach-Object {[string]::Format("{0:0.00} GB", $_.SizeRemaining / 1GB)}
New-ItemProperty -Path $RegistryPath -Name "FSL Profile Size Remaining" -Value $FSLProfileSizeRemaining -Force

# FSLogix O365 Status
$FSLO365Status = Get-Volume -FriendlyName *O365-$ENV:USERNAME* | Where-Object { $_.DriveType -eq 'Fixed'} | Select-Object -ExpandProperty HealthStatus
New-ItemProperty -Path $RegistryPath -Name "FSL O365 Status" -Value $FSLO365Status -Force

# FSLogix O365 Size
$FSLO365Size = Get-Volume -FileSystemLabel *O365-$ENV:USERNAME* | Where-Object { $_.DriveType -eq 'Fixed'} | ForEach-Object {[string]::Format("{0:0.00} GB", $_.Size / 1GB)}
New-ItemProperty -Path $RegistryPath -Name "FSL O365 Size" -Value $FSLO365Size -Force

# FSLogix O365 Size Remaining
$FSLO365SizeRemaining = Get-Volume -FileSystemLabel *O365-$ENV:USERNAME* | Where-Object { $_.DriveType -eq 'Fixed'} | ForEach-Object {[string]::Format("{0:0.00} GB", $_.SizeRemaining / 1GB)}
New-ItemProperty -Path $RegistryPath -Name "FSL O365 Size Remaining" -Value $FSLO365SizeRemaining -Force

# FSLogix Version
$FSLVersion = (Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -eq "Microsoft FSLogix Apps"}).DisplayVersion
New-ItemProperty -Path $RegistryPath -Name "FSL Version" -Value $FSLVersion -Force


# Execute BGInfo as Tray icon, if already executed end process before
$BGInfoID = (Get-Process | Where-Object {$_.ProcessName -eq "BGInfo64" -and $_.SI -eq "$CitrixSessionID"}).Id
Stop-Process -Id $BGInfoID -EA SilentlyContinue
Start-Sleep -Seconds 1
Start-Process -FilePath "$BGInfoDir\Bginfo64.exe" -ArgumentList @('/taskbar','/nolicprompt','/timer:0',"`"$BGInfoDir\$BGInfoFile`"") 

