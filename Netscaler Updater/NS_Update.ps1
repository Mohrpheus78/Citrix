# ***********************************************
# D. Mohrmann, Cancom GmbH, Twitter: @mohrpheus78
# Update Netscaler appliances with powershell
# ***********************************************

<#
.SYNOPSIS
This script installs firmware updates on Citrix Netscaler appliances with the help of a powershell module (Posh-SSH). The Powershell module will be installed if it's not available.
		
.DESCRIPTION
To install a firmware update you have to fill out the file "NS.csv". Just add the name and the IP addresses of your netscalers. Put the current firmware file in the root folder before you start. 
You can also add your own download url's for your Netscaler VPX firmware, just add the URL's for the variables $NS13_1_DownloadURL and $NS13_DownloadURL.
Before the update process starts, you can cleanup the update and flash folder.

.EXAMPLE
NS.csv:

Name	IP
NSLB01	172.27.10.112
NSLB02	172.27.10.113


.PARAMETER
No parameters needed

.NOTES
Version: 1.1
11/27/23: Changed timeout for reboot
#>

#Logfile
$Date = Get-Date -format yyyy-MM-dd-hh-mm-ss
$NSUpdateLog = "$PSScriptRoot\NS-Update-$Date.log"


# FUNCTION Logging
#========================================================================================================================================
Function DS_WriteLog {
    
    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory=$true, Position = 0)][ValidateSet("I","S","W","E","-",IgnoreCase = $True)][String]$InformationType,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text
    )
 
    begin {
    }
 
    process {
     $DateTime = (Get-Date -format yyyy-MM-dd) + " " + (Get-Date -format HH:mm:ss)
	
	 IF (-not(Test-Path -Path $NSUpdateLog)) {
	    New-Item -Path $NSUpdateLog -ItemType File -Force | out-null
	}	
        if ( $Text -eq "" ) {
            Add-Content $NSUpdateLog -value ("") # Write an empty line
        } Else {
         Add-Content $NSUpdateLog -value ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
        }
    }
 
    end {
    }
}
#========================================================================================================================================

# FUNCTION Save-Download
#========================================================================================================================================
function Save-Download {
    [CmdletBinding()]
    param (
          [Parameter(Mandatory = $true, ValueFromPipeline)]
          [Microsoft.PowerShell.Commands.WebResponseObject]
          $WebResponse
    )

    $errorMessage = "Cannot determine filename for download."
    if (!($WebResponse.Headers.ContainsKey("Content-Disposition"))) {
        Write-Error $errorMessage -ErrorAction Stop
        }

    $content = [System.Net.Mime.ContentDisposition]::new($WebResponse.Headers["Content-Disposition"])  
    $fileName = $content.FileName
    if (!$fileName) {
        Write-Error $errorMessage -ErrorAction Stop
        }
 
    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $fileName

    Write-Verbose "Downloading to $fullPath"

    $file = [System.IO.FileStream]::new($fullPath, [System.IO.FileMode]::Create)
    $file.Write($WebResponse.Content, 0, $WebResponse.RawContentLength)
    $file.Close()
}
#========================================================================================================================================

# FUNCTION Show-Menu
#========================================================================================================================================
function Show-Menu
{
    cls
    Write-Host "Available Netcaler firmware:"
    Write-Output ""   
    Write-Host "1: $VersionNetscaler13"
    Write-Host "2: $VersionNetscaler13_1"
}
#========================================================================================================================================

# FUNCTION  RunAs Admin
#========================================================================================================================================
function Use-RunAs {    
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
            try {  
                $arg = "-WindowStyle Maximized -file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop'  
            } 
            catch { 
                Write-Warning "Error - Failed to restart script elevated"  
                BREAK               
            } 
            exit 
        }  
    }  
}
#========================================================================================================================================

Use-RunAs

# .Set NET protocol type to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Variablen
#$Root = "C:\Users\dmadmin\Documents\NS"
$CredentialConfig = (Get-ChildItem -Path $PSScriptRoot -Filter 'Credentials_$NSHost.xml').Name
$CredentialSelection = New-Object PSObject
$Netscaler = (Import-Csv -Path "$PSScriptRoot\NS.csv" -Delimiter ";")
$NS13_DownloadURL = 
$NS13_1_DownloadURL = 

# Prepare for module installation
Write-Host -ForegroundColor Cyan "Prepare for Powershell module installation"`n
DS_WriteLog "I" "Prepare for module installation"
Write-Host -ForegroundColor Cyan "Checking for nuget Package Provider"`n
DS_WriteLog "I" "Checking for nuget Package Provider"
if (!(Get-PackageProvider -Name 'nuget')) {
    try {
	    Install-PackageProvider -Name 'nuget' -Force -ForceBootstrap -Scope AllUsers
    }
    catch {
	    DS_WriteLog "E" "Something went wrong, check your internet or proxy settings, cannot download Package Provider 'nuget'"
	    Write-Host -ForegroundColor Red "Error: $($PSItem.ToString())"
	    Write-Host -ForegroundColor Red "Something went wrong, check your internet or proxy settings, cannot download Package Provider 'nuget'"
	    Read-Host "Press any key to exit"
	    BREAK
    }
}

Write-Host -ForegroundColor Cyan "Checking for PSRepository 'PSGallery'"`n
DS_WriteLog "I" "Checking for PSRepository 'PSGallery'"
try {
	if (!(Get-PSRepository -Name 'PSGallery' -EA SilentlyContinue)) {
		Write-Host -ForegroundColor Cyan "PSRepository 'PSGallery' not found, trying to register..."`n
		DS_WriteLog "I" "Checking for PSRepository 'PSGallery'"
		Register-PSRepository -Default
		}
}
    catch {
        DS_WriteLog "E" "Something went wrong, check your internet or proxy settings, cannot register PackageProvider 'PSGallery'"
	    Write-Host -ForegroundColor Red "Error: $($PSItem.ToString())"
	    Write-Host -ForegroundColor Red "Something went wrong, check your internet or proxy settings, cannot register PackageProvider 'PSGallery'"
	    Read-Host "Press any key to exit"
	    BREAK
    }

Write-Host -ForegroundColor Cyan "Checking installation policy for PSRepository 'PSGallery'"`n
DS_WriteLog "I" "Checking installation policy for PSRepository 'PSGallery'"
$PSGallery = (Get-PSRepository -Name 'PSGallery').InstallationPolicy
if ($PSGallery -ne 'Trusted') {
	Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
}
	
Write-Host -ForegroundColor Cyan "Checking Posh-SSH module... please wait"`n
DS_WriteLog "I" "Checking Posh-SSH module... please wait"
    IF (!(Get-Module -ListAvailable -Name Posh-SSH)) {
        try {
            DS_WriteLog "I" "Module not found, installing Posh-SSH module"
            Write-Host -ForegroundColor Cyan "Module not found, installing Posh-SSH module"`n
            Install-Module Posh-SSH -Force | Import-Module Posh-SSH
        }
        catch {
            DS_WriteLog "E" "Something went wrong, check your PSGallery settings or proxy settings"
            Write-Host -ForegroundColor Red "Error: $($PSItem.ToString())"
	        Write-Host "Something went wrong, check your PSGallery settings or proxy settings"
	        Read-Host "Press any key to exit"
	        BREAK
        }
    }


# Check for Updates
$LocalPoshSSHVersion = (Get-Module -Name Posh-SSH -ListAvailable | Select-Object -First 1).Version
$CurrentPoshSSHVersion = (Find-Module -Name Posh-SSH -Repository PSGallery).Version
IF (($LocalPoshSSHVersion -lt $CurrentPoshSSHVersion)) {
    try {
        DS_WriteLog "I" "Updating Posh-SSH module"
        Write-Host -ForegroundColor Cyan "Updating Posh-SSH module"`n
        Update-Module Posh-SSH -force
    }
    catch {
        DS_WriteLog "E" "Something went wrong, check your PSGallery settings or proxy settings"
        Write-Host -ForegroundColor Red "Error: $($PSItem.ToString())"
	    Write-Host "Something went wrong, check your PSGallery settings or proxy settings"
	    Read-Host "Press any key to exit"
	    BREAK
    }
}

# Netscaler selection
DS_WriteLog "I" "Checking current configuration..."
Write-Host -ForegroundColor Cyan "Checking current configuration..."`n
IF (!(Test-Path -Path "$PSScriptRoot\NS.csv")) {
    DS_WriteLog "E" "Netscaler Configuration not found!"
	Write-Host -ForegroundColor Red "Netscaler Configuration not found!"
    Write-Host "Please define your Netscaler hosts in the CSV file"
}
ELSE {
    $Netscaler = (Import-Csv -Path "$PSScriptRoot\NS.csv" -Delimiter ";")
    $AllNS = $Netscaler
    # Add property "ID" to object
    $ID = 1
    $AllNS | ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name "ID" -Value $ID 
        $ID += 1
    }
}


# Show menu to select Netscaler
Write-Host "Available Netscaler Hosts:" `n 
$ValidChoices = 1..($AllNS.Count)
$Menu = $AllNS | ForEach-Object {(($_.ID).toString() + "." + " " +  $_.Name + " " + "-" + " " + $_.IP)}
$Menu | Out-Host
Write-Host
$SelectedNSHost = Read-Host -Prompt 'Select Netscaler hosts'

$SelectedNSHost = $AllNS | Where-Object {$_.ID -eq $SelectedNSHost}
if ($SelectedNSHost.ID -notin $ValidChoices) {
    Write-Host -ForegroundColor Red "Selected Netscaler host not found, aborting!"
	Read-Host "Press any key to exit"
	BREAK
}
$NSHost = $SelectedNSHost.Name
$NSHostIP = $SelectedNSHost.IP
DS_WriteLog "I" "Selected host is $NSHost / IP: $NSHostIP"

if (Test-Path -Path "$PSScriptRoot\Credentials_$NSHost.xml") {
    $CredentialConfig = (Get-ChildItem -Path $PSScriptRoot -Filter "Credentials_$NSHost.xml").Name
    DS_WriteLog "I" "Credentials found for Netscaler '$NSHost'"
    Write-Host `n
    Write-Host -ForegroundColor Cyan "Credentials found for Netscaler '$NSHost'"`n
	$CredentialsXML = Import-Clixml -Path "$PSScriptRoot\$CredentialConfig"
	$Username = $CredentialsXML.UserName
	IF ($CredentialsXML.UserName) {
        $title = ""
		$message = "Do you want to use the credentials for user '$Username'?"
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
    }

    IF ($Answer1 -eq "Yes") {
        $Username = $CredentialsXML.UserName
	    Add-member -inputobject $CredentialSelection -MemberType NoteProperty -Name "UserName" -Value $UserName -Force
	}

    IF ($Answer1 -eq "No") {
        DS_WriteLog "I" "Configure your Netscaler admin account and password once, the password is encrypted and only valid for the current user account!"
	    Write-Host -ForegroundColor Yellow "Configure your Netscaler admin account and password once, the password is encrypted and only valid for the current user account!"`n
        Read-Host "Press ENTER to continue..."
	    Get-Credential -UserName nsroot -Message "Netscaler account" | Export-CliXml  -Path "$PSScriptRoot\Credentials_$NSHost.xml"
	}	
    $Credentials = Import-CliXml -Path "$PSScriptRoot\Credentials_$NSHost.xml"
}

ELSE {
    DS_WriteLog "I" "Configure your Netscaler admin account and password once, the password is encrypted and only valid for the current user account!"
	Write-Host -ForegroundColor Yellow "Configure your Netscaler admin account and password once, the password is encrypted and only valid for the current user account!"`n
    Read-Host "Press ENTER to continue..."
	Get-Credential -UserName nsroot -Message "Netscaler account" | Export-CliXml  -Path "$PSScriptRoot\Credentials_$NSHost.xml"
	}	
$Credentials = Import-CliXml -Path "$PSScriptRoot\Credentials_$NSHost.xml"

# Current versions
$URLVersionNetscaler13 = "https://www.citrix.com/content/citrix/en_us/downloads/citrix-adc.rss"
$webRequestNetscaler13 = Invoke-WebRequest -UseBasicParsing -Uri ($URLVersionNetscaler13) -SessionVariable websession
$regexVersionNetscaler13 = 'Citrix ADC Release \(Maintenance Phase\) 13\.0 Build [0-9]*\.[0-9]+/[0-9]*\.[0-9]+'
$VersionNetscaler13 = $webRequestNetscaler13.RawContent | Select-String -Pattern $regexVersionNetscaler13 -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -First 1
$VersionNetscaler13 = $VersionNetscaler13.Replace("Citrix ADC Release ","")

$URLVersionNetscaler13_1 = "https://www.citrix.com/content/citrix/en_us/downloads/citrix-adc.rss"
$webRequestNetscaler13_1 = Invoke-WebRequest -UseBasicParsing -Uri ($URLVersionNetscaler13_1) -SessionVariable websession
$regexVersionNetscaler13_1 = 'Citrix ADC Release \(Maintenance Phase\) 13\.1 Build \d\d\.\d\d'
$VersionNetscaler13_1 = $webRequestNetscaler13_1.RawContent | Select-String -Pattern $regexVersionNetscaler13_1 -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -First 1
$VersionNetscaler13_1 = $VersionNetscaler13_1.Replace("Citrix ADC Release ","")

Show-Menu
Write-Output ""
$input = Read-Host "Select the Netscaler firmware for your update"
switch ($input) {
'1' {
    cls
    Write-Host -ForegroundColor Yellow "You selected firmware '$VersionNetscaler13'"`n
    }
'2' {
    cls
    Write-Host -ForegroundColor Yellow "You selected firmware '$VersionNetscaler13_1'"`n
    } 
}

$NewBuild = (Get-ChildItem -Path $PSScriptRoot -Filter "build*").Name
if ([string]::ISNullOrEmpty( $NewBuild) -eq $true) {
    try {
        DS_WriteLog "I" "Trying to download current Netscaler firmware"
        Write-Host -ForegroundColor Cyan "Trying to download current Netscaler firmware..."`n
        IF ($input -eq '1') {
            $download_NS13 = Invoke-WebRequest -Uri $NS13_DownloadURL
            $download_NS13 | Save-Download
            }
        IF ($input -eq '2') {
            $download_NS13_1 = Invoke-WebRequest -Uri $NS13_1_DownloadURL
            $download_NS13_1 | Save-Download
            }

        DS_WriteLog "I" "Netscaler firmware download successful"
        Write-Host -ForegroundColor Yellow "Netscaler firmware download successful"`n
        $NewBuild = (Get-ChildItem -Path $PSScriptRoot -Filter "build*").Name
        $NewBuildTrim = $NewBuild.TrimStart("build-").Insert(0,"ns-")
        DS_WriteLog "I" "Found Netscaler update firmware version: $NewBuild"
        Write-Host -ForegroundColor Yellow "Found Netscaler version: $NewBuild"`n
    }
    catch {
        DS_WriteLog "E" "No firmware file found, please place a current firmware in the folder '$PSScriptRoot'"
        Write-Host -ForegroundColor Red "No firmware file found, please place a current firmware in the folder '$PSScriptRoot'"
        Read-Host "Press any key to exit"
        BREAK
     }
}
else {
    DS_WriteLog "I" "Found Netscaler update firmware version: $NewBuild"
    Write-Host -ForegroundColor Yellow "Found Netscaler version: $NewBuild"`n
    $NewBuildTrim = $NewBuild.TrimStart("build-").Insert(0,"ns-")
}

try { 
    DS_WriteLog "I" "SSH connect to $NSHost..."
    Write-Host -ForegroundColor Cyan "SSH connect to $NSHost..."`n
	$SSHSession = New-SSHSession -ComputerName $NSHostIP -Credential $Credentials -AcceptKey -ConnectionTimeout 90
}
catch {
    DS_WriteLog "E" "Error connecting to '$NSHost', check configuration!"
	Write-Host "Error connecting to '$NSHost', check configuration! (Error: $($Error[0]))"
    Read-Host "Press any key to exit"
	BREAK

}
$CurrentBuild = (Invoke-SSHCommand -Command "show ns version" -SessionId $SSHSession.SessionId).Output.trimstart() | Select-Object -Skip 1 -Last 1
$CurrentBuild = $CurrentBuild.Split(",") | Select-Object -First 1
$CurrentBuild = $CurrentBuild -replace("Netscaler ","")

if ((Invoke-SSHCommand -Command "show ha node" -SessionId $SSHSession.SessionId).Output.trimstart() | findstr "2)") {
    $HANode = "True"
}

$Node = (Invoke-SSHCommand -Command "show config" -SessionId $SSHSession.SessionId).Output.trimstart() | findstr "Node"
$Node = $Node.Split("(")[0]
$Platform = (Invoke-SSHCommand -Command "show ns hardware" -SessionId $SSHSession.SessionId).Output.trimstart() | findstr "Virtual"

DS_WriteLog "I" "Current Netscaler version is $CurrentBuild, $Node, $Platform"
Write-Host -ForegroundColor Yellow "Current Netscaler version is $CurrentBuild, $Node"`n

if ($Node -like "*Primary*" -and $HANode -eq "True") {
    DS_WriteLog "E" "You are connected to a primary node! Connect to secondary node and start again."
    Write-Host -ForegroundColor Red "You are connected to a primary node! Connect to secondary node and start again."
    Read-Host "Press any key to exit"
    BREAK
 }

if ($Node -like "*Secondary*" -and $HANode -eq "True") {
    DS_WriteLog "I" "Save config on primary node"
    Write-Host -ForegroundColor Cyan "Save config on primary node"`n
    $NodePrimary = (Invoke-SSHCommand -Command "show config" -SessionId $SSHSession.SessionId).Output.trimstart() | findstr "Node"
    $NodePrimary = $NodePrimary.Split("(")[1].TrimStart("Primary is ").TrimEnd(")")
    $SSHSessionPrimary = New-SSHSession -ComputerName $NodePrimary -Credential $Credentials -AcceptKey -ConnectionTimeout 90
    Invoke-SSHCommand -Command "shell save config" -SessionId $SSHSessionPrimary.SessionId | Out-Null
    }


$Dir = (Invoke-SSHCommand -Command "shell ls -d /var/nsinstall/*/" -SessionId $SSHSession.SessionId).Output.trimstart() | Select-Object -Skip 1 | select -SkipLast 1
if ($Dir -like '/var*') {
    DS_WriteLog "I" "Found the following directories on the Netscaler: $Dir"
    Write-Host -ForegroundColor Yellow "Found the following directories on the Netscaler: $Dir"`n
    $title = ""
    $message = "Do you want to delete old firmware update folders to clean up space on the Netscaler?"
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

    if ($Answer1 -eq 'Yes') {
        try {
            DS_WriteLog "I" "Deleting old directories"
            Write-Host -ForegroundColor Cyan "Deleting old directories"`n
            Invoke-SSHCommand -Command "shell rm -r /var/nsinstall/*/" -SessionId $SSHSession.SessionId | Out-Null
            Invoke-SSHCommand -Command "shell rm -r /var/crash/*" -SessionId $SSHSession.SessionId | Out-Null
        }
        catch {
            DS_WriteLog "E" "Error deleting old directories"
	        Write-Host "Error deleting old directories (Error: $($Error[0]))"
            Read-Host "Press any key to exit"
	        BREAK
	    }
    }
}

#if ($Answer1 -eq 'No') {
    $Flash = @(Invoke-SSHCommand -Command "shell ls -d /flash/*.gz" -SessionId $SSHSession.SessionId).Output.trimstart() | Select-Object -Skip 1 | select -SkipLast 2
    
    if ($Flash -like '/flash*') {
        DS_WriteLog "I" "Found old builds in flash directory: $Flash"
        Write-Host -ForegroundColor Yellow "Found old builds in flash directory: $Flash"`n
        $title = ""
        $message = "Do you want to delete old builds to clean up space on the Netscaler?"
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

        if ($Answer2 -eq 'Yes') {
            try {
                DS_WriteLog "I" "Deleting old builds"
                Write-Host -ForegroundColor Cyan "Deleting old builds"`n
                Invoke-SSHCommand -Command "shell rm -r $Flash[0]" -SessionId $SSHSession.SessionId | Out-Null
                }
            catch {
                DS_WriteLog "E" "Error deleting old builds"
	            Write-Host "Error deleting old builds (Error: $($Error[0]))"
                Read-Host "Press any key to exit"
	            BREAK
	        }
        }
    }
#}


$title = ""
$message = "Do you want to update to '$NewBuild'?"
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

if ($Answer3 -eq 'Yes') {      
    try {
        DS_WriteLog "I" "Creating directory '$NewBuild' for the new NS build"
        Write-Host -ForegroundColor Cyan "Creating directory '$NewBuild' for the new NS build"`n
        Invoke-SSHCommand -Command "shell mkdir /var/nsinstall/$NewBuild" -SessionId $SSHSession.SessionId | Out-Null
        }
    catch {
        DS_WriteLog "E" "Error creating directory '$NewBuild'"
        Write-Host -ForegroundColor Red "Error creating directory '$NewBuild', try again! (Error: $($Error[0]))"
        Read-Host "Press any key to exit"
        BREAK
        }
    }
else {
		DS_WriteLog "E" "Update process terminated by user"
		Write-Host -ForegroundColor Red "Update process terminated by user"
        Read-Host "Press any key to exit"
		BREAK
}

try {
    DS_WriteLog "I" "Connecting to '$NSHost' via SFTP"
    Write-Host -ForegroundColor Cyan "Connecting to '$NSHost' via SFTP"`n
	$SFTPSession = New-SFTPSession -ComputerName $NSHostIP -Credential $Credentials
}
catch {
    DS_WriteLog "E" "Error connecting to '$NSHost', check configuration!"
	Write-Host -ForegroundColor Red "Error connecting to '$NSHost', check configuration! (Error: $($Error[0]))"
    Read-Host "Press any key to exit"
	BREAK
}

try {
    DS_Writelog "I" "Uploading new firmware '$NewBuild' to '$NSHost'"
    Write-Host -ForegroundColor Cyan "Uploading new firmware '$NewBuild' to '$NSHost'"`n
    Set-SFTPItem -SessionId $SFTPSession.SessionId -Path "$PSScriptRoot\$NewBuild" -Destination "/var/nsinstall/$NewBuild" | Out-Null
    DS_Writelog "E" "Error uploading firmware '$NewBuild' to '$NSHost'"
    Write-Host -ForegroundColor Red "Error: $($Error[0])"
   }
catch {
     DS_WriteLog "E" "Error uploading firmware '$NewBuild'"
     Write-Host -ForegroundColor Red "Error uploading firmware '$NewBuild', try again! (Error: $($Error[0]))"
     Read-Host "Press any key to exit"
     BREAK
}

Do {
    try {
        $ConnectionTimeout = 0
        $SSHStream = New-SSHShellStream -SessionId $SSHSession.SessionId -EA SilentlyContinue
        Start-Sleep -seconds 3
	    $connectiontimeout++
    }
    catch {
        DS_WriteLog "E" "Error connecting to $NSHost"
	    Write-Host "Error connecting to $NSHost (Error: $($Error[0]))"
        Read-Host "Press any key to exit"
	    BREAK
	}
} Until ($SSHStream.CanRead -match "True" -or $connectiontimeout -ge 3)

try {
    $SSHStream.WriteLine("shell")
    Start-Sleep -s 1
    $SSHStream.read()
    
    $SSHStream.WriteLine("cd /var/nsinstall/$NewBuild/")
    Start-Sleep -s 1
    $SSHStream.read()
    
    DS_WriteLog "I" "Unpacking firmware '$NewBuild'"
    Write-Host `n
    Write-Host -ForegroundColor Cyan "Unpacking firmware '$NewBuild'"`n
    $SSHStream.WriteLine("tar -xzvf $NewBuild")
    Start-Sleep -s 60
    $SSHStream.read()
}
catch {
    DS_WriteLog "E" "Error unpacking firmware"
    Write-Host -ForegroundColor Red "Error unpacking firmware (Error: $($Error[0]))"
    Read-Host "Press any key to exit"
    BREAK
}
    
try {
    DS_WriteLog "I" "Updating '$NSHost' to '$NewBuild', please wait..."
    Write-Host `n
    Write-Host -ForegroundColor Cyan "Updating '$NSHost' to '$NewBuild', please wait..."`n
    $SSHStream.WriteLine("./installns")
    Start-Sleep -s 1
    $SSHStream.read()

    $SSHStream.WriteLine("Y")
    Start-Sleep -s 120
    $SSHStream.read()

    DS_WriteLog "I" "Restarting '$NSHost'"
    Write-Host -ForegroundColor Cyan "Restarting '$NSHost'"`n
    $SSHStream.WriteLine("Y")
    Start-Sleep -s 1
    #$SSHStream.read()
}
catch {
    DS_WriteLog "E" "Error updating firmware"
	Write-Host -ForegroundColor Red "Error updating firmware (Error: $($Error[0]))"
    Read-Host "Press any key to exit"
	BREAK
}

Start-Sleep -s 60

Do {
    $connectiontimeout = 0
    try {
        DS_WriteLog "I" "Waiting for reboot, connecting to '$NSHost'"
        Write-Host -ForegroundColor Cyan "Waiting for reboot, connecting to '$NSHost', please wait..."`n
        Start-Sleep -s 5
	    $SSHSession = New-SSHSession -ComputerName $NSHostIP -Credential $Credentials -AcceptKey -ConnectionTimeout 120 -EA SilentlyContinue
	    Start-Sleep -seconds 5
	    $connectiontimeout++
    }
    catch {
        DS_WriteLog "E" "Error connecting to $NSHost"
	    Write-Host -ForegroundColor Red "Error connecting to $NSHost (Error: $($Error[0]))"
        Read-Host "Press any key to exit"
	    BREAK
	}
} Until ($SSHSession.Connected -match "True" -or $connectiontimeout -ge 10)

$CurrentBuild = (Invoke-SSHCommand -Command "show ns version" -SessionId $SSHSession.SessionId).Output.trimstart() | Select-Object -Skip 1 -Last 1
$CurrentBuild = $CurrentBuild.Split(",") | Select-Object -First 1
$CurrentBuild = $CurrentBuild -replace("Netscaler ","")

DS_WriteLog "I" "Current Netscaler version is $CurrentBuild"
Write-Host -ForegroundColor Yellow "Current Netscaler version is $CurrentBuild"`n

$title = ""
    $message = "Is this the correct version?"
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

    if ($Answer4 -eq 'Yes') {
        try {
            $SSHSession = New-SSHSession -ComputerName $NSHostIP -Credential $Credentials -ConnectionTimeout 120 -AcceptKey -EA SilentlyContinue
        }
        catch {
            DS_WriteLog "E" "Error connecting to $NSHost"
	        Write-Host -ForegroundColor Red  "Error connecting to $NSHost (Error: $($Error[0]))"
            Read-Host "Press any key to exit"
	        BREAK
	    }

        if ((Invoke-SSHCommand -Command "show ha node" -SessionId $SSHSession.SessionId).Output.trimstart() | findstr "2)") {
			$HANode = "True"
		}
		
        $Node = (Invoke-SSHCommand -Command "show config" -SessionId $SSHSession.SessionId).Output.trimstart() | findstr "Node"
        if ($Node -notlike "*Standalone*") {
            $Node = $Node.Split("(")[0]
            $NodePrimary = (Invoke-SSHCommand -Command "show config" -SessionId $SSHSession.SessionId).Output.trimstart() | findstr "Node"
            $NodePrimary = $NodePrimary.Split("(")[1].TrimStart("Primary is ").TrimEnd(")")
            }
		
        if ($Node -like "*Secondary*" -and $HANode -eq "True") {
            $title = ""
            $message = "Are you finished? Is this the second node in your HA cluster you updated?"
            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
	        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
            $choice=$host.ui.PromptForChoice($title, $message, $options, 1)
	        switch ($choice) {
	            0 {
	                $Answer5 = 'Yes'       
		            }
		        1 {
			        $Answer5 = 'No'
			        }
	        }
			
            if ($Answer5 -eq 'Yes') {
                try {
                     DS_WriteLog "I" "Enable HA sync on secondary node"
				     Write-Host -ForegroundColor Cyan "Enable HA sync on secondary node"`n                 
				     $SSHStream = New-SSHShellStream -SessionId $SSHSession.SessionId
					 $SSHStream.WriteLine("set node -hasync enable")
                     Start-Sleep -s 1
                     $SSHStream.read()
                     DS_WriteLog "I" "Enable HA sync on primary node"
				     Write-Host -ForegroundColor Cyan "Enable HA sync on primary node"`n   
                     $SSHSessionPrimary =New-SSHSession -ComputerName $NodePrimary -Credential $Credentials -AcceptKey -ConnectionTimeout 90
                     $SSHStreamPrimary = New-SSHShellStream -SessionId $SSHSessionPrimary.SessionId
					 $SSHStreamPrimary.WriteLine("set node -hasync enable")
                     $SSHStreamPrimary.read()
                     Start-Sleep -s 1
                     $SSHStreamPrimary.WriteLine("save config")
					 Start-Sleep -s 1
                     $SSHStreamPrimary.read()
                }
                catch {
					   DS_WriteLog "E" "Error while executing 'force failover' or 'Disable HA sync'"
					   Write-Host "Error while executing 'force failover or Disable HA sync' (Error: $($Error[0]))"
                       Read-Host "Press any key to exit"
					   BREAK
				}
                DS_WriteLog "I" "Update successfully finished!"
                Write-Host -ForegroundColor Cyan "Update successfully finished!"`n
                Write-Host -ForegroundColor Cyan "Check the configuration of the Netscaler you just updated"`n
                Read-Host "Press any key to exit"
                BREAK
            }

            if ($Answer5 -eq 'No') {
				Write-Host -ForegroundColor Cyan "Check the configuration of the Netscaler you just updated"`n                 
				$title = ""
				$message = "Do you want to disable HA sync and execute 'force failover' to update the next node?"
				$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
				$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
				$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
				$choice=$host.ui.PromptForChoice($title, $message, $options, 0)
				switch ($choice) {
					0 {
						$Answer6 = 'Yes'       
						}
					1 {
						$Answer6 = 'No'
						}
				}
				if ($Answer6 -eq 'Yes') {
					try {
                        DS_WriteLog "I" "Disable HA sync"
						Write-Host -ForegroundColor Cyan "Disable HA sync"`n
						$SSHStream = New-SSHShellStream -SessionId $SSHSession.SessionId
						$SSHStream.WriteLine("set node -hasync disable")
						Start-Sleep -s 1
						$SSHStream.read()
                        
                        DS_WriteLog "I" "Execute force failover"
						Write-Host -ForegroundColor Cyan "Execute force failover"`n
						#$SSHStream = New-SSHShellStream -SessionId $SSHSession.SessionId
						$SSHStream.WriteLine("force failover")
						Start-Sleep -s 1
						$SSHStream.read()

						$SSHStream.WriteLine("Y")
						Start-Sleep -s 1
						#$SSHStream.read()
						DS_WriteLog "I" "Update successfully, please update the other (new secondary) node!"
						Write-Host -ForegroundColor Cyan "Update successfully, please update the other (new secondary) node!"
						}
					catch {
						DS_WriteLog "E" "Error while executing 'force failover' or 'Disable HA sync'"
						Write-Host "Error while executing 'force failover or Disable HA sync' (Error: $($Error[0]))"
                        Read-Host "Press any key to exit"
						BREAK
						}
				}
				else {
						DS_WriteLog "I" "Update successfully, please execute 'force failover' and disable HA sync to update the primary node!"
						Write-Host -ForegroundColor Cyan "Update successfully, please execute 'force failover' and disable HA sync to update the primary node!"
						}
			}
		}
	
	#if ($Node -like "*Primary*" -and $HANode -eq "False") {
    if ($Node -like "*Standalone*") {
		DS_WriteLog "I" "Update successfully"
		Write-Host -ForegroundColor Cyan "Update successfully"`n
        Write-Host -ForegroundColor Cyan "Check the configuration of the Netscaler you just updated"`n
		}
		
	}
	if ($Answer4 -eq 'No') {
		DS_WriteLog "E" "Something went wrong with the update, please check Netscaler and logs and try again!"
	    Write-Host -ForegroundColor Red "Somethin went wrong with the update, please check Netscaler and logs and try again!"
        Read-Host "Press any key to exit"
	    BREAK
	}

Rename-Item -Path $NSUpdateLog -NewName "NS-Update-$NSHost-$Date.log"

 
