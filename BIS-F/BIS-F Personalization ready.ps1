# ****************************************************
# D. Mohrmann, S&L Firmengruppe, Twitter: @mohrpheus78
# Toast notification if BIS-F personalization is ready
# 1/2
# ****************************************************

<#
.SYNOPSIS
This script will get the session ID of the currently logged in user and calls another script in the context of this user, to show a
toast notification that BIS-F personalizationis ready. Use with Base Image Script Framework, place the script in the folder
"C:\Program Files (x86)\Base Image Script Framework (BIS-F)\Framework\SubCall\Personalization\Custom", it will be launched by the BIS-F scheduled task at logon

.DESCRIPTION
The script will first find out what locale settings the user has configured and then show the toast notification
   
.NOTES
Edit the PSexec installation path
#>

# psexec location
$psexeclocation = "${env:ProgramFiles(x86)}\Sysinternals"

# Function to get the active user session
Function Get-TSSessions {
    qwinsta |
    #Parse output
    ForEach-Object {
    $_.Trim() -replace "\s+",","
    } |
    #Convert to objects
    ConvertFrom-Csv
}

# Get session ID
$SessionID = (Get-TSSessions | Where-Object "STATE" -EQ "Active").ID

# Lauch psexec in the context of the user to show the toast notification
.$psexeclocation\PsExec.exe -accepteula -s -i $SessionID powershell.exe -Executionpolicy bypass -file "${env:ProgramFiles(x86)}\Base Image Script Framework (BIS-F)\Framework\SubCall\Personalization\Custom\SubCall\BIS-F toast notification.ps1"