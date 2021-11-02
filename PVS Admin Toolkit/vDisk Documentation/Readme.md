# PVS vDisk version documentation
This script will generate a HTML report of your current vDisk versions

## Parameter
-outputpath  
The path where the HTML report is saved

## Example
& '.\PVS vDisk versions.ps1' -outputpath C:\Users\admin\Desktop 

## Notes
The script is based on the excellent PVS Health Check script from Sacha Thomet (@sacha81): https://github.com/sacha81/citrix-pvs-healthcheck/blob/master/Citrix-PVS-Farm-Health-toHTML_Parameters.xml
I used most of the code and added the decription, there is also no need of the XML file.  
If you want to change the table width cause you need more space for the descriptions, increase the value '1400' in lines 80 and 144 to something higer.
If you want to change the root folder you have to modify the shortcut and the output path for the report.

## Examples
![Versions](https://github.com/Mohrpheus78/Citrix/blob/main/PVS%20Admin%20Toolkit/vDisk%20Documentation/Images/PVSversions.png)