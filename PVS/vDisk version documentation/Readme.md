# PVS vDisk version documentation

This script will generate a HTML report of your current vDisk versions

## Parameter
-Sitename
Sitename of yout PVS site  
-outputpath
The path where the report is saved
	
## Example
& '.\PVS vDisk versions.ps1' -Sitename Testlab -outputpath C:\Users\admin\Desktop
    
## Notes
The script is based on the excellent PVS Health Check script from Sacha Thomet (@sacha81): https://github.com/sacha81/citrix-pvs-healthcheck/blob/master/Citrix-PVS-Farm-Health-toHTML_Parameters.xml
I used most of the code and added the decription, there is also no need of the XML file. 