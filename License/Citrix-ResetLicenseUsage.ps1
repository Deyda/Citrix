<#
.Synopsis
   Reset the license usage on the Citrix License Server.
.DESCRIPTION
   The script uses udadmin to reset the usage.

.PARAMETER License
    The name of the Citrix License out of the Lic File.

.EXAMPLE
    .\Citrix-ResetLicenseUsage.ps1 -License XDT_PLT_UD


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

<#
.Synopsis
   Change the priority of a citrix policy.
.DESCRIPTION
   The script prompts for the name of a citrix policy and the new priority to be set.

.PARAMETER Policy
    The name of the Citrix Policy.
.PARAMETER Priority
    New Priority for the Citrix Policy.
.PARAMETER DDC
    DDC to establish connection.

.EXAMPLE
    .\Citrix-ResetLicenseUsage.ps1 -License XDT_PLT_UD


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

#Used licenses?!
$FilePath = "C:\Script\Citrix_Used_License.txt"
set-location "C:\Program Files (x86)\Citrix\Licensing\LS"
udadmin.exe -list -f "$License" | out-file $FilePath

#Get license to delete
$Licenses = (Select-String -Pattern "$License" -Path $FilePath) | ForEach-Object {$_.line -replace "."+$License+".*",""}

#Use UDadmin to release licenses
ForEach ($lic in $Licenses) {udadmin.exe -f $License -user "$lic" -delete}
ForEach ($lic in $Licenses) {udadmin.exe -f $License -device "$lic" -delete}

#Restart licensing service
$svc = (Get-Service -DisplayName "Citrix Licensing")
Restart-Service -InputObject $svc -Verbose

Exit