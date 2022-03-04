<#
.Synopsis
   Reset the license usage on the Citrix License Server.
.DESCRIPTION
   The script uses udadmin to reset the usage.

.PARAMETER License
    The name of the Citrix License out of the Lic File.

.EXAMPLE
    .\Citrix-ResetLicenseUsage.ps1 -License XDT_PLT_UD

    Schedulded Task like:
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -file "C:\Script\Citrix-ResetLicenseUsage.ps1"


.NOTES
  Author: Manuel Winkel (@deyda84)
  Creation Date:  2022-03-04
#>

Param(
    [Parameter(
            Mandatory=$True,
            HelpMessage='License Type',
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$License
)


#Get Current Path
$Environment = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

#Add Items to Environment
$AddPathItems = ";C:\Program Files (x86)\Citrix\Licensing\LS;"
$Environment = $Environment.Insert($Environment.Length,$AddPathItems)

#Set Updated Path
[System.Environment]::SetEnvironmentVariable("Path", $Environment, "Machine")

#Used licenses?!
$FilePath = "C:\Script\Citrix_Used_License.txt"
udadmin.exe -list -f "$License" | out-file $FilePath

#Get license to delete
$Licenses = (Select-String -Pattern "$License" -Path $FilePath) | ForEach-Object {$_.line -replace "."+$License+".*",""}

#Use UDadmin to release licenses
ForEach ($lic in $Licenses) {udadmin.exe -f $License -user "$lic" -delete}
ForEach ($lic in $Licenses) {udadmin.exe -f $License -device "$lic" -delete}

#Restart licensing service
$svc = (Get-Service -Name "Citrix Li*")
Restart-Service -InputObject $svc -Verbose

Exit