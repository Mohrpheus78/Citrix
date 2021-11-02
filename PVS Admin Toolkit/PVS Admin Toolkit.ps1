<#
.SYNOPSIS
This script will create a systray icon with a menu to launch the other PVS admin scripts.
	
.DESCRIPTION
The purpose of the script is to create a systray icon to launch the PVS admin scripts in the folder "C:\Program Files (x86)\Scripts".

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-27
Purpose/Change:	
2021-10-30		Inital version
#>

# Force garbage collection just to start slightly lower RAM usage
[System.GC]::Collect()

# Declare assemblies 
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework')   | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')    | out-null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null
 
# Add an icon to the systray
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Program Files\Citrix\Provisioning Services\MCLI.exe")
 
# Create object for the systray 
$Systray_Tool_Icon = New-Object System.Windows.Forms.NotifyIcon

# Text displayed when you pass the mouse over the systray icon
$Systray_Tool_Icon.Text = "PVS Admin Toolkit"

# Systray icon
$Systray_Tool_Icon.Icon = $icon
$Systray_Tool_Icon.Visible = $true

# Create object for the systray 
$contextmenu = New-Object System.Windows.Forms.ContextMenuStrip

# Create Menus
$Menu_1 = $contextmenu.Items.Add("PVS Console");
$Menu_1.Image = $icon

$Menu_2 = $contextmenu.Items.Add("vDisk Maintenance");

$Menu_3 = $contextmenu.Items.Add("Document vDisk versions");
$Menu_3.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Documentation\PVS vDisk versions.png")

$Menu_4 = $contextmenu.Items.Add("Merge vDisk");
$Menu_4.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Merge\Merge PVS vDisk.png")

$Menu_5 = $contextmenu.Items.Add("Replicate vDisk");
$Menu_5.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Replication\Replicate PVS vDisk.png")

$Menu_6 = $contextmenu.Items.Add("Export all vDisks (XML)");
$Menu_6.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Export\Export PVS vDisk.png")

$Menu_7 = $contextmenu.Items.Add("Shrink vDisk");
$Menu_7.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Shrink\Shrink PVS vDisk.png")

$Menu_Exit = $contextmenu.Items.Add("Exit");
$Menu_Exit.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\Exit.png")


#Sub menus for Menu 2
$Menu2_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu2_SubMenu1.Text = "New vDisk version"
$Menu2_SubMenu1.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\New PVS vDisk version.png")
$Menu_2.DropDownItems.Add($Menu2_SubMenu1)
 
$Menu2_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu2_SubMenu2.Text = "Promote vDisk version"
$Menu2_SubMenu2.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\Promote PVS vDisk version.png")
$Menu_2.DropDownItems.Add($Menu2_SubMenu2)

# Add the context menu object to the main systray tool object
$Systray_Tool_Icon.ContextMenuStrip = $contextmenu;

# Action after clicking
$Menu_1.add_Click({ 
    start-process "C:\Program Files\Citrix\Provisioning Services Console\Console.msc"
	})

$Menu2_SubMenu1.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Maintenance\New PVS vDisk version.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu2_SubMenu2.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Maintenance\Promote PVS vDisk version.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_3.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Documentation\PVS vDisk versions.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_4.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Merge\Merge PVS vDisk.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_5.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Replication\Replicate PVS vDisk.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_6.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Export\Export PVS vDisk.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_7.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Shrink\Shrink PVS vDisk.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

# Make PowerShell Disappear
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

# Action after click Exit
$Menu_Exit.add_Click({
	$Systray_Tool_Icon.Visible = $false 
	Stop-Process $pid
	})
 
# Create an application context for it to all run within.
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)


