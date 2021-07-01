#requires -modules ActiveDirectory
<#
.SYNOPSIS
  Get a list of enabled published resources on Citrix CVAD, and counts the number of (enabled) AD users per application
.DESCRIPTION
  This script generates a CSV file with an inventory of published resources on Citrix CVAD, retrieves AD users and groups per application and counts the number of (enabled) AD accounts per application
.PARAMETER <Parameter_Name>
  None
.INPUTS
  None
.OUTPUTS
  CSV File
.NOTES
  Version:        1.0
  Author:         Bart Jacobs - @Cloudsparkle
  Creation Date:  11/09/2020
  Purpose/Change: CVAD Application User Count Inventory
.EXAMPLE
  None
#>

#Try loading Citrix Powershell modules, exit when failed
If ((Get-PSSnapin "Citrix*" -EA silentlycontinue) -eq $null)
  {
    try {Add-PSSnapin Citrix* -ErrorAction Stop }
    catch {Write-error "Error loading Citrix Powershell snapins"; Return }
  }

#Variables to be customized
$CTXDDC = "" #Choose any Delivery Controller
$CSVFile = "c:\temp\CTXAppInventory.csv"

#Initializing Script Variables
$csvContents = @() # Create the empty array that will eventually be the CSV file

#Get all Published Resources
$CTXApplications = Get-BrokerApplication -AdminAddress $CTXDDC

Foreach ($CTXApp in $CTXApplications)
{
  If ($CTXApp.Enabled -eq $True)
  {
    #Initializing
    $output=""
    $totalcount = 0

    #Get AD Users and groups of the published resource
    $accountlist = $CTXApp.AssociatedUserNames

    Foreach ($account in $accountlist)
    {
      #Initialize loop variables
      $AppGroup = $null
      $IsADUser = $false

      #Split the account into DOMAIN and USER
      $input = $account
      $domain,$ADName = $input.split('\')

      $output += ($ADName + ";")

      #AD User or Group?
      try {$AppGroup = Get-ADGroup $ADName }
      catch { $IsADUser = $true }

      if ($IsADUser -eq $false)
      {
        $groupmembers = (Get-ADGroupMember -Recursive -Identity $account.AccountName)
        Foreach ($groupmember in $groupmembers)
        {
          $groupuser = get-aduser -Identity $groupmember.SamAccountName
          if ($groupuser.enabled -eq $true)
          {
            $totalcount = $totalcount + 1
          }
        }
      }
      Else
      {
        $AppUser = Get-ADUser $ADName

        if ($AppUSer.Enabled -eq $True)
        {
          $totalcount = $totalcount + 1
        }
      }
    }

    #When running interactive, get some running output
    #write-host $CTXAPP.ApplicationName, $output, $totalcount

    #Get the CSV data ready
    $row = New-Object System.Object # Create an object to append to the array
    $row | Add-Member -MemberType NoteProperty -Name "Application" -Value $CTXApp.Displayname
    $row | Add-Member -MemberType NoteProperty -Name "Accounts" -Value $output
    $row | Add-Member -MemberType NoteProperty -Name "Count" -Value $totalcount

    $csvContents += $row # append the new data to the array#
  }
}

#Write the CSV output
$csvContents | Export-CSV -path $CSVFile -NoTypeInformation