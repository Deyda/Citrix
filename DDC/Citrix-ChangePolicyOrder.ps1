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
    .\Citrix-ChangePolicyOrder.ps1 -Policy "No Optical Drive Mapping" -Priority 2

.EXAMPLE
    .\Citrix-ChangePolicyOrder.ps1 -Policy "No Optical Drive Mapping" -Priority 2 -DDC DDC01

.NOTES
  Author: Manuel Winkel (@deyda84)
  Creation Date:  2021-03-15
#>

Param(
	[Parameter(Mandatory=$True,HelpMessage='Name of the Citrix Policy')]
	[string]$Policy ,
    [Parameter(Mandatory=$True,HelpMessage='New Priority')]
    [int]$Priority ,
    [string]$ddc = 'localhost'
)

#Load Citrix snappin
Add-PSSnapIn citrix*

#Verify Delivery Controller value exists
if ([string]::IsNullOrEmpty($ddc)) {
    write-host "Delivery Controller name is not specified. Please specify as a script paramater or add value to the param block in the script. Exiting." -ForegroundColor Red
    exit
}

#Create PSDrive with Citrix Policies
New-PSDrive -name LocalFarmGpo -PSProvider CitrixGroupPolicy -Controller $ddc

Set-CtxGroupPolicy $Policy -Priority $Priority