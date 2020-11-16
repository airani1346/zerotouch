<b>About</b></br>
zerotouch - 2020 zerotouch deployment HA Cluster R80.40 and above</br>
this script is only a demo for Check Point API abilities. all parameter are "Hard coded"</br>

<b>Overview</b></br>
This repository contains one powershell script.</br>
zerops.ps1</br>

<b>Requirements</b></br>
powershell 5.0 or newer.</br>
line 4: put in your Management Server IP adress or FQDN</br>
line 5: username and password with API call priviliges</br>
line 6: zero touch portal username and password with priviliges on necessary UC</br>

<b>Usage</b></br>
open powerhell console.</br>
change to directory where you stored zerops.ps1 (file can be renamed)</br>
execute script.</br>


<b>What does it do?</b></br>
after editing the parameter in lines 4, 5 and 6 you can start the script.</br>

Zero touch clish script per gateway: inside "ZTGW" function</br>
Management Server Cluster Definition: inside "CreateCluster" function</br>

after starting script you will see following menu</br>

&nbsp;&nbsp;&nbsp;<b>1) Create Cluster Obj on Mgmt Create OTP and Publish</b></br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;a Cluster with two members are created</br>
&nbsp;&nbsp;&nbsp;<b>2) ZT first and second GW</b></br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;script connects to Zero touch Portal</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;gets a list of your UC</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;gets a list of your Templates (Gaia and SMB)</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;asks if you want to unclaim a mac address first</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;gets a list of unclaimed mac addresses</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;asks for gateway host name</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;claimes mac adress with previously collected information</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;gives you instruction "wait till DHCP port Blinks on your Gateway" </br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;shows you the activation link</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;please open this link in browser and folow instruction</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;asks you if you want to wait for process end or not.</br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if you want to wait: it will jump into a loop until deployment status is equal "Finished"                </br>
&nbsp;&nbsp;&nbsp;<b>3) Create-Sic</b></br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;initiales SIC between Management Server and Gateways and waits till this process is finished</br>
&nbsp;&nbsp;&nbsp;<b>4) Instal Policy</b></br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;starts and waits for policy push task to this Cluster </br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;policy name is hard coded  in "installPolicy" function</br>
&nbsp;&nbsp;&nbsp;<b>0) Exit</b></br>
