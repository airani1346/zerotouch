# #################################################
# necessary Variables
# #################################################
$checkpoint_mgmt_server='<management server ip address>'
$mgmtLogin = @{ "user" = "<user name>";  "password" = "<password>" } | ConvertTo-Json
$ztlogin = @{ "user" = "<zero touch username>";  "password" = "<password>" } | ConvertTo-Json



$AccountNr=""
$urlbase="https://$checkpoint_mgmt_server"+':443/web_api/'
$ZTurlbase='https://zerotouch.checkpoint.com/ZeroTouch/web_api/v2'

#############################################################################
# Dependencies
#############################################################################
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Throw "Please update your PowerShell. min req: 5"
}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# ###########################################################################
# function declarations
# ###########################################################################

# ###########################################################################
# Time-stamp 
# ###########################################################################
function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)   
}

# ###########################################################################
# get internet explorer path over registry
# ###########################################################################
function Get-DefaultBrowser
{
	Param([parameter(Mandatory=$true)][alias("Computer")]$ComputerName)
	
	$Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName)
	$RegistryKey = $Registry.OpenSubKey("SOFTWARE\\Classes\\https\\shell\\open\\command")
	#Get (Default) Value
	$RegistryKeyWOArg = $RegistryKey.Name.Replace(" %1","")
	$Value = $RegistryKeyWOArg.GetValue("")
	
	return $Value
}


# ###########################################################################
# Zero Touch deployment in this script clish script is hardcoded. 
# for a real scenario these values  can be fetched over files or Database
# ###########################################################################
function ZTGW() {
    # #################################################
    # login to ZT and get SID
    # #################################################
    $sid = (Invoke-RestMethod -Method Post -ContentType "application/json" -Uri "$ZTurlbase/login" -Body $ztlogin).sid
    $Headers=@{"x-chkp-sid" = "$sid"}
    
    # ##################################################
    # list account id's and prompt to select
    # ##################################################
    if ($AccountNr -ne "") {
        [string]$swacc=  $(Write-Host "Switch-Account [Y/N](Default No): " -ForegroundColor Yellow -NoNewline; Read-Host)
        if ($swacc -ne "") { 
            $AccountNr -eq ""
        }
    }
    
    while ($AccountNr -eq "") {
        $arrAccounts=(Invoke-RestMethod -Method Post -ContentType "application/json" -Headers $Headers -Uri "$ZTurlbase/show-all-accounts" -Body @{}) | select account-id, company-name 
        $arrAccounts | Format-Table -AutoSize
    
        [string]$AccountNr=  $(Write-Host "Select Account ID: " -ForegroundColor Yellow -NoNewline; Read-Host)
        if ($AccountNr -eq "") { Write-Host "you have to select an account to proceed" }
    }
    
    # ##################################################
    # list templates and prompt to select
    # ##################################################
    $json_body = @"
        { 
            "account-ids" : [ $AccountNr ] 
        }  
"@
    Write-Host "List of Gaia Templates: " -ForegroundColor Yellow
    $arrtemplateIDs=(Invoke-RestMethod -Method Post -ContentType "application/json" -Headers $Headers -Uri "$ZTurlbase/show-all-gaia-templates" -Body $json_body)
    foreach ($templateIDs in $arrtemplateIDs) {
        write-host ID: $templateIDs.'template-id'   Name: $templateIDs.name
    }
    
    Write-Host "List of SMB Templates: " -ForegroundColor Yellow
    $arrSMBtemplateIDs=(Invoke-RestMethod -Method Post -ContentType "application/json" -Headers $Headers -Uri "$ZTurlbase/show-all-templates" -Body $json_body)
    foreach ($templateIDs in $arrSMBtemplateIDs) {
        write-host ID: $templateIDs.'template-id'   Name: $templateIDs.name
    }
    Write-Host "- -------------------------------- - " -ForegroundColor Yellow
    [string]$TemplateID=  $(Write-Host "Select TemplateID: " -ForegroundColor Yellow -NoNewline; Read-Host)
    if ($TemplateID -eq "") { Throw "no TemplateID ID- no action" }
    

    # ##################################################
    # unclaim mac address to reclaim it again?
    # ##################################################
    [string]$unclaimSwitch=  $(Write-Host "do you want to unclaim a mac address first? [Y/N] (Default N): " -ForegroundColor Yellow -NoNewline; Read-Host)
    $unclaimSwitch=$unclaimSwitch.ToUpper()
    if ($unclaimSwitch -ne "")  { 
        [string]$gwMAC=  $(Write-Host "Please select Gateway Mac Adr: " -ForegroundColor Yellow -NoNewline; Read-Host)
        if ($gwMAC -eq "") { Throw "no TemplateID ID- no action" }
        # ##################################################
        # unclaim mac address 
        # ##################################################
        $json_body = @"
            {
                "account-id" : $AccountNr,
                "mac":"$gwMac"
            }
"@
        Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$ZTurlbase/unclaim-gaia-gateway" -Body $json_body
    }
    
    
    # ##################################################
    # get user input MAC and name
    # ##################################################
    [string]$gwMAC=  $(Write-Host "Claim a Gateway. Please select Gateway Mac Adr: " -ForegroundColor Yellow -NoNewline; Read-Host)
    if ($gwMAC -eq "") { Throw "no TemplateID ID- no action" }

    [string]$gwName=  $(Write-Host "Please Put new Gateway name: " -ForegroundColor Yellow -NoNewline; Read-Host)
    if ($gwName -eq "") { Throw "no TemplateID ID- no action" }
      
    # ##################################################
    # Claim gateways: set name and template
    # ##################################################        
    $json_body = @"
        { 
            "mac"         : "$gwMac" ,
            "account-id"  : $AccountNr,  
            "object-name" : "$gwName",
            "template-id" : $TemplateID
        } 
"@

    $ClaimResponse=Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$ZTurlbase/claim-gaia-gateway" -Body $json_body

    # ##################################################
    # set user-script and refresh activation link
    # ##################################################                
    $gwconf1=@'
set management interface eth5
set interface Mgmt state off
set interface eth1 state on
set interface eth1 auto-negotiation on
set interface eth1 ipv4-address 192.168.10.2 mask-length 24
set interface eth2 state on
set interface eth2 auto-negotiation on
set interface eth2 ipv4-address 192.168.17.2 mask-length 24
set interface eth5 state on
set interface eth5 auto-negotiation on
set interface eth5 ipv4-address 192.168.178.82 mask-length 24
set static-route default nexthop gateway address 192.168.178.1 on
set static-route default nexthop gateway address 192.168.1.254 off
set user admin password-hash $1$AGPtAorN$NGc5XwEkqS0gp1k8uAF0l1
set user admin shell /bin/bash
'@

    $gwconf2=@'
set management interface eth5
set interface Mgmt state off
set interface eth1 state on
set interface eth1 auto-negotiation on
set interface eth1 ipv4-address 192.168.10.3 mask-length 24
set interface eth2 state on
set interface eth2 auto-negotiation on
set interface eth2 ipv4-address 192.168.17.3 mask-length 24
set interface eth5 state on
set interface eth5 auto-negotiation on
set interface eth5 ipv4-address 192.168.178.83 mask-length 24
set static-route default nexthop gateway address 192.168.178.1 on
set static-route default nexthop gateway address 192.168.1.254 off
set user admin password-hash $1$AGPtAorN$NGc5XwEkqS0gp1k8uAF0l1
set user admin shell /bin/bash
'@

    if ($gwName.EndsWith("1")) {
        $gwconf=$gwconf1.replace("`n",'\n').replace("`r","\n")
    }
    if ($gwName.EndsWith("2")) {
        $gwconf=$gwconf2.replace("`n",'\n').replace("`r","\n")
    }
 
    $json_body = @"
        { 
            "mac"                : "$gwMac",
            "account-id"         : $AccountNr, 
            "user-script"        : "$gwconf",   
            "activate-with-url"  : true,
            "under-construction" : false
            
        } 
"@
    $ClaimResponse=Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$ZTurlbase/set-gaia-claimed-gateway-configuration" -Body $json_body

    # ##################################################
    # show activation link
    # ##################################################
    $json_body = @"
        { 
            "mac": "$gwMac",
            "account-id" : $AccountNr 
        } 
"@
    $ShowClaimedGateResponse=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$ZTurlbase/show-gaia-claimed-gateway" -Body $json_body).'activation-url-key'
       
    
    Write-Host "# ###############################################" -ForegroundColor Yellow 
    Write-Host "wait until DHCP Port Blinks" -ForegroundColor Magenta 
    $hint=  $(Write-Host "Plug in Kable and wait till Management port Blinks! and then press enter" -ForegroundColor Magenta ; Read-Host)
    Write-Host "# ###############################################" -ForegroundColor Yellow 
   
    Write-Host "call activation link and wait for successfull config check" -ForegroundColor Magenta
    write-host "activation of $gwMac via " -ForegroundColor Magenta
	[string]$waiter=  $(write-host "link will open. Please follow instructions and close browser at the end to continue" -ForegroundColor Magenta ; Read-Host)
	#start-process -FilePath $(Get-DefaultBrowser) -ArgumentList "https://zerotouch.checkpoint.com/ZeroTouch/activatelink/$ShowClaimedGateResponse" -wait
    
    Write-Host "# ###############################################" -ForegroundColor Yellow 
    

    # ##################################################
    # list all claimed gateways
    # ##################################################
    $json_body = @"
        { 
            "account-id" :  $AccountNr
        }  
"@
    $arrClaimedGWs=(Invoke-RestMethod -Method Post -ContentType "application/json" -Headers $Headers -Uri "$ZTurlbase/show-all-gaia-claimed-gateways" -Body $json_body) | select mac, object-name, emplate-name

    # ##################################################
    # wait for downloaded flag
    # ##################################################
    [string]$WatchProgress=  $(Write-Host "do you want to watch progress? [Y/N] (Default Y): " -ForegroundColor Yellow ; Read-Host)
    $Status=""
    if ($WatchProgress -eq "") {
        $json_body = @"
                 {
                     "account-id" : $AccountNr,
                      "mac": "$gwMAC"
                 }
"@
        while ($Status -ne "Finished") {       
            $Status=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$ZTurlbase/show-gaia-claimed-gateway-status" -Body $json_body).'reported-display-status'
            write-Host "waiting for Status [Finished] current status is: " $Status
            $WatchProgress=  $(Write-Host "repeat query?[Y/N] (Default Y): " -ForegroundColor Yellow ; Read-Host)
            if ($WatchProgress -ne '') {
                $Status = "Finished"
            }
        }
    }

    # ##################################################
    # logout
    # ##################################################
    Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$ZTurlbase/logout" -Body @{ }
    write-Host "ZT logout" -ForegroundColor Magenta
}

# ###########################################################################
# get task /api call status on Management server to have more control 
# on process
# ###########################################################################
function getTaskStatus () {
    param(
        [string] $localTaskID,
        [int] $waitsec,
        [string] $checkstr,
        [string] $skipper      
    )

    write-host "check every $waitsec for $localTaskID if task is finished"
    $status=''
    
    $body = @{} | ConvertTo-Json 
    while ($status -eq '') {
        Start-Sleep -s $waitsec
        $TaskStatusArr=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/show-tasks" -Body $body)
        $task = $TaskStatusArr.tasks | where { $_.'task-id' -eq $localTaskID }
        $status=$task.status
        write-host "$(Get-TimeStamp) current status: " $status
        if ($status -ne $checkstr) { $status = ''}
        
        #if ($skipper -eq 'true') {
        #    [string]$dis=  $(Write-Host "break further checking? [Y/N](any input will break. Enter to repeat): " -ForegroundColor Yellow -NoNewline; Read-Host)
        #    if ($dis -ne "") { 
        #        $status -eq "fertig"
        #    }
        #}
    }
}

# ###########################################################################
# Create a Cluster on Management Server as default object without sic
# ###########################################################################
function CreateCluster () {
    $sid = (Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $headers -Uri "$urlbase/login" -Body $mgmtLogin).sid
    $Headers=@{"x-chkp-sid" = "$sid"}

    $jsonCluster=@'
{
	"name" : "Cluster1",
	"color" : "Yellow",
	"version" : "R80.40",
	"ipv4-address" : "192.168.178.81",
	"os-name" : "Gaia",
	"cluster-mode" : "cluster-xl-ha",
	"firewall" : true,
	"vpn" : false,
	"interfaces" : [  
	{
		"name" : "eth1",
		"interface-type" : "cluster + sync",
		"ipv4-address" : "192.168.10.1",
		"ipv4-network-mask" : "255.255.255.0",
		"topology" : "INTERNAL",
		"topology-settings" : {
			"ip-address-behind-this-interface" : "network defined by the interface ip and net mask",
			"interface-leads-to-dmz" : false
		},
		"anti-spoofing" : true,
		"anti-spoofing-settings" : 	{
			"action" : "prevent"
		}
	}, 
	{
		"name" : "eth2",
		"interface-type" : "cluster",
		"ipv4-address" : "192.168.17.1",
		"ipv4-network-mask" : "255.255.255.0",
		"topology" : "INTERNAL",
		"topology-settings" : {
			"ip-address-behind-this-interface" : "network defined by the interface ip and net mask",
			"interface-leads-to-dmz" : false
		},
		"anti-spoofing" : true,
		"anti-spoofing-settings" : {
			"action" : "prevent"
		}
	}, 
	{
		"name" : "eth5",
		"interface-type" : "cluster",
		"ipv4-address" : "192.168.178.81",
		"ipv4-network-mask" : "255.255.255.0",
        "topology" : "EXTERNAL",
		"anti-spoofing" : true,
		"anti-spoofing-settings" : 	{
			"action" : "prevent"
		}
	}],
	"members" : 	[ {
		"name" : "gw-3200-01",
		"ip-address" : "192.168.178.82",
		"interfaces" : [ 
			{
				"name" : "eth1",
				"ipv4-address" : "192.168.10.2",
				"ipv4-network-mask" : "255.255.255.0"
			}, 
			{
				"name" : "eth2",
				"ipv4-address" : "192.168.17.2",
				"ipv4-network-mask" : "255.255.255.0"
			}, {
				"name" : "eth5",
				"ipv4-address" : "192.168.178.82",
				"ipv4-network-mask" : "255.255.255.0"
			}
		]
	}, 
	{
		"name" : "gw-3200-02",
		"ip-address" : "192.168.178.83",
		"interfaces" : 
			[ 
				{
					"name" : "eth1",
					"ipv4-address" : "192.168.10.3",
					"ipv4-network-mask" : "255.255.255.0"
				}, 
				{
					"name" : "eth2",
					"ipv4-address" : "192.168.17.3",
					"ipv4-network-mask" : "255.255.255.0"
				}, 
				{
					"name" : "eth5",
					"ipv4-address" : "192.168.178.83",
					"ipv4-network-mask" : "255.255.255.0"
				} 
			]
	}]
}
'@
    
    # ############################################################
    # create cluster and member objects
    # ############################################################
    $taskid=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/add-simple-cluster" -Body $jsonCluster).'task-id'
    getTaskStatus "$taskid" 5 "succeeded" "false"
    write-host "$(Get-TimeStamp)  task finished successfully will wait 10 sec before publishing"
    Start-Sleep -s 10

    # ############################################################
    # publish
    # ############################################################
    $body = @{ } | ConvertTo-Json
    $taskid=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/publish" -Body $body).'task-id'
    $status=''
    $json_body = @"
{
    "task-id" : "$taskid"
}
"@
    while ($status -eq '') {
        Start-Sleep -s 5
        $TaskStatusArr=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/show-task" -Body $json_body)
        $task = $TaskStatusArr.tasks | where { $_.'task-id' -eq $taskid }
        $status=$task.status
        write-host "$(Get-TimeStamp) create cluster publish status: " $status
        if ($status -ne 'succeeded') { $status = ''}
    }


    write-host "$(Get-TimeStamp)  publish done will wait 10 sec before logout"
    Start-Sleep -s 10
    # ############################################################
    # logout
    # ############################################################
    $body = @'
{ 
} 
'@
    $logout=Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/logout" -Body $body
    write-host "$(Get-TimeStamp)  logout done"
}

# ###########################################################################
# initiate sic to cluster members
# ###########################################################################
function Create-Sic () {
    $sid = (Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $headers -Uri "$urlbase/login" -Body $mgmtLogin).sid
    $Headers=@{"x-chkp-sid" = "$sid"}

    # ############################################################
    # set ontime password to Initialize Trust 
    # ############################################################
    $json_body=@"
    {
        "name" : "cluster1",
        "members" : {
          "update" : 
            [ 
                {
                    "name" : "gw-3200-01",
                    "one-time-password" : "vpn123"
                }, 
                {
                    "name" : "gw-3200-02",
                    "one-time-password" : "vpn123"
                } 
            ]
        }
    }
"@

    $setSimpleTaskid=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/set-simple-cluster" -Body $json_body).'task-id'
    getTaskStatus "$setSimpleTaskid" 5 "succeeded" "true"
    write-host 'task finished successfully will wait 10 sec before publishing-sic should be still in progress' 
    Start-Sleep -s 10

    # ############################################################
    # publish
    # ############################################################
    $status=''
    $body = @{ } | ConvertTo-Json
    $taskid=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/publish" -Body $body).'task-id'

    $json_body = @"
{
    "task-id" : "$taskid"
}
"@
    while ($status -eq '') {
        Start-Sleep -s 5
        $TaskStatusArr=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/show-task" -Body $json_body)
        $task = $TaskStatusArr.tasks | where { $_.'task-id' -eq $taskid }
        $status=$task.status
        write-host "$(Get-TimeStamp) current status: " $status
        if ($status -ne 'succeeded') { $status = ''}
    }


    write-host "$(Get-TimeStamp)  publish done will wait 10 sec before logout"
    Start-Sleep -s 10

    # ############################################################
    # logout
    # ############################################################
    $body = @{ } | ConvertTo-Json
    $logoutTask=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/logout" -Body $body)
}

# ###########################################################################
# Install policy on this cluster 
# ###########################################################################
function installPolicy () {
	[string]$waiter=  $(Write-Host "make sure that cluster topology matches your need" -ForegroundColor Yellow -NoNewline; Read-Host)
	
    $sid = (Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $headers -Uri "$urlbase/login" -Body $mgmtLogin).sid
    $Headers=@{"x-chkp-sid" = "$sid"}

    # ############################################################
    # push policy
    # ############################################################
    $json_body= @'
{ 
    "policy-package" : "standard",
    "access" : "true",
    "threat-prevention" : "false",
    "targets" : "cluster1" 
}
'@
    $policyPushTask=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/install-policy" -Body $json_body).'task-id'
    getTaskStatus "$policyPushTask" 5 "succeeded" "true"
    write-host 'policy-push in progress will wait 10 sec before logout' 
    Start-Sleep -s 10

    # ############################################################
    # logout
    # ############################################################
    $body = @{ } | ConvertTo-Json
    $logoutTask=(Invoke-RestMethod -Method Post -ContentType "application/json"  -Headers $Headers -Uri "$urlbase/logout" -Body $body)
}


# ##########################################################################
# function definitionen End
# ##########################################################################
$code="0"
while (($code -eq "0") -or ($code -eq "1") -or ($code -eq "2") -or ($code -eq "3")) {
    #clear-Host
    Write-Host "Please select Task:" -ForegroundColor Yellow
    Write-Host "      1) Create Cluster Obj on Mgmt Create OTP and Publish" -ForegroundColor Magenta
    Write-Host "      2) ZT first and second GW" -ForegroundColor Magenta
    Write-Host "      3) Create-Sic" -ForegroundColor Magenta    
    Write-Host "      4) Instal Policy" -ForegroundColor Magenta    
    Write-Host "      " 
    Write-Host "      0) Exit" -ForegroundColor Magenta

    $code= $(Write-Host "   Please select Task: " -ForegroundColor Yellow -NoNewline; Read-Host)
    switch ($code) {
        0 {  exit                            }
        1 {  CreateCluster                   }
        2 {  ZTGW                            }
        3 {  Create-SIC                      }
        4 {  installPolicy                   }
    }
} 
