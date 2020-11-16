# zerotouch
first 3 lines has to be modified

$checkpoint_mgmt_server='<management server ip address>'
  
$mgmtLogin = @{ "user" = "<user name>";  "password" = "<password>" } | ConvertTo-Json
  
$ztlogin = @{ "user" = "<zero touch username>";  "password" = "<password>" } | ConvertTo-Json

