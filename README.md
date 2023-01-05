# Nasuni Edge Appliance Automation
 Scripts for automating the deployment of Nasuni Edge Appliances
 
# Support Statement

*   These scripts have been validated with the PowerShell and Nasuni versions documented in the README file.
    
*   Nasuni Support is limited to the underlying APIs and pages used by the scripts.
    
*   Nasuni API and Protocol bugs or feature requests should be communicated to Nasuni Customer Success.
    
*   GitHub project to-do's, bugs, and feature requests should be submitted as “Issues” in GitHub under its repositories.

# Main Auto Deploy Script functions
1. Logs into the NMC using customer-provided credentials and finds an unused serial number and auth code that will be used for the out-of-the-box setup wizard. Since the NMC serial numbers are not accessible using the NMC API, this script logs into the NMC directly and requires an NMC login with access to the serial numbers page.
2. Completes the out of the box setup wizard (e.g., configures Edge Appliance Name, Network information, serial number, input serial number, accept EULA, and join NMC management)
3. Logs into Edge Appliance after setup and completes Active Directory join.

# Requirements
1. Nasuni 8.8 Edge Appliances or higher required. Nasuni has tested this with the 8.8, 9.0, 9.3, 9.5, and 9.7 releases.
2. Powershell 6 or higher must be used--the script uses some functions unavailable in earlier versions of PowerShell. Note: PowerShell ISE, the PowerShell Editor included with Windows, is based on PowerShell 4 and should not be used with this script. Visual Studio Code is the best editor for the latest versions of PowerShell.
3. DHCP must be enabled for initial deployment even if the customer wants to use static IP addressing for the Edge Appliance.

# Technical Details
The script uses PowerShell Invoke-WebRequest to make calls using HTTPS over port 8443 to the existing Edge Appliance configuration/settings pages normally completed interactively by the customer. Python implements a similar module called Requests that could be used instead of PowerShell. This does not use the Selenium WebDriver, and no modifications to the Nasuni backend are required to use this script.

Most form interactions and basic error handling are implemented in the script, but not everything is (e.g., we currently skip installing updates in the script). However, that can be expanded as appropriate.

The main sections of the deployment wizard work must be accessed sequentially and are only made available for calls after the previous section has been completed. For example, it is not possible to make calls to the “Accept EULA" page until the “Serial Number” page has been successfully submitted. Further, once a page has been successfully submitted, the wizard's active “stage” is updated, and you cannot access a previous stage of the wizard without calling a special action to reverse a prior step. The script accounts for both of these behaviors and steps through the wizard's key stages in the correct order. The script now knows where to pick up where it left off now and can be run multiple times if desired. The script doesn’t attempt to configure something that is already configured (i.e., if the network config is already set, it skips configuring the network).

# Variables
The AutoDeployEA.ps1 script does not need to be modified. It only needs one input--the path (varPath in the script) to a variables input file. Variables for the script are stored in a file called "Variables.ps1". You can used the include Variables.ps1 file as a template for your environment.

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

#Populate the Network Inferface Settings information for the first Traffic Group
#specify boot protocol - dhcp (dhcp) or static. dhcp2 is not valid for traffic groups. For dhcp, set 1proto to DHCP and do not set info for the other variables in this section.
$1proto	= 'static'
#enter the desired IP address for the Edge Appliance
$1ipaddr = '192.168.86.136'
$1netmask =	'255.255.255.0'
$1mtu =	'1500'
```
