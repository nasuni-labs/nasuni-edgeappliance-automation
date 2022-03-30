#Get a serial number and auth code from the NMC, complete the Edge Appliance Setup wizard, and join the Edge Appliance to the domain
#Needs PowerShell 6 or higher

#define script parameters
param ($varPath)

#define the function for getting page state
function GetPageState{
    $script:GetState=Invoke-WebRequest -uri $GetStateUri -skipCertificateCheck -SessionVariable sv
    #Regex pattern to compare two strings
    $startString = 'action="'
    $stopString = '/"'
    $pattern = "$startString(.*?)$stopString"

    #Perform the comparison operation to find the right wizard page
    $PageState = [regex]::Match($GetState.content,$pattern).Groups[1].Value

    #check to see if the wizard is complete and the Edge Appliance is waiting for login
    if ($PageState -NotLike '*/wizard/*') {
        #Regex pattern to compare two strings
        $startString = 'button id="'
        $stopString = '_btn"'
        $pattern = "$startString(.*?)$stopString"
        #Perform the comparison operation
        $PageState = [regex]::Match($GetState.content,$pattern).Groups[1].Value
    }
    #Return result
    return $PageState
}

#Read the Variables content from an external PowerShell script
if ($null -eq $varPath) {
$varPath = read-host -Prompt "Please enter the path to the variables input file" 
}

#get the invocation path for the script
$mypath = $MyInvocation.MyCommand.Path

#find the correct slash to use. Requires PowerShell 6
if ($isWindows -eq 'True)') {$slash = "\"} else {$slash = "/"} 

#determine full or local path
if (($varPath -like "*/*") -or ($varPath -like "*\*")) {$absolutePath = 'True'} else {$absolutePath = 'False'}

#if an absolute path was input use it as is
if ($absolutePath -eq 'True') {$fullVarPath = $varPath} else {
    $parentPath = Split-Path $mypath -Parent
    $fullVarPath = $parentPath + $slash + $varPath
}
#load Variables into the script
. $fullVarPath

#Part 1 - login to the NMC and export a list of serial numbers and auth codes
#skip this section if GetSerialFromNMC is false
if ($GetSerialFromNMC -eq 'true') {
Write-Output "Part 1: Logging into the NMC to get an unused auth code and serial number"

#LoginPage
$LoginUri = "https://" + $NmcHostname + "/login/?next=/"
$GetLogin=Invoke-WebRequest -uri $LoginUri -skipCertificateCheck -SessionVariable sv 
$Form = $GetLogin.InputFields
$csrfmiddlewaretoken = $Form[0].value

#Submit Login Page
$LoginHeaderInput = @{
    "Referer" = $LoginUri
}

$LoginFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "username" = $NmcUsername
    "password" = $NmcPassword
}

#write-output "Logging into the NMC"
$SubmitLogin=Invoke-WebRequest -Uri $LoginUri -WebSession $sv -Method POST -Form $LoginFormInput -Headers $LoginHeaderInput -skipCertificateCheck
#write-output "-Status Code: $($SubmitLogin.StatusCode)"

#Serials Page
$SerialsUri = "https://" + $NmcHostname + "/account/serial_numbers/json/"

#Get Serials
$GetSerials = Invoke-WebRequest -uri $SerialsUri -skipCertificateCheck -WebSession $sv

$NasuniJson = ConvertFrom-Json –InputObject $GetSerials.Content
$NamesJson = $NasuniJson | Get-Member | Where-Object -Property Membertype -EQ NoteProperty

foreach($NameJson in $NamesJson)  
    {  
    $row = $NameJson.Name
    $serial_number = $NasuniJson."$row".serial_number
    $serial_number_type = $NasuniJson."$row".serial_number_type
    $filer_description = $NasuniJson."$row".filer_description
    $filer_build= $NasuniJson."$row".filer_build
    $auth_code = $NasuniJson."$row".auth_code

 
    #return the first unused filer serial number and auth code
    if (($null -eq $filer_description) -and ($null -eq $filer_build) -and ($serial_number_type -eq "filer")) {
    $SerialNumber = $serial_number
    $AuthCode = $auth_code
    write-output "Found unused serial for deployment"
    break
    }
    }
} else {write-output "Skipping Part1: NMC Login-getting Serial Numbers from the NMC is disabled"}

#Part 2 - Edge Appliance Setup Wizard
Write-Output "Part 2: Edge Appliance Set up Wizard"
#build the variables to check the Edge Appliance state for each step
$GetStateUri = "https://" + $EdgeApplianceIpAddress + ":8443/"

#Network Page
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/network*' ) {
$NetworkUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/network/"
$GetNetwork=Invoke-WebRequest -uri $NetworkUri -skipCertificateCheck -SessionVariable sv
$Form = $GetNetwork.InputFields
$csrfmiddlewaretoken = $Form[0].value

#Submit Network Page
$NetworkHeaderInput = @{
    "Referer" = $NetworkUri
}

$NetworkFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "hostname" = $EdgeApplianceName
    "eth0-traffic_group" = '1'
    "bootproto" = $NwBootproto
    "gateway"	= $NwGateway
    "search_domain" = $NwSearchDomain
    "primary_dns"	= $NwPrimaryDNS
    "secondary_dns" = $NwSecondaryDNS
    "changeproxy" = $NwProxyConfigure
    "1-proto"	= $NwTG1Proto
    "1-ipaddr" = $NwTG1Ipaddr
    "1-netmask" = $NwTG1Netmask
    "1-mtu" = $NwTG1Mtu
    "1-gateway" = ''
    "1-device" = '1'
    "2-proto"	= 'dhcp'
    "2-ipaddr" = ''
    "2-netmask" = ''
    "2-mtu" = '1500'
    "2-gateway" = ''
    "2-device" = '2'
    "3-proto"	= 'dhcp'
    "3-ipaddr" = ''
    "3-netmask" = ''
    "3-mtu" = '1500'
    "3-gateway" = ''
    "3-device" = '3'
}

write-output "Submitting Network Configuration"
$SubmitNetworkConfig=Invoke-WebRequest -Uri $NetworkUri -WebSession $sv -Method POST -Form $NetworkFormInput -Headers $NetworkHeaderInput -skipCertificateCheck
write-output "-Status Code: $($SubmitNetworkConfig.StatusCode)"

#Build CSRF Only form input
$CSRFOnlyFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
}
} else {write-output "Skipping network, wizard state is $PageStateVar"}

#Proxy Page
#check to see if proxy needs to be configured
if ($NwProxyConfigure -eq 'on' ) {
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/proxy*' ) {
    $ProxyUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/proxy/"
    #replace comma with end of line character for no Proxy list
    $NwProxyNoProxy = $NwProxyNoProxy.replace(",","`r`n")

    #Submit Proxy Page
    $ProxyHeaderInput = @{
    "Referer" = $ProxyUri
}
    $ProxyFormInput = [ordered]@{
        "csrfmiddlewaretoken" = $csrfmiddlewaretoken
        "dotest" = 'true'
        "proxy" = $NwProxyHost
        "port" = $NwProxyPort
        "username" = $NwProxyUsername
        "password" = $NwProxyPassword
        "no_proxy" = $NwProxyNoProxy
        "enabled" = $NwProxyEnabled
    }

    write-output "Submitting Proxy Configuration"
    $SubmitProxyConfig=Invoke-WebRequest -Uri $ProxyUri -WebSession $sv -Method POST -Form $ProxyFormInput -Headers $ProxyHeaderInput -skipCertificateCheck
    write-output "-Status Code: $($SubmitProxyConfig.StatusCode)"
}
}

#Submit Netready
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/netready*' ) {
    $NetreadyUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/netready/"
    $GetNetready=Invoke-WebRequest -uri $NetreadyUri -skipCertificateCheck -SessionVariable sv
    $Form = $GetNetReady.InputFields
    $csrfmiddlewaretoken = $Form[0].value
    #Build CSRF Only form input
    $CSRFOnlyFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
        }
    
    $NetreadyHeader = @{
    "Referer" = $NetreadyUri
    }
    write-output "Submitting Netready"
    $SubmitNetready=Invoke-WebRequest -Uri $NetreadyUri -WebSession $sv -Method POST -Form $CSRFOnlyFormInput -Headers $NetreadyHeader -skipCertificateCheck
    write-output "-Status Code: $($SubmitNetready.StatusCode)"

#switch to newly configured static IP update static IP
if ($NwTG1Proto -eq "static") {
    write-output "switching to new ip address"
    #change the IP address for subsequent calls to use the new static IP address we assigned for the interface in the first traffic group
    $EdgeApplianceIpAddress = $NwTG1Ipaddr
    $GetStateUri = "https://" + $EdgeApplianceIpAddress + ":8443/"
}
} else {write-output "Skipping netready, wizard state is $PageStateVar"}

#Updates section - assumes Edge Appliance is current--add logic later to skip updates
#Pause for next step
Start-Sleep -s 20
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/updates*' ) {
$UpdatesUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/updates/"
#Get a new CSRF token--we need to do this when switching to static IP
$GetUpdates=Invoke-WebRequest -uri $UpdatesUri -skipCertificateCheck -SessionVariable sv 
$Form = $GetUpdates.InputFields
$csrfmiddlewaretoken = $Form[0].value

#Rebuild CSRF Only form input to use the new CSRF Token
$CSRFOnlyFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
}

$UpdatesHeader = @{
    "Referer" = $UpdatesUri
}
write-output "Submitting Updates"
$SubmitUpdates=Invoke-WebRequest -Uri $UpdatesUri -WebSession $sv -Method POST -Form $CSRFOnlyFormInput -Headers $UpdatesHeader -skipCertificateCheck
write-output "-Status Code: $($SubmitUpdates.StatusCode)"

#Pause for next step
Start-Sleep -s 10
} else {write-output "Skipping updates page, wizard state is $PageStateVar"}

#Submit Serial and Auth
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/serial*' ) {
$SerialUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/serial/"
$GetSerial=Invoke-WebRequest -uri $SerialUri -skipCertificateCheck -SessionVariable sv
$Form = $GetSerial.InputFields
$csrfmiddlewaretoken = $Form[0].value
$SerialHeader = @{
    "Referer" = $SerialUri
}
$SerialFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "serial_number" = $SerialNumber
    "auth_code" = $AuthCode
}
write-output "Submitting serial number"
$SubmitSerial=Invoke-WebRequest -Uri $SerialUri -WebSession $sv -Method POST -Form $SerialFormInput -Headers $SerialHeader -skipCertificateCheck
write-output "-Status Code: $($SubmitSerial.StatusCode)"
} else {write-output "Skipping serial number page, wizard state is $PageStateVar"}

#ConfirmNew
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/confirmnew*' ) {
$ConfirmNewUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/confirmnew/"
$GetConfirmNew=Invoke-WebRequest -uri $ConfirmNewUri -skipCertificateCheck -SessionVariable sv
$Form = $GetConfirmNew.InputFields
$csrfmiddlewaretoken = $Form[0].value
$ConfirmNewHeader = @{
    "Referer" = $ConfirmNewUri
}
$ConfirmNewFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "confirm" = "Install New Filer"
}
write-output "Confirming Install New Edge Appliance"
$SubmitConfirmNew=Invoke-WebRequest -Uri $ConfirmNewUri -WebSession $sv -Method POST -Form $ConfirmNewFormInput -Headers $ConfirmNewHeader -skipCertificateCheck
write-output "-Status Code: $($SubmitConfirmNew.StatusCode)"
} else {write-output "Skipping Install new Filer Confirmation Page, wizard state is $PageStateVar"}

#PostSerialUpdate Check
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/update_new*' ) {
$PostSerialUpdateUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/update_new/"
$GetPostSerialUpdate=Invoke-WebRequest -uri $PostSerialUpdateUri -skipCertificateCheck -SessionVariable sv
$Form = $GetPostSerialUpdate.InputFields
$csrfmiddlewaretoken = $Form[0].value
$PostSerialUpdateHeader = @{
    "Referer" = $PostSerialUpdateUri
}
$PostSerialUpdateFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
}
write-output "Running command to skip Post Serial Software Update"
$SubmitPostSerialUpdate=Invoke-WebRequest -Uri $PostSerialUpdateUri -WebSession $sv -Method POST -Form $PostSerialUpdateFormInput -Headers $PostSerialUpdateHeader -skipCertificateCheck
write-output "-Status Code: $($SubmitPostSerialUpdate.StatusCode)"
} else {write-output "Skipping post serial update page, wizard state is $PageStateVar"}

#Accept EULA
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/eula*' ) {
$EulaUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/eula/"
$GetEula=Invoke-WebRequest -uri $EulaUri -skipCertificateCheck -SessionVariable sv
$Form = $GetEULA.InputFields
$csrfmiddlewaretoken = $Form[0].value
$EulaHeader = @{
    "Referer" = $EulaUri
}
$EulaFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "accept" = "on"
}
write-output "Accepting EULA"
$SubmitEula=Invoke-WebRequest -Uri $EulaUri -WebSession $sv -Method POST -Form $EulaFormInput -Headers $EulaHeader -skipCertificateCheck
write-output "-Status Code: $($SubmitEula.StatusCode)"
} else {write-output "Skipping Accept EULA Page, wizard state is $PageStateVar"}

#Populate Edge Appliance Description
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/description*' ) {
$DescriptionUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/description/"
$GetDescription=Invoke-WebRequest -uri $DescriptionUri -skipCertificateCheck -SessionVariable sv
$Form = $GetDescription.InputFields
$csrfmiddlewaretoken = $Form[0].value
$DescriptionHeader = @{
    "Referer" = $DescriptionUri
}
$DescriptionFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "description" = $EdgeApplianceName
}
Write-output "Setting Edge Appliance Description"
$SubmitDescription=Invoke-WebRequest -Uri $DescriptionUri -WebSession $sv -Method POST -Form $DescriptionFormInput -Headers $DescriptionHeader -skipCertificateCheck
write-output "-Status Code: $($SubmitDescription.StatusCode)"
} else {write-output "Skipping set filer name page, wizard state is $PageStateVar"}

#Check NMC - Join NMC Management
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/checknmc*' ) {
$CheckNMCUri = "https://" + $EdgeApplianceIpAddress + ":8443/wizard/checknmc/"
$GetCheckNMC=Invoke-WebRequest -uri $CheckNMCUri -skipCertificateCheck -SessionVariable sv
$Form = $GetCheckNMC.InputFields
$csrfmiddlewaretoken = $Form[0].value
$CheckNMCHeader = @{
    "Referer" = $CheckNMCUri
}
$CheckNMCFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "enabled" = "on"
}
#Pause for next step
Start-Sleep -s 5

write-output "Joining NMC Manaagement"
$SubmitCheckNMC=Invoke-WebRequest -Uri $CheckNMCUri -WebSession $sv -Method POST -Form $CheckNMCFormInput -Headers $CheckNMCHeader -skipCertificateCheck
write-output "-Status Code: $($SubmitCheckNMC.StatusCode)"
} else {write-output "Skipping NMC join page, wizard state is $PageStateVar"}

#Create User - Create local user and password
$PageStateVar = GetPageState
if ($PageStateVar -like '*/wizard/createuser*' ) {
    #wrap create user in a job to handle a bug in create user that can cause it to hang even though the create is successful
    write-output "Creating user"
    $CreateUserTimeoutSeconds = 15
    $job = Start-Job { 
        $CreateUserUri = "https://" + $using:EdgeApplianceIpAddress + ":8443/wizard/createuser/"
        $GetCreateUser=Invoke-WebRequest -uri $CreateUserUri -skipCertificateCheck -SessionVariable sv
        $Form = $GetCreateUser.InputFields
        $csrfmiddlewaretoken = $Form[0].value
        $CreateUserHeader = @{
        "Referer" = $CreateUserUri
        }
        $CreateUserFormInput = [ordered]@{
            "csrfmiddlewaretoken" = $csrfmiddlewaretoken
            "username" = $using:EdgeApplianceUsername
            "pass1" = $using:EdgeAppliancePassword
            "pass2" = $using:EdgeAppliancePassword
            }
    
        $SubmitCreateUser = Invoke-WebRequest -Uri $CreateUserUri -WebSession $sv -Method POST -Form $CreateUserFormInput -Headers $CreateUserHeader -skipCertificateCheck
    
        write-output "-Status Code: $($SubmitCreateUser.StatusCode)"
        }
    $done = $job |Wait-Job -TimeOut $CreateUserTimeoutSeconds
    if($done){
        # It returned within the timeout 
        write-output "Create user completed before timing out"
    }
    else {
        # Nothing was returned. Job timed out.
        write-output "Create user timed out--can be ignored--user account should still be set"
    }
} else {write-output "Skipping user creation page, wizard state is $PageStateVar"}

write-output "Part 2: Wizard Complete"

#Part 3 - NMC Join Check and Domain Join
write-output "Part 3: Joining NMC Management Check and AD Domain Join"
#Login Page
$LoginUri = "https://" + $EdgeApplianceIpAddress + ":8443/login/"

#Get the Login page and get the csrfmiddlewaretoken
$GetLogin=Invoke-WebRequest -uri $LoginUri -skipCertificateCheck -SessionVariable sv
$LoginFormInputFields = $GetLogin.InputFields
$csrfmiddlewaretoken = $LoginFormInputFields[0].value

#Submit Login Page
$LoginHeaderInput = @{
    "Referer" = $LoginUri
}

$LoginFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "username" = $EdgeApplianceUsername
    "password" = $EdgeAppliancePassword
}

write-output "Submitting Login"
$SubmitLogin=Invoke-WebRequest -Uri $LoginUri -WebSession $sv -Method POST -Form $LoginFormInput -Headers $LoginHeaderInput -skipCertificateCheck
write-output "-Status Code: $($SubmitLogin.StatusCode)"

#Begin NMC section
$NmcUri = "https://" + $EdgeApplianceIpAddress + ":8443/support/nmc/"

$AjaxHeaderInput = @{
    "Referer" = $NmcUri
    "csrftoken" = $csrfmiddlewaretoken
    "X-Requested-With" = "XMLHttpRequest"
}
$GetNmc=Invoke-WebRequest -uri $NmcUri -skipCertificateCheck -WebSession $sv -Headers $AjaxHeaderInput
#get a new csrftoken
$csrfmiddlewaretoken = $GetNMC.inputfields[0].value

#Regex pattern to compare two strings
$nmcStartString = 'selected="selected">'
$nmcStopString = '</option>'
$nmcPattern = "$nmcStartString(.*?)$nmcStopString"

#Perform the comparison operation to get the state of the NMC Join
$nmcState = [regex]::Match($GetNmc.content, $nmcPattern).Groups[1].Value

if ($nmcState -eq 'enabled') {
    write-output "Already under NMC management - Skipping NMC Join"
}
else {
    write-output "Checking NMC management"
    
#join NMC management

#Post NMC Confirmation Services
$NmcConfirmUri = "https://" + $EdgeApplianceIpAddress + ":8443/support/confirm_nmc/" 

$NmcConfirmFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "username" = $EdgeApplianceUsername
    "password" = $EdgeAppliancePassword
}
$NmcConfirmHeaderInput = [ordered]@{
    "Referer" = $NmcUri
    "X-Requested-With" = "XMLHttpRequest"
    "X-CSRFToken" = $csrfmiddlewaretoken
}
write-output "Confirming NMC Join"
$ConfirmNMC=Invoke-WebRequest -Uri $NmcConfirmUri -WebSession $sv -Method POST -Form $NmcConfirmFormInput -Headers $NmcConfirmHeaderInput -skipCertificateCheck
write-output "-Confirm NMC Status Code: $($ConfirmNMC.StatusCode)"

$JoinNMCUri = "https://" + $EdgeApplianceIpAddress + ":8443/support/nmc/" 
$JoinNMCFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "enabled" = "ENABLED"
}
$JoinNMCHeaderInput = [ordered]@{
    "Referer" = $NmcUri
    "X-Requested-With" = "XMLHttpRequest"
    "X-CSRFToken" = $csrfmiddlewaretoken
}
write-output "Joining NMC - May take 5 minutes"
$JoinNMC=Invoke-WebRequest -Uri $JoinNMCUri -WebSession $sv -Method POST -Form $JoinNMCFormInput -Headers $JoinNMCHeaderInput -skipCertificateCheck
write-output "-Join NMC Status Code: $($JoinNMC.StatusCode)"
}

#Configure Directory Services
#only configure AD if AD join is enabled in script
if ($DomainJoin -eq 'true') {
$DirectoryServicesUri = "https://" + $EdgeApplianceIpAddress + ":8443/directoryservices/"

#Get the Domain Health to check the status of the join - if already healthy, skip domain config
#Add X-Request-With to the header since Domain health expects it
$AjaxHeaderInput = @{
    "Referer" = $DirectoryServicesUri
    "csrftoken" = $csrfmiddlewaretoken
    "X-Requested-With" = "XMLHttpRequest"
}

$DomainHealthUri = "https://" + $EdgeApplianceIpAddress + ":8443/directoryservices/health_check/"
write-output "Getting Domain Join Health"
$GetDomainHealth=Invoke-WebRequest -uri $DomainHealthUri -skipCertificateCheck -WebSession $sv -Headers $AjaxHeaderInput
write-output "-Status Code: $($GetDomainHealth.StatusCode)"
$JsonHealthStatus = $GetDomainHealth.Content | ConvertFrom-Json

if ($JsonHealthStatus.healthy -eq 'True') {
    write-output "Domain Join Healthy - Skipping Domain Join"
}
else {

#Get Directory Services
$DirectoryServicesGetHeaderInput = @{
    "Referer" = $DirectoryServicesUri
}

write-output "Getting Directory Services"
$GetDirectoryServices=Invoke-WebRequest -uri $DirectoryServicesUri -Headers $DirectoryServicesGetHeaderInput -skipCertificateCheck -WebSession $sv
$DirectoryServicesInputFields = $GetDirectoryServices.InputFields
$csrfmiddlewaretoken = $DirectoryServicesInputFields[0].value
write-output "-Status Code: $($GetDirectoryServices.StatusCode)"




#Post Directory Services
$DirectoryServicesPostHeaderInput = @{
    "Referer" = $DirectoryServicesUri
    "csrftoken" = $csrfmiddlewaretoken
}

#build the form input
$DirectoryServicesPostFormInput = [ordered]@{
    "val_only" = 'true'
    "domain" = $DomainName
    "alter_hostname" = 'on'
    "workgroup" = $null
    "controllers" = $null
    "computerou" = $null
    "backend" = 'ipa'
    "ldap_servers" = $null
    "kdcs" = $null
    "ldap_schema" = $null
    "ldap_user_search_base" = $null
    "ldap_group_search_base" = $null
    "ldap_user_name_attr" = $null
    "ldap_group_name_attr" = $null
    "ldap_netgroup_search_base" = $null
    "ldap_bind_dn" = $null
    "ldap_bind_password" = $null
    "id_min" = $null
    "id_max" = $null
    "domain_type" = 'ads'
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "username" = $DomainUsername
    "password" = $DomainPassword
    "password2" = $DomainPassword
}

#submit first with val_only set to true to test the configuration
write-output "Submitting Domain Configuration val only true"
$SubmitDirectoryServices=Invoke-WebRequest -Uri $DirectoryServicesUri -WebSession $sv -Method POST -Form $DirectoryServicesPostFormInput -Headers $DirectoryServicesPostHeaderInput -skipCertificateCheck
write-output "-Status Code: $($SubmitDirectoryServices.StatusCode)"

#submit again with val_only set to false so that the request is fully processed
write-output "Submitting Domain Configuration val only false"
$DirectoryServicesPostFormInput['val_only'] = 'false'
$SubmitDirectoryServices=Invoke-WebRequest -Uri $DirectoryServicesUri -WebSession $sv -Method POST -Form $DirectoryServicesPostFormInput -Headers $DirectoryServicesPostHeaderInput -skipCertificateCheck
write-output "-Status Code: $($SubmitDirectoryServices.StatusCode)"

#sleep before attempting to get the domain source config
start-sleep -seconds 5

#Get the Domain Source Config
#Add X-Request-With to the header since the last pages of Wizard expect Ajax requests and return 500 errors if not specified
$AjaxHeaderInput = @{
    "Referer" = $DirectoryServicesUri
    "csrftoken" = $csrfmiddlewaretoken
    "X-Requested-With" = "XMLHttpRequest"
}
$DomainSrcConfigUri = "https://" + $EdgeApplianceIpAddress + ":8443/directoryservices/domain_src_config/"
write-output "Getting Domain Source Configuration"
$GetDomainSrcConfig=Invoke-WebRequest -uri $DomainSrcConfigUri -skipCertificateCheck -WebSession $sv -Headers $AjaxHeaderInput
write-output "-Status Code: $($GetDomainSrcConfig.StatusCode)"

#get the first Edge Appliance serial number from the domain config and use it as the source for AD mapping
$jsonDomainSrcConfig = $GetDomainSrcConfig.Content | convertfrom-json
$FilerChoices = $jsonDomainSrcConfig.src_filer_choices | Select-Object -First 1
$EADomainConfigSourceSerial = $FilerChoices[0]
#length of the guid is 36 - we can filter on that to skip the next step if this will be the first AD bound Edge Appliance

#Submit Domain Source Config
$PostDomainSrcConfigFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "filer" = $EADomainConfigSourceSerial
}

write-output "Posting Domain Source Configuration"
$PostDomainSrcConfig=Invoke-WebRequest -Uri $DomainSrcConfigUri -WebSession $sv -Method POST -Form $PostDomainSrcConfigFormInput -Headers $AjaxHeaderInput -skipCertificateCheck
write-output "-Status Code: $($PostDomainSrcConfig.StatusCode)"

#Submit the Wizard Complete Page
$WizardCompleteUri = "https://" + $EdgeApplianceIpAddress + ":8443/directoryservices/wizard_complete/"
$WizardCompleteFormInput = [ordered]@{
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "username" = $DomainUsername
    "password" = $DomainPassword
    "password2" = $DomainPassword
}

write-output "Completing the Domain Join Wizard"
$PostWizardComplete=Invoke-WebRequest -Uri $WizardCompleteUri -WebSession $sv -Method POST -Form $WizardCompleteFormInput -Headers $AjaxHeaderInput -skipCertificateCheck
write-output "-Status Code: $($PostWizardComplete.StatusCode)"

#Get the Domain Health to check the status of the join
$DomainHealthUri = "https://" + $EdgeApplianceIpAddress + ":8443/directoryservices/health_check/"
write-output "Getting Domain Join Health"
$GetDomainHealth=Invoke-WebRequest -uri $DomainHealthUri -skipCertificateCheck -WebSession $sv -Headers $AjaxHeaderInput
write-output "-Status Code: $($GetDomainHealth.StatusCode)"
$JsonHealthStatus = $GetDomainHealth.Content | ConvertFrom-Json

if ($JsonHealthStatus.healthy -eq 'True') {
    write-output "Domain Join Healthy - Script Complete"
}
else {#Join Domain again if AD join health check fails
    write-output "Domain Join Unhealthy - attempting to rejoin"

    #build the form input for rejoin
    $RejoinFormInput = [ordered]@{
    "controllers" = ''
    "rejoin" = 'on'
    "csrfmiddlewaretoken" = $csrfmiddlewaretoken
    "username" = $DomainUsername
    "password" = $DomainPassword
    "password2" = $DomainPassword
    }

    #Set Rejoin URI
    $RejoinUri = "https://" + $EdgeApplianceIpAddress + ":8443/directoryservices/settings/"

    #submit rejoin request
    write-output "Rejoining AD"
    $SubmitRejoin=Invoke-WebRequest -Uri $RejoinUri -WebSession $sv -Method POST -Form $RejoinFormInput -Headers $DirectoryServicesPostHeaderInput -skipCertificateCheck
    write-output "-Status Code: $($SubmitRejoin.StatusCode)"

    #checking Health one more time
    write-output "Checking Domain Health Again"
    $GetDomainHealth=Invoke-WebRequest -uri $DomainHealthUri -skipCertificateCheck -WebSession $sv -Headers $AjaxHeaderInput
    $JsonHealthStatus = $GetDomainHealth.Content | ConvertFrom-Json
    if ($JsonHealthStatus.healthy -eq 'True') {
        write-output "Domain Join Healthy - Script Complete"
    }
    else {write-output "Domain Join Unhealthy - check network configuration and Edge Appliance UI"}
    }
}
} 
else {write-output "Skipping domain join, domain join disabled in script"}
