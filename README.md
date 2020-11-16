# zerotouch
zerotouch - 2020 zerotouch deployment HA Cluster R80.40 and above
this script is only a demo for Check Point API abilities. all parameter are "Hard coded"

Overview
This repository contains one powershell script.
zerops.ps1

Requirements
powershell 5.0 or newer.
line 4: put in your Management Server IP adress or FQDN
line 5: username and password with API call priviliges
line 6: zero touch portal username and password with priviliges on necessary UC

Usage
open powerhell console.
change to directory where you stored zerops.ps1 (file can be renamed)
execute script.


What does it do?
after editing the parameter in lines 4, 5 and 6 you can start the script.

Zero touch clish script per gateway: inside "ZTGW" function
Management Server Cluster Definition: inside "CreateCluster" function

after starting script you will see following menu

    1) Create Cluster Obj on Mgmt Create OTP and Publish
            a Cluster with two members are created
    2) ZT first and second GW
            script connects to Zero touch Portal
            gets a list of your UC
            gets a list of your Templates (Gaia and SMB)
            asks if you want to unclaim a mac address first
            gets a list of unclaimed mac addresses
            asks for gateway host name
            claimes mac adress with previously collected information
            gives you instruction "wait till DHCP port Blinks on your Gateway" 
            shows you the activation link
                please open this link in browser and folow instruction
            asks you if you want to wait for process end or not.
                if you want to wait: it will jump into a loop until deployment status is equal "Finished"
                
    3) Create-Sic
            initiales SIC between Management Server and Gateways and waits till this process is finished
    4) Instal Policy
            starts and waits for policy push task to this Cluster 
            policy name is hard coded  in "installPolicy" function
    0) Exit
    


reads and lists your UC accounts
after selecting account a list of your templates  


