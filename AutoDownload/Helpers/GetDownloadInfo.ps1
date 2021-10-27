#Downloads Latest Citrix Opimizer from https://support.citrix.com/article/CTX224676
#Can be used as part of a pipeline or MDT task sequence.
#Ryan Butler TechDrabble.com @ryan_c_butler 07/19/2019

#Uncomment to use plain text or env variables
#$CitrixUserName = $env:citrixusername
#$CitrixPassword = $env:citrixpassword

#Uncomment to use credential object
$creds = Get-Credential
$CitrixUserName = $creds.UserName
$CitrixPassword = $creds.GetNetworkCredential().Password

$downloadpath = "C:\temp\CitrixOptimizer.zip"
$unzippath = "C:\temp\opt"

#Initialize Session 
Invoke-WebRequest "https://identity.citrix.com/Utility/STS/Sign-In" -SessionVariable websession -UseBasicParsing

#Set Form
$form = @{
	"persistent" = "1"
	"userName" = $CitrixUserName
	"loginbtn" = ""
	"password" = $CitrixPassword
	"returnURL" = "https://login.citrix.com/bridge?url=https://www.citrix.com/downloads/citrix-virtual-apps-and-desktops/product-software/citrix-virtual-apps-and-desktops-2109.html"
	"errorURL" = "https://login.citrix.com?url=https://www.citrix.com/downloads/citrix-virtual-apps-and-desktops/product-software/citrix-virtual-apps-and-desktops-2109.html&err=y"
}
#Authenticate
Invoke-WebRequest -Uri ("https://identity.citrix.com/Utility/STS/Sign-In") -WebSession $websession -Method POST -Body $form -ContentType "text/html" -UseBasicParsing

$appURLVersion = "https://www.citrix.com/downloads/citrix-virtual-apps-and-desktops/edition-software/premium-2109.html"
$webRequest = Invoke-WebRequest -WebSession $websession  -UseBasicParsing -Uri ($appURLVersion) -SessionVariable websession
$regexAppVersion = "https://downloads.citrix.com.*"
$webRequest.RawContent | Select-String -Pattern $regexAppVersion -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -First 1