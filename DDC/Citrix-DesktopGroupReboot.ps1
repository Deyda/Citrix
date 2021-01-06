<#
.Synopsis
   Reboots machines in desktop delivery group by placing them into maintenance in predefined bacthes.
.DESCRIPTION
   The script reboots all machines in a given desktop delivery group while the system is in use. This is done by placing a user defined number of machines into maintenance, waiting for sessions to logoff and rebooting machines. Once the batch is verfied, the script moves to the next batch.

.PARAMETER DesktopGroupName
    The name of the Desktop Delivery Group. This parameter is mandatory.
.PARAMETER PercentToRemain
    Percent of machines to remain available. This does not apply to machines with zero sessions. This parameter is mandatory.
.PARAMETER AdminAddress
    Delivery Controller FQDN. Add to the param block in the script if this value will not change often.
.PARAMETER RetryInterval
    The interval in seconds when the script checks for sessions on the given batch. Default is 120 seconds.
.PARAMETER WaitForRegisterInterval
    Expected reboot and registration timeout. If lapses the script throws an error. Default is 120 seconds.
.PARAMETER MaxRecords
    This is a Powershell MaxRecordCount parameter needed to query machine objects. Default is 10,000. Specify if the environment has more the 10,000 machines.
.PARAMETER LogoffDisconnected
    Logoff sessions that are in disconnected state.
.PARAMETER DisconnectWait
    Wait time after logoff command is sent. Usually it takes a few seconds for the session to fully logoff. Set this time to skip another interval of checking for sessions.

.EXAMPLE
    .\citrix-desktopgroupreboot.ps1 -AdminAddress "mydc.domain.org" -DesktopGroupName "My Desktops" -PercentToRemain 80 -WaitForRegisterInterval 180
.EXAMPLE
    .\citrix-desktopgroupreboot.ps1 -AdminAddress "mydc.domain.org" -DesktopGroupName "My Desktops" -PercentToRemain 20 -LogoffDisconnected $true
.NOTES
  Author: Dmitry Palchuk
  Creation Date:  12/2020
#>


Param (
    #Name of Desktop Delivery Group
    $DesktopGroupName,
    #Percent of machines in Desktop Delivery Group to remain available
    [Parameter(Mandatory = $true)]
    [int]$PercentToRemain,
    #Delivery Controller FQDN
    $AdminAddress,
    #Time it takes for machines to reboot and register
    [int]$WaitForRegisterInterval = 120,
    #Retry interval seconds between session count checks
    [int]$RetryInterval = 120,
    #Maximum Records paramater for PS quieries
    [int]$MaxRecords = 10000,
    #Logoff Disconnected Sessions
    [bool]$LogoffDisconnected,
    #Wait time after session is disconnected
    $DisconnectWait = 30
)

#Load Citrix snappin
Add-PSSnapIn citrix*

#Verify Delivery Controller value exists
if ([string]::IsNullOrEmpty($adminaddress)) {
    write-host "Delivery Controller name is not specified. Please specify as a script paramater or add value to the param block in the script. Exiting." -ForegroundColor Red
    exit
}

#Verify Desktop Group
if ([string]::IsNullOrEmpty($DesktopGroupName) -or (!(Get-BrokerDesktopGroup -Name $DesktopGroupName -ErrorAction SilentlyContinue))) {
    write-host "Desktop Group name is not specified or does not exist. Please select the Desktop Group." -ForegroundColor Yellow
    $DesktopGroups = Get-BrokerDesktopGroup

    For ($i = 0; $i -lt $DesktopGroups.Count; $i++) {
        Write-Host "$($i+1): $($DesktopGroups[$i].Name)"
    }

    [int]$number = Read-Host "Press the number to select store"
    $DesktopGroupName = $DesktopGroups[$number - 1].Name
}


#Functions

function Wait-RebootMaintenance ($AdminAddress, $DesktopGroupName, $machines, $retryinterval, $waitforregisterinterval, $LogoffDisconnected, $DisconnectWait) {
    #main
    write-host "Working on rebooting $machines" -ForegroundColor Yellow
    #while there are machines that are in maintenance mode
    $verifymachines = $machines
    while ($machines.count -gt 0) {
        write-host $machines.count "machines remaining. machines are `n$machines `n" -ForegroundColor Yellow
        #logoff disconnected sessions
        if ($LogoffDisconnected -and (Get-BrokerSession | Where-Object { $_.DesktopGroupName -eq $DesktopGroupName -and $_.SessionState -eq "Disconnected" })) {
            Write-Host "Logging off disconnected sessions" -ForegroundColor Yellow
            Get-BrokerSession -AdminAddress $AdminAddress | Where-Object { $_.DesktopGroupName -eq $DesktopGroupName -and $_.SessionState -eq "Disconnected" } | Stop-BrokerSession
            start-sleep $DisconnectWait
        }
        #for each machine check if session count is less then one
        foreach ($machine in $machines) {
            if ((Get-BrokerMachine -AdminAddress $AdminAddress -MachineName $machine).SessionCount -lt 1) {
                Write-Host $machine "has" (Get-BrokerMachine -MachineName $machine).sessioncount "sessions rebooting"
                #if true reboot and turn off maintenance mode
                Get-BrokerMachine -AdminAddress $AdminAddress -MachineName $machine | New-BrokerHostingPowerAction -Action Restart | Set-BrokerMachine -InMaintenanceMode $false
                #remove machine from array
                $machines = $machines | Where-Object { $_ -ne $machine }
            }
        }
        write-host "waiting $retryinterval seconds"
        Start-Sleep $retryinterval
    }
    #verify that machines registered
    Start-Sleep $waitforregisterinterval
    foreach ($machine in $verifymachines) {
        if ((Get-BrokerMachine -AdminAddress $AdminAddress -MachineName $machine).RegistrationState -ne "Registered") { Throw "One or more of rebooted machines did not register. Stopping" }
    }
    write-host "ending the batch" -foregroundcolor green
}



#Main

#calculate reboot count
[int]$totalcount = (Get-BrokerMachine -AdminAddress $AdminAddress -MaxRecordCount $maxrecords -DesktopGroupName $desktopgroupname).count
[int]$machinestoremainup = [System.Math]::Round(($totalcount / 100) * $percenttoremain)
[int]$placeinmaintcount = $totalcount - $machinestoremainup
write-host "`nBatches of $placeinmaintcount machines will be placed in maintenance at one time `n" -ForegroundColor Yellow

#logoff disconnected sessions
if ($LogoffDisconnected -and (Get-BrokerSession -AdminAddress $AdminAddress | Where-Object { $_.DesktopGroupName -eq $DesktopGroupName -and $_.SessionState -eq "Disconnected" })) {
    Write-Host "Logging off disconnected sessions" -ForegroundColor Yellow
    Get-BrokerSession -AdminAddress $AdminAddress | Where-Object { $_.DesktopGroupName -eq $DesktopGroupName -and $_.SessionState -eq "Disconnected" } | Stop-BrokerSession
    Start-Sleep $DisconnectWait
}
#get machines with zero sessions first and reboot
$zerosessionmachines = Get-BrokerMachine -AdminAddress $AdminAddress -MaxRecordCount $maxrecords -DesktopGroupName $desktopgroupname | Where-Object { $_.SessionCount -lt 1 }

if ($zerosessionmachines.count -gt 0) {
    Write-Host "`nThe following machines do not have sessions. rebooting. $($zerosessionmachines.MachineName) `n" -ForegroundColor Yellow
    #reboot
    Wait-RebootMaintenance -AdminAddress $AdminAddress -machines $zerosessionmachines.machinename -retryinterval $retryinterval -waitforregisterinterval $waitforregisterinterval
    #build remaining array
    write-host "`nBuilding remaining arrays"
    $allmachines = (Get-BrokerMachine -AdminAddress $AdminAddress -MaxRecordCount $maxrecords -DesktopGroupName $desktopgroupname).MachineName | Where-Object { $_ -notin $zerosessionmachines.machinename }
    if ($allmachines.Count -lt 1) {
        write-host "all machines have been rebooted" -ForegroundColor Green
        break
    }
}

else {
    #Get list of machines in delivery group
    $allmachines = (Get-BrokerMachine -AdminAddress $AdminAddress -MaxRecordCount $maxrecords -DesktopGroupName $desktopgroupname).MachineName
}


#Cycle through remaining machines in specified batches
while ($allmachines.count -gt 0) {
    #subtract the placeinmaintenancecount from remaining machines
    $newremainingmachines = $allmachines | Select-Object -first $placeinmaintcount
    #put in maintenance and reboot
    Write-Host "The following machines will be placed into maint" $placeinmaintmachines
    foreach ($box in $newremainingmachines) {
        Write-Host "Placing $box into maintenance"
        set-brokermachine -AdminAddress $AdminAddress -machinename $box -inmaintenancemode $true
    }
    Wait-RebootMaintenance -AdminAddress $AdminAddress -DesktopGroupName $desktopgroupname -machines $newremainingmachines -retryinterval $retryinterval -waitforregisterinterval $waitforregisterinterval -LogoffDisconnected $LogoffDisconnected -DisconnectWait $DisconnectWait
    #update array
    $allmachines = $allmachines | Where-Object { $_ -notin $newremainingmachines }
}
Write-Host "All machines have been rebooted" -ForegroundColor Green