# This script can be executed when the machine certificate have been installed.
# The certificate thumbprint will be find idf the hostname is in the subject. This need to be change if your certificate binding is for a DNS alias for ex.
# 14 dec 2017 - STH
 
# Fetching registry key to get the Citrix Broker Service GUID
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
$CBS_Guid = Get-ChildItem HKCR:Installer\Products -Recurse -Ea 0 | Where-Object { $key = $_; $_.GetValueNames() | ForEach-Object { $key.GetValue($_) } | Where-Object { $_ -like '*Citrix Broker Service*' } } | Select-Object Name
$CBS_Guid.Name -match "[A-Z0-9]*$"
$GUID = $Matches[0]
 
# Formating the string to look like a GUID with dash ( - )
[GUID]$GUIDf = "$GUID"
Write-Host -Object "Citrix Broker Service GUID for $HostName is: $GUIDf" -foregroundcolor "yellow";
# Closing PSDrive
Remove-PSDrive -Name HKCR
 
# Getting local IP address and adding :443 port
$ipV4 = Test-Connection -ComputerName (hostname) -Count 1  | Select -ExpandProperty IPV4Address 
$ipV4ssl = "$ipV4 :443" -replace " ", ""
Write-Host -Object "The IP Address for $HostName is: $ipV4ssl" -foregroundcolor "green";
 
# Getting the certificate thumbprint
# certificate is chosen when hostname is found in the subject, you can change {$_.Subject -match "$HostName"} to help to match the right certificate
$HostName = $env:computername
$Thumbprint = (Get-ChildItem -Path Cert:LocalMachine\My | Where-Object {$_.Subject -match "$HostName"}).Thumbprint -join ';';
Write-Host -Object "Certificate Thumbprint for $HostName is: $Thumbprint" -foregroundcolor "magenta"; 
 
# Preparing to execute the netsh command inside powershell
$SSLxml = "http add sslcert ipport=$ipV4ssl certhash=$Thumbprint appid={$GUIDf}"
$SSLxml | netsh
 
# Verifying the certificate binding on the Citrix XML
netsh http show sslcert
