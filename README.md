# Nasuni Edge Appliance Automation
 Scripts for automating the deployment of Nasuni Edge Appliances

# Main Auto Deploy Script functions
1. Logs into the NMC using customer-provided credentials and finds an unused serial number and auth code that will be used for the out-of-the-box setup wizard. Since the NMC serial numbers are not accessible using the NMC API, this script logs into the NMC directly and requires an NMC login with access to the serial numbers page.
2. Completes the out of the box setup wizard (e.g., configures Edge Appliance Name, Network information, serial number, input serial number, accept EULA, and join NMC management)
3. Logs into Edge Appliance after setup and completes Active Directory join.

# Requirements
1. Nasuni 8.8 Edge Appliances or higher required. 8.8, 9.0, and 9.3 have been tested.
2. Powershell 6 or higher must be used--the script uses some functions unavailable in earlier versions of PowerShell. Note: PowerShell ISE, the PowerShell Editor included with Windows, is based on PowerShell 4 and should not be used with this script. Visual Studio Code is the best editor for the latest versions of PowerShell.
3. DHCP must be enabled for initial deployment even if the customer wants to use static IP addressing for the Edge Appliance.

# Technical Details
The script uses PowerShell Invoke-WebRequest to make calls using HTTPS over port 8443 to the existing Edge Appliance configuration/settings pages normally completed interactively by the customer. Python implements a similar module called Requests that could be used instead of PowerShell. This doesn’t use the Selenium WebDriver, and no modifications to the Nasuni backend are required to use this script.

Developing the script required reverse-engineering the existing wizard pages and underlying forms. Most form interactions and basic error handling are implemented in the script, but not everything is (e.g., we currently skip installing updates in the script). However, that can be expanded as appropriate.

The main sections of the deployment wizard work must be accessed sequentially and are only made available for calls after the previous section has been completed. For example, it isn’t possible to make calls to the “Accept Eula” page until the “Serial Number” page has been successfully submitted. Further, once a page has been successfully submitted, the wizard's active “stage” is updated, and you can’t access a previous stage of the wizard without calling a special action to reverse a prior step. The script accounts for both of these behaviors and steps through the wizard's key stages in the correct order. Beginning with the v2 version of the script, the script now knows where to pick up where it left off now and can be run multiple times if desired. The script doesn’t attempt to configure something that’s already configured (i.e., if the network config is already set, it skips configuring the network).
