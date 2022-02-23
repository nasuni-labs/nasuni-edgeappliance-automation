#Auto Deploy Variables
#Variables for Part 1 - NMC login to get serial number and auth for the next section
#Tell the script to use login to NMC to find an unused serial number and auth code (true/false). If false, you must provide a Serial Number and Auth Code
$GetSerialFromNMC = 'true'

#specify NMC hostname
$NmcHostname = "insertNmcHostnameOrIP"

#specify NMC login information - use DOMAIN\username for domain accounts
$NmcUsername = 'username'
$NmcPassword = 'password'

#specify Serial Number and Auth code if not using the NMC to obtain them
$SerialNumber = 'enterAuthCode'
$AuthCode = 'enterAuthCode'

#Variables for Part 2 - Edge Appliance Setup Wizard
#Enter Edge Appliance IP Address
$EdgeApplianceIpAddress = "insertEdgeApplianceIPaddress"

#Enter Edge Appliance Name
$EdgeApplianceName = "insertEdgeApplianceName"

#Enter desired Edge Appliance User Name and Password
$EdgeApplianceUsername = "username"
$EdgeAppliancePassword = 'password'

#Network Information
#Populate the information for the System Settings portion of network configuration.
#specify boot protocol - dhcp (dhcp), dhcp2 (dhcp with custom dns) or static. For dhcp set bootproto to dhcp and leave the other variables blank.
#for dhcp with custom dns, set dhcp2 for bootproto and populate the other variables in this section. 
$NwBootproto = 'dhcp2'
$NwGateway = ''
#dns information
$NwSearchDomain = 'domain.com'
$NwPrimaryDNS = 'insertDnsIP'
$NwSecondaryDNS = ''

#Populate the Network Inferface Settings information for the first Traffic Group
#specify boot protocol - dhcp or static. dhcp2 is not valid for traffic groups. For dhcp, set 1proto to DHCP and do not set info for the other variables in this section.
$NwTG1Proto	= 'dhcp'
#enter the desired IP address for the Edge Appliance
$NwTG1Ipaddr = ''
$NwTG1Netmask =	''
$NwTG1Mtu =	'1500'

#Proxy Config
#configure proxy (on for yes, empty for no)
$NwProxyConfigure = ''
#proxy hostname or IP address
$NwProxyHost = 'insertProxyIP'
#proxyPort
$NwProxyPort = 8080
#proxy Username (optional)
$NwProxyUsername = ''
#proxy Password (optional)
$NwProxyPassword = ''
#proxy no proxy list (optional) - comma separated for multiple entries
$NwProxyNoProxy = ''
#proxy enabled - 1 true, 0 false
$NwProxyEnabled = 1

#Variables for Part 3 - Domain Join
#Contrals whether to join AD domain - true or false
$DomainJoin = 'true'
#AD Domain Name - e.g., domain.com
$DomainName = "insertDomain.com"

#AD Join credentials - an AD account with permission to join the domain. Do not specify a Domain Prefix
$DomainUsername = 'DomainUsername'
$DomainPassword = 'DomainPassword'