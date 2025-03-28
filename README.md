# Nasuni Edge Appliance Automation
 Scripts for automating the deployment of Nasuni Edge Appliances
 
# Support Statement

*   These scripts have been validated with the PowerShell and Nasuni versions documented in the README file.
    
*   Nasuni Support is limited to the underlying APIs and pages used by the scripts.
    
*   Nasuni API and Protocol bugs or feature requests should be communicated to Nasuni Customer Success.
    
*   GitHub project to-dos, bugs, and feature requests should be submitted as “Issues” in GitHub under its repositories.

# Main Auto Deploy Script functions
1. Uses the Portal API to get an unused serial number and auth code that will be used for the out-of-the-box setup wizard. This requires access to Nasuni Portal (soon to replace account.nasuni.com)--contact us if you need access. Create a role for API access in Portal and grant at least enough access to view serial numbers and auth codes. Within the Portal API Key management page, create a service key and link it to the role. You must include the service key and secret in the Variables.ps1 files.
2. Completes the out-of-the-box setup wizard (e.g., configures Edge Appliance Name, Network information, serial number, input serial number, accept EULA, and join NMC management)
3. Logs into Edge Appliance after setup and completes Active Directory join.

# Requirements
1. Nasuni 9.15 Edge Appliances or higher are required. Nasuni has tested this with the 9.15 release.
2. Powershell 6 or higher must be used--the script uses some functions unavailable in earlier versions of PowerShell. Note: PowerShell ISE, the PowerShell Editor included with Windows, is based on PowerShell 4 and should not be used with this script. Visual Studio Code is the best editor for the latest versions of PowerShell.
3. DHCP must be enabled for initial deployment even if you want to use static IP addressing for the Edge Appliance.

# Technical Details
The script uses PowerShell Invoke-WebRequest to make calls using HTTPS over port 8443 to the existing Edge Appliance configuration/settings pages normally completed interactively by the customer. Python implements a similar module called Requests that could be used instead of PowerShell. This does not use the Selenium WebDriver, and no modifications to the Nasuni backend are required to use this script.

Most form interactions and basic error handling are implemented in the script, but not everything is (e.g., we currently skip installing updates in the script). However, that can be expanded as appropriate.

The main sections of the deployment wizard work must be accessed sequentially and are only made available for calls after the previous section has been completed. For example, making calls to the “Accept EULA" page is impossible until the “Serial Number” page has been successfully submitted. Further, once a page has been successfully submitted, the wizard's active “stage” is updated, and you cannot access a previous stage of the wizard without calling a special action to reverse a prior step. The script accounts for these behaviors and steps through the wizard's key stages in the correct order. The script knows where to pick up where it left off now and can be run multiple times if desired. The script doesn’t attempt to configure something already configured (i.e., if the network config is already set, it skips configuring the network).

# Variables
The AutoDeployEA.ps1 script does not need to be modified. It only needs one input--the path (varPath in the script) to a variables input file. Variables for the script are stored in a file called "Variables.ps1". You can use the included Variables.ps1 file as a template for your environment.

# Executing the script
Running the script is easy. From within PowerShell, execute the script and provide input for varPath.<br>
`./AutoDeployEA.ps1 -varPath <path>`

# Static IP Example for Variables
```powershell
#example variables for static IP config after deployment
$bootproto = 'static'
$gateway = '192.168.86.1'
#dns information
$search_domain = 'mydomain.com'
$primary_dns = '8.8.8.8'
$secondary_dns = ''

#Populate the Network Interface Settings information for the first Traffic Group
#specify boot protocol - dhcp (dhcp) or static. dhcp2 is not valid for traffic groups. For dhcp, set 1proto to DHCP and do not set info for the other variables in this section.
$1proto	= 'static'
#enter the desired IP address for the Edge Appliance
$1ipaddr = '192.168.86.136'
$1netmask =	'255.255.255.0'
$1mtu =	'1500'
```
