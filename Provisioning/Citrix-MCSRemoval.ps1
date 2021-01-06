<#
.SYNOPSIS
  Remove a given number of Windows 7 VDI
.DESCRIPTION
  Remove a given number of Windows 7 VDI provided as a paramte
.EXAMPLE
    PS C:\PSScript > Citrix-MCSRemoval.ps1 -VDICount 10 
    Remove 10 non persistent Windows 7 VDI, split equally between the two DTC (GV1 and GV2)
.INPUTS
    None. You cannot pipe objects to this script.
.OUTPUTS
    No objects are output from this script. This script creates its own logs files.
.NOTES
  Version:        0.1
  Author:         Steven Lemonier
  Creation Date:  2020-11-11
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Position=0, Mandatory=$true)] [int]$VDICount,
    [Parameter(Position = 1, Mandatory=$False)][Alias("OF")][ValidateNotNullOrEmpty()] [string]$OutFilePath="C:\Temp\VDI_Removal.log"
)

Set-StrictMode -Version 2
Add-PSSnapin Citrix* -erroraction silentlycontinue

function Log {
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$log
    )
    if(Test-Path -Path $OutFilePath){
        if((get-item $OutFilePath).Length -gt 5mb){
            $date = Get-date -Format yyyy-MM-dd
            Move-Item -Path $OutFilePath -Destination "C:\Temp\VDI_Removal-$date.log"
        }
    }
    $ScriptTime = Get-Date -Format yyyy.MM.dd-HH:mm:ss
    if($log -match "ERROR"){
        Write-host "[$scriptTime] $log" -ForegroundColor Red
    } 
    elseif ($log -match "OK") {
        Write-host "[$scriptTime] $log" -ForegroundColor Green
    }else{
        Write-Host "[$scriptTime] $log"
    }
    "[$scriptTime] $log" | Out-File -FilePath $OutFilePath -Append
}

function RemoveWindows7 {
    param (
        [parameter(position=0,Mandatory=$true)] $VDICount
    )
    #Check if number of unused VDI is greater than the number we want to decomission
    $UnusedCount = ((Get-BrokerMachine -CatalogName "Windows 7 Skype - *" -MaxRecordCount 5000 | Where-Object { $_.SessionCount -eq 0  }).MachineName | Measure-Object).Count
    if($UnusedCount -gt $VDICount){
        Log "OK: Number of unused VDI: $UnusedCount"
    } else {
        Log "ERROR: Not enough unused VDI ($UnusedCount)"
        Break
    }

    $VDICount = $VDICount / 2
    #Find unused VDI in GV1
    $UnusedVDI = (Get-BrokerMachine -CatalogName "Windows 7 Skype - GV1 LUN14x" -MaxRecordCount 5000 | Where-Object { $_.SessionCount -eq 0  } | Select-Object -first $VDICount).MachineName
    foreach($VDI in $UnusedVDI){
        Log "INFO: Setting $VDI maintenance mode to True"
        Get-BrokerMachine -MachineName $VDI | Set-BrokerMachine -InMaintenanceMode $true
        If((Get-BrokerMachine -MachineName $VDI).InMaintenanceMode){
            Log "OK: $VDI is in maintenance mode"
            Log "INFO: $VDI PowerOff..."
            New-BrokerHostingPowerAction -Action TurnOff -MachineName $VDI
            while(((Get-BrokerMachine -MachineName $VDI).PowerState -ne "Off")){
                Start-Sleep -Seconds 2
            }
            Log "OK: $VDI is powered off"
            $VDI = ($VDI.Split("\"))[1]
            $VMID = (Get-ProvVM -VMName $VDI).VMId
            $SID = (Get-ProvVM -VMName $VDI).ADAccountSID
            Log "INFO: Unlock VM $VDI"
            Unlock-ProvVM -ProvisioningSchemeUid "00b1dd03-a7c0-4dd0-9c78-4765d1dd64bb" -VMId $VMID
            Log "INFO: Remove VM $VDI"
            Remove-ProvVM -ProvisioningSchemeUid "00b1dd03-a7c0-4dd0-9c78-4765d1dd64bb" -VMName $VDI
            Log "INFO: Remove VM $VDI from Citrix Infrastructure"
            Remove-BrokerMachine -DesktopGroup 55 -MachineName "adir\$VDI"
            Remove-BrokerMachine -Force -MachineName "adir\$VDI"
            Log "INFO: Remove $VDI Account from Active Directory"
            Remove-AcctADAccount -ADAccountSID $SID -Force -IdentityPoolUid "49410157-c7b5-445e-9ff5-85ba8b3c8d1b" -RemovalOption Delete
        }else {
            Log "ERROR: $VDI was not set in maintenance mode"
        }
    }
    #Reset variable
    $UnusedVDI = $null
    #Find unused VDI in GV2
    $UnusedVDI = (Get-BrokerMachine -CatalogName "Windows 7 Skype - GV2 LUN24x" -MaxRecordCount 5000 | Where-Object { $_.SessionCount -eq 0  } | Select-Object -first $VDICount).MachineName
    foreach($VDI in $UnusedVDI){
        Log "INFO: Setting $VDI maintenance mode to True"
        Get-BrokerMachine -MachineName $VDI | Set-BrokerMachine -InMaintenanceMode $true
        If((Get-BrokerMachine -MachineName $VDI).InMaintenanceMode){
            Log "OK: $VDI is in maintenance mode"
            Log "INFO: $VDI PowerOff..."
            New-BrokerHostingPowerAction -Action TurnOff -MachineName $VDI
            while(((Get-BrokerMachine -MachineName $VDI).PowerState -ne "Off")){
                Start-Sleep -Seconds 2
            }
            Log "OK: $VDI is powered off"
            $VDI = ($VDI.Split("\"))[1]
            $VMID = (Get-ProvVM -VMName $VDI).VMId
            $SID = (Get-ProvVM -VMName $VDI).ADAccountSID
            Log "INFO: Unlock VM $VDI"
            Unlock-ProvVM -ProvisioningSchemeUid "d2fc0d28-016a-42ee-9d16-c6cbff6b71ef" -VMId $VMID
            Log "INFO: Remove VM $VDI"
            Remove-ProvVM -ProvisioningSchemeUid "d2fc0d28-016a-42ee-9d16-c6cbff6b71ef" -VMName $VDI
            Log "INFO: Remove VM $VDI from Citrix Infrastructure"
            Remove-BrokerMachine -DesktopGroup 55 -MachineName "adir\$VDI"
            Remove-BrokerMachine -Force -MachineName "adir\$VDI"
            Log "INFO: Remove $VDI Account from Active Directory"
            Remove-AcctADAccount -ADAccountSID $SID -Force -IdentityPoolUid "bc3000f4-bf36-419c-a0cd-b325c2dfb48b" -RemovalOption Delete 
        }else {
            Log "ERROR: $VDI was not set in maintenance mode"
        }
    }
}

Write-Host `r`n "Continual Progress Report is also being saved to" $OutFilePath -BackgroundColor Yellow -ForeGroundColor DarkBlue
Log "INFO: Script started by $env:USERDOMAIN\$env:USERNAME"
RemoveWindows7 -VDIcount $VDICount
Log "####################################################################################################"