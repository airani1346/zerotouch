# zerotouch
line 4,5 and 6 have to be modifie
  
$checkpoint_mgmt_server='<management server ip address>'
$mgmtLogin = @{ "user" = "<user name>";  "password" = "<password>" } | ConvertTo-Json
$ztlogin = @{ "user" = "<zero touch username>";  "password" = "<password>" } | ConvertTo-Json
