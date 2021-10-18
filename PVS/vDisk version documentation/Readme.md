# PVS vDisk version documentation

This script will generate a HTML report of your current vDisk versions

## Parameter
-Sitename  
Site name of your PVS site  
-outputpath  
The path where the HTML report is saved
	
## Example
& '.\PVS vDisk versions.ps1' -Sitename Testlab -outputpath C:\Users\admin\Desktop
    
## Notes
The script is based on the excellent PVS Health Check script from Sacha Thomet (@sacha81): https://github.com/sacha81/citrix-pvs-healthcheck/blob/master/Citrix-PVS-Farm-Health-toHTML_Parameters.xml
I used most of the code and added the decription, there is also no need of the XML file.  
If you want to change the table width cause you need more space for the descriptions, increase the value '1400' in lines 64 and 128 to something higer

## Examples
![Versions](https://github.com/Mohrpheus78/Citrix/tree/main/PVS/vDisk%20version%20documentation/Images/PVSversions.png)