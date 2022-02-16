<#
.SYNOPSIS
This script will create a systray icon with a menu to launch the other PVS admin scripts.
	
.DESCRIPTION
The purpose of the script is to create a systray icon to launch the PVS admin scripts in the folder "C:\Program Files (x86)\Scripts".

.NOTES
If you want to change the root folder you have to modify the shortcut. 

Author:         Dennis Mohrmann <@mohrpheus78>
Creation Date:  2021-10-27
Purpose/Change:	
2021-10-30		Inital version
2022-02-16		Added WIndows Updates and configuration menu
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
$Menu_1 = $contextmenu.Items.Add("PVS Toolkit Configuration");
$Menu_1.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\Configuration.png")

$Menu_2 = $contextmenu.Items.Add("Launch PVS Console");
$Menu_2.Image = $icon

$Menu_3 = $contextmenu.Items.Add("vDisk Maintenance");
$Menu_3.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\New PVS vDisk version.png")

$Menu_4 = $contextmenu.Items.Add("Windows Update");
$Menu_4.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\Windows Update.png")

$Menu_5 = $contextmenu.Items.Add("Document vDisk versions");
$Menu_5.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Documentation\PVS vDisk versions.png")

$Menu_6 = $contextmenu.Items.Add("Merge vDisk");
$Menu_6.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Merge\Merge PVS vDisk.png")

$Menu_7 = $contextmenu.Items.Add("Replicate vDisk");
$Menu_7.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Replication\Replicate PVS vDisk.png")

$Menu_8 = $contextmenu.Items.Add("Export all vDisks (XML)");
$Menu_8.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Export\Export PVS vDisk.png")

$Menu_9 = $contextmenu.Items.Add("Shrink vDisk");
$Menu_9.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Shrink\Shrink PVS vDisk.png")

$Menu_Exit = $contextmenu.Items.Add("Exit");
$Menu_Exit.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\Exit.png")

#Sub menus for Menu 1
$Menu1_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu1_SubMenu1.Text = "Hypervisor configuration"
$Menu1_SubMenu1.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\Hypervisor\Hypervisor.png")
$Menu_1.DropDownItems.Add($Menu1_SubMenu1)

$Menu1_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu1_SubMenu2.Text = "PVS configuration"
$Menu1_SubMenu2.Image = $Icon
$Menu_1.DropDownItems.Add($Menu1_SubMenu2)

#Sub menus for Menu 3
$Menu3_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu3_SubMenu1.Text = "New vDisk version"
$Menu3_SubMenu1.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\New PVS vDisk version.png")
$Menu_3.DropDownItems.Add($Menu3_SubMenu1)
 
$Menu3_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu3_SubMenu2.Text = "Promote vDisk version"
$Menu3_SubMenu2.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\Promote PVS vDisk version.png")
$Menu_3.DropDownItems.Add($Menu3_SubMenu2)

#Sub menu for Menu 4
$Menu4_SubMenu1 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu4_SubMenu1.Text = "Install Windows Updates on vDisk"
$Menu4_SubMenu1.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\Windows Update.png")
$Menu_4.DropDownItems.Add($Menu4_SubMenu1)

$Menu4_SubMenu2 = New-Object System.Windows.Forms.ToolStripMenuItem
$Menu4_SubMenu2.Text = "Import scheduled tasks for Windows Update"
$Menu4_SubMenu2.Image = [System.Drawing.Bitmap]::FromFile("$PSScriptRoot\vDisk Maintenance\Scheduled Task.png")
$Menu_4.DropDownItems.Add($Menu4_SubMenu2)

# Add the context menu object to the main systray tool object
$Systray_Tool_Icon.ContextMenuStrip = $contextmenu;

# Action after clicking
$Menu1_SubMenu1.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\Hypervisor\Configure Hypervisor.ps1`""
	start-process powershell.exe -ArgumentList $args
	})
	
$Menu1_SubMenu2.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\PVS\Configure PVS.ps1`""
	start-process powershell.exe -ArgumentList $args
	})
	
$Menu_2.add_Click({ 
    start-process "C:\Program Files\Citrix\Provisioning Services Console\Console.msc"
	})
	
$Menu3_SubMenu1.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Maintenance\New PVS vDisk version.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu3_SubMenu2.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Maintenance\Promote PVS vDisk version.ps1`""
	start-process powershell.exe -ArgumentList $args
	})
	
$Menu4_SubMenu1.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Maintenance\Start Windows Updates.ps1`""
	start-process powershell.exe -ArgumentList $args
	})
	
$Menu4_SubMenu2.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Maintenance\Windows Updates Task.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_5.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Documentation\PVS vDisk versions.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_6.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Merge\Merge PVS vDisk.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_7.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Replication\Replicate PVS vDisk.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_8.add_Click({
	$args = "-NoProfile -NoLogo -WindowStyle Maximized -ExecutionPolicy Bypass -File `"$PSScriptRoot\vDisk Export\Export PVS vDisk.ps1`""
	start-process powershell.exe -ArgumentList $args
	})

$Menu_9.add_Click({
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


