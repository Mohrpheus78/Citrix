<#
.SYNOPSIS
This script will generate a HTML report of your current vDisk versions
	
.DESCRIPTION
The purpose of the script is, that you have a documentation of your vDisk versions, especially the descriptions of the versions that get lost after merging 

.PARAMETER -outputpath
The path where the report is saved

.EXAMPLE
& '.\PVS vDisk versions.ps1' -Sitename Testlab -outputpath C:\Users\admin\Desktop

.NOTES
The script is based on the excellent PVS Health Check script from Sacha Thomet (@sacha81): https://github.com/sacha81/citrix-pvs-healthcheck/blob/master/Citrix-PVS-Farm-Health-toHTML_Parameters.xml
I used most of the code and added the decription, there is also no need of the XML file. 

Version:		1.0
Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-16
Purpose/Change:	
2021-10-16		Inital version
2021-10-17		changed HTML style
2021-10-18		added parameters and vDisk type
#>

[CmdletBinding()]

param (
		# Path to HTML Report
		[Parameter(Mandatory = $true)]
		[ValidateNotNull()]
		[ValidateNotNullOrEmpty()]
		[Array]$outputpath
	  )

# Check if PVS SnapIn is available
if ($null -eq (Get-PSSnapin "Citrix.PVS.SnapIn" -EA silentlycontinue)) {
	try {
		Add-PSSnapin Citrix.PVS.SnapIn -ErrorAction Stop
	}
	catch {
		write-error "Error loading Citrix.PVS.SnapIn PowerShell snapin"; Return }
	}
	
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

#$ReportDate = (Get-Date -UFormat "%A, %d. %B %Y %R")
#==============================================================================================

Write-Host -ForegroundColor Yellow "PVS vDisk version documentation" `n

$outputdate = Get-Date -Format 'yyyy-MM-dd'
$logfile = Join-Path $psscriptroot ("PVS vDisk Version.log")
$resultsHTM = Join-Path $outputpath ("PVS vDisk Versions-$outputdate.htm") #add $outputdate in filename if you like

#Header for Table 1 "vDisk Checks"
$vDiksFirstheaderName = "vDisk Name"
$vDiskheaderNames = "Site", "Store", "vDiskFileName", "Version", "Type", "CreateDate" , "ReplState", "Description"
$vDiskheaderWidths = "auto","auto","auto","auto","auto","auto","auto","auto"
$vDisktablewidth = "1400"
 
#==============================================================================================
#log function
function LogMe() {
    Param(
    [parameter(Mandatory = $true, ValueFromPipeline = $true)] $logEntry,
    [switch]$display,
    [switch]$err,
    [switch]$warning,
    [switch]$progress
    )
 
    if ($err) {
    $logEntry = "[ERROR] $logEntry" ; Write-Host "$logEntry" -Foregroundcolor Red}
    elseif ($warning) {
    Write-Warning "$logEntry" ; $logEntry = "[WARNING] $logEntry"}
    elseif ($progress) {
    Write-Host "$logEntry" -Foregroundcolor Green}
    elseif ($display) {
    Write-Host "$logEntry"
    }
  
    #$logEntry = ((Get-Date -uformat "%D %T") + " - " + $logEntry)
    $logEntry | Out-File $logFile -Append
}

#==============================================================================================
Function writeHtmlHeader {
param($title, $fileName)
#$date = $ReportDate
$head = @"
<html>
<head>
<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
<title>$title</title>
<STYLE TYPE="text/css">
<!--
td {
font-family: Tahoma;
font-size: 13px;
border-top: 1px solid #999999;
border-right: 1px solid #999999;
border-bottom: 1px solid #999999;
border-left: 1px solid #999999;
padding-top: 0px;
padding-right: 0px;
padding-bottom: 0px;
padding-left: 0px;
overflow: hidden;
}
body {
margin-left: 5px;
margin-top: 5px;
margin-right: 0px;
margin-bottom: 10px;
table {
table-layout:fixed; 
border: thin solid #000000;
}
-->
</style>
</head>
<body>
<table width='1400'>
<tr bgcolor='#e6e6e6'>
<td colspan='7' height='35' align='center' valign="middle">
<font face='Tahoma' color='#313233' size='4'>
<strong>$title</strong></font>
</td>
</tr>
</table>
"@
$head | Out-File $fileName
}

# ==============================================================================================
Function writeTableHeader {
param($fileName, $firstheaderName, $headerNames, $headerWidths, $tablewidth)
$tableHeader = @"
<table width='$tablewidth'><tbody>
<tr bgcolor=#e6e6e6>
<td width='auto' align='left'><strong>$firstheaderName</strong></td>
"@
$i = 0
    while ($i -lt $headerNames.count) {
    $headerName = $headerNames[$i]
    $headerWidth = $headerWidths[$i]
    $tableHeader += "<td width='" + $headerWidth + "' 'align='left'><strong>$headerName</strong></td>"
    $i++
    }
$tableHeader += "</tr>"
$tableHeader | Out-File $fileName -append
}

#==============================================================================================
Function writeData {
param($data, $fileName, $headerNames)
  
 $data.Keys | sort | ForEach-Object {
$tableEntry += "<tr>"
$computerName = $_
$tableEntry += ("<td bgcolor='#e6e6e6' align=left><font color='#313233'>$computerName</font></td>")
$headerNames | ForEach-Object {
    try {
    if ($data.$computerName.$_[0] -eq "SUCCESS") { $bgcolor = "#387C44"; $fontColor = "#FFFFFF" }
    elseif ($data.$computerName.$_[0] -eq "WARNING") { $bgcolor = "#FF7700"; $fontColor = "#FFFFFF" }
    elseif ($data.$computerName.$_[0] -eq "ERROR") { $bgcolor = "#FF0000"; $fontColor = "#FFFFFF" }
    else { $bgcolor = "#e6e6e6"; $fontColor = "#313233" }
    $testResult = $data.$computerName.$_[1]
    }
    catch {
    $bgcolor = "#e6e6e6"; $fontColor = "#313233"
    $testResult = ""
    }
  
 $tableEntry += ("<td bgcolor='" + $bgcolor + "' align=left><font color='" + $fontColor + "'>$testResult</font></td>")
 }
 $tableEntry += "</tr>"
 }
 $tableEntry | Out-File $fileName -append
}

# ===============================================================================================
function PVSvDiskCheck() {
	# ======= PVS vDisk Check #==================================================================
	"Check PVS vDisks" | LogMe -display -progress
	" " | LogMe -display -progress
	
	$AllvDisks = Get-PvsDiskInfo -SiteName $Sitename
	$global:vdiskResults = @{}
	
	foreach($vDisk in $AllvDisks )
		{
		$VDtests = @{}
		
		#VdiskName
		$vDiskName = $vDisk | %{ $_.Name }
		"Name of vDisk: $vDiskName" | LogMe -display -progress
		$vDiskName
    
        #VdiskSite
		$VdiskSite = $vDisk | %{ $_.sitename }
		"Site: $VdiskSite" | LogMe -display -progress
		$VDtests.Site = "NEUTRAL", $VdiskSite
		
		#VdiskStore
		$vDiskStore = $vDisk | %{ $_.StoreName }
		"vDiskStore: $vDiskStore" | LogMe -display -progress
		$VDtests.Store = "NEUTRAL", $vDiskStore      
		
			#Get details of each version of the vDisk: 
			$vDiskVersions = Get-PvsDiskVersion -Name $vDiskName -SiteName $VdiskSite -StoreName $vDiskStore
			
			$vDiskVersionTable = @{}
			foreach($diskVersion in $vDiskVersions){
			
			#VdiskVersionFilename
			$diskversionfilename = $diskVersion | %{ $_.DiskFileName }
			"Filename of Version: $diskversionfilename" | LogMe -display -progress
			$vDiskVersionTable.diskversionfilename += $diskversionfilename +="<br>"
			
			#VdiskVersionVersion
			$diskversionVersion = $diskVersion | %{ $_.Version }
			$StringDiskversionVersion = $diskversionVersion | Out-String
			"Version: $StringDiskversionVersion" | LogMe -display -progress
			$vDiskVersionTable.StringDiskversionVersion += $StringDiskversionVersion +="<br>"
			
			#VdiskVersionType
			$diskversionType = $diskVersion | %{ $_.Type }
			$StringDiskversionType = $diskversionType | Out-String
				if ($diskversionType -eq 4) {$StringDiskversionType = "Base"}
				if ($diskversionType -eq 1) {$StringDiskversionType = "Version"}
			"Type: $StringDiskversionType" | LogMe -display -progress
			$vDiskVersionTable.DiskversionType += $StringDiskversionType +="<br>"
			
			#VdiskVersionCreateDate
			$diskversionCreateDate = $diskVersion | %{ $_.CreateDate }
			"Create Date: $diskversionCreateDate" | LogMe -display -progress
			$vDiskVersionTable.diskversionCreateDate += $diskversionCreateDate +="<br>"

            #VdiskVersionDescription
			$diskversionDescription = $diskVersion | %{ $_.Description }
			"Description: $diskversionDescription" | LogMe -display -progress
			$vDiskVersionTable.diskversionDescription += $diskversionDescription +="<br>"
			
			#VdiskVersion ReplState (GoodInventoryStatus)
			$diskversionGoodInventoryStatus = $diskVersion | %{ $_.GoodInventoryStatus }
			$StringDiskversionGoodInventoryStatus = $diskversionGoodInventoryStatus | Out-String
			"Replication: $StringDiskversionGoodInventoryStatus" | LogMe -display -progress
			#Check if correct replicated, count Replication Errors
			Write-Host "Replication State: " $DiskversionGoodInventoryStatus
			$ReplErrorCount = 0
			if($DiskversionGoodInventoryStatus -like "True" ){
			$ReplErrorCount += 0
			 } else {
			$ReplErrorCount += 1}
			$vDiskVersionTable.StringDiskversionGoodInventoryStatus += $StringDiskversionGoodInventoryStatus +="<br>"
			#Check if correct replicated THE LAST DISK
			if($ReplErrorCount -eq 0 ){
			"$diskversionfilename correct replicated" | LogMe
			$ReplStateStatus = "SUCCESS"
			 } else {
			"$diskversionfilename not correct replicated $ReplErrorCount errors" | LogMe -display -error
			$ReplStateStatus = "ERROR"}
			}

            
			
		$VDtests.vDiskFileName = "Neutral", $vDiskVersionTable.diskversionfilename
		$VDtests.Version = "Neutral", $vDiskVersionTable.StringDiskversionVersion
		$VDtests.Type = "Neutral", $vDiskVersionTable.DiskversionType
		$VDtests.CreateDate = "Neutral", $vDiskVersionTable.diskversionCreateDate
		$VDtests.ReplState = "$ReplStateStatus", $vDiskVersionTable.StringDiskversionGoodInventoryStatus
        $VDtests.Description = "Neutral", $vDiskVersionTable.diskversionDescription
					
            #image name adds Site name in multi site reports
            if ($Sitename.count -ne 1) {$global:vdiskResults."$vDiskName ($VdiskSite)" = $VDtests}
            else {$global:vdiskResults.$vDiskName = $VDtests}

		}
	

}


#==============================================================================================
#HTML function
function WriteHTML() {
 
    # ======= Write all results to an html file =================================================
    Write-Host ("Saving results to html report: " + $resultsHTM)
    writeHtmlHeader "$EnvName" $resultsHTM
    writeTableHeader $resultsHTM $vDiksFirstheaderName $vDiskheaderNames $vDiskheaderWidths $vDisktablewidth
    $global:vdiskResults | sort-object -property ReplState | % { writeData $vdiskResults $resultsHTM $vDiskheaderNames }
}


#==============================================================================================
# == MAIN SCRIPT ==
#==============================================================================================
$scriptstart = Get-Date
rm $logfile -force -EA SilentlyContinue
"Begin with Citrix Provisioning vDisk Check" | LogMe -display -progress
" " | LogMe -display -progress

"Initiate PVS vDisk check" | LogMe
$Sitename = (Get-PvsSite).SiteName
$EnvName = "PVS vDisk Versions"
PVSvDiskCheck
WriteHTML

$scriptend = Get-Date
$scriptruntime =  $scriptend - $scriptstart | Select-Object TotalSeconds
$scriptruntimeInSeconds = $scriptruntime.TotalSeconds
"Script was running for $scriptruntimeInSeconds " | LogMe -display -progress

.$resultsHTM