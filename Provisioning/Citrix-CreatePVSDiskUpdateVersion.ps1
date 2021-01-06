<#
.Synopsis
   This script creates PVS disk maintenance version.
.DESCRIPTION
   This script creates maintenance version of a PVS disk and boots dedicated image build machine returning the IP address of that VM.
   Configuration XML file - InteractivePVSConfig.xml is required for this automation to work. Please specify the file path in the Param block under configpath or during execution.
   If the XML path is not specified at that time, the script will attempt to use InteractivePVSConfig.xml file in the same location as the script.
    After configuring paramaters in the XML example file, be sure to rename it to InteractivePVSConfig.xml!
   The script can be ran interactively without parameters.
.EXAMPLE
    .\Citrix-CreatePVSDiskUpdateVersion.ps1 -pvsStoreName "MyStore" -pvsDiskName "myDisk2020" -updatemachine myUpdatemachine -configpath "c:\automation\InteractivePVSConfig.xml"
.NOTES
    Author: Dmitry Palchuk
    Creation Date:  12/2020

#>
Param (
    $pvsstorename,
    $pvsdiskname,
    $updatemachine,
    $configpath
)

#Configuration File Path
#use the same path as the script if config is not specified
if ([string]::IsNullOrEmpty($configpath)) {
    #determine script location
    $myDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    #determine xml file name and location
    [xml]$ConfigFile = Get-Content "$myDir\InteractivePVSConfig.xml" -ErrorAction Stop
}
else {
    [xml]$ConfigFile = Get-Content $configpath
}

#vars
$RemovePVS = $ConfigFile.Settings.BaseSettings.RemotePVS
$RemovePVSServerFQDN = $ConfigFile.Settings.BaseSettings.RemotePVSServerFQDN
$RemovePVSServerPort = $ConfigFile.Settings.BaseSettings.RemotePVSServerPort
$UpdateCollection = $ConfigFile.Settings.PVSSettings.PVSUpdateCollection
$BootTimeout = $ConfigFile.Settings.PVSSettings.BootTimeout

#load module
Import-Module $ConfigFile.Settings.BaseSettings.PVSModuleLocation

#connect to pvs server
if ($RemovePVS -eq "true") {
    Set-PvsConnection -Server $RemovePVSServerFQDN -Port $RemovePVSServerPort
}

#Ask for store name or list stores

if ([string]::IsNullOrEmpty($pvsstorename)) {

    $PVSStores = Citrix.PVS.SnapIn\Get-PvsStore

    Write-Host "Please select the PVS Store"
    For ($i = 0; $i -lt $PVSStores.Count; $i++) {
        Write-Host "$($i+1): $($PVSStores[$i].Name)"
    }

    [int]$number = Read-Host "Press the number to select store"
    $pvsstorename = $PVSStores[$number - 1].Name
    Write-Host "You selected $PVSstorename" -ForegroundColor Green
}

#Check if PVS disk is specified
if ([string]::IsNullOrEmpty($pvsdiskname)) {

    #Check if store contains multple disks and prompt
    if (((Citrix.PVS.SnapIn\Get-PvsDiskLocator | Where-Object { $_.StoreName -eq $pvsstorename }).diskLocatorId).count -gt 1) {

        $Disks = Citrix.PVS.SnapIn\Get-PvsDiskLocator | Where-Object { $_.StoreName -eq $pvsstorename }

        Write-Host "The store you selected contains mutliple disks. Please choose the disk"
        For ($i = 0; $i -lt $Disks.Count; $i++) {
            Write-Host "$($i+1): $($Disks[$i].diskLocatorName)"
        }

        [int]$number = Read-Host "Press the number to select disk"
        $disklocatorname = $Disks[$number - 1].diskLocatorName
        $updateDiskLocatorID = (Citrix.PVS.SnapIn\Get-Pvsdisklocator | Where-Object { $_.DiskLocatorName -eq $disklocatorname }).DiskLocatorId.guid
    }

    else {
        $disklocator = Citrix.PVS.SnapIn\Get-PvsDiskLocator | Where-Object { $_.StoreName -eq $pvsstorename }
        $updateDiskLocatorID = $disklocator.disklocatorid.Guid
    }
}
else {
    $updateDiskLocatorID = (Citrix.PVS.SnapIn\Get-Pvsdisklocator | Where-Object { $_.DiskLocatorName -eq $pvsdiskname }).DiskLocatorId.guid
}

#Check if any of the disk versions are Test or Maintenance
#if exists notify with machine name its attached to
$updateVersions = Citrix.PVS.SnapIn\Get-PvsDiskVersion -DiskLocatorId $disklocator.disklocatorid.Guid
foreach ($updateversion in $updateversions) {
    if ($updateversion.Access -eq 1 -or $updateversion.Access -eq 2) {
        Throw "Maintenance or Test Version of $($disklocator.name) exists. It may need to be promoted or deleted. It is assigned to $($updatevm.name). Check disk versions under $storename store."

    }
}


#verify that update VM exists and it is in maintenance
#check in specified collection
if ([string]::IsNullOrEmpty($updatemachine) -and (![string]::IsNullOrEmpty($UpdateCollection)) ) {
    $updatevm = Citrix.PVS.SnapIn\Get-PvsDeviceInfo | Where-Object { $_.DiskLocatorName -eq $($($disklocator.StoreName) + "\" + $($disklocator.DiskLocatorName)) -and $_.Type -ne 0 -and $_.CollectionName -eq $UpdateCollection }
    if ([string]::IsNullOrEmpty($updatevm)) {
        Throw "Update machine not found or its not in maintenance mode. Please check $UpdateCollection collection and create new machine or assign disk to an available machine"
    }
}
#check against site
elseif ([string]::IsNullOrEmpty($updatemachine) -and ([string]::IsNullOrEmpty($UpdateCollection)) ) {
    $updatevm = Citrix.PVS.SnapIn\Get-PvsDeviceInfo | Where-Object { $_.DiskLocatorName -eq $($($disklocator.StoreName) + "\" + $($disklocator.DiskLocatorName)) -and $_.Type -ne 0 }
    if ([string]::IsNullOrEmpty($updatevm)) {
        Throw "Update machine not found in PVS Site or its not in maintenance mode. Please check machine setting to ensure its in Maintenance mode or create new machine or assign disk to an available machine"
    }
}
#use specified update machine
else {
    $updatevm = Citrix.PVS.SnapIn\Get-PvsDeviceInfo -DeviceName $updatemachine
    if ($updatevm.Type -eq 0) {
        Throw "Update VM is not in maintenance mode. Please verify configuration."
    }
}

#verify that only one update machine is specified
if ($updatevm.Count -gt 1) {
    Write-Host "Multiple machines are in maintenance mode with specified disk attached. Please choose the machine to use"
    $updatevms = $updatevm
    For ($i = 0; $i -lt $updatevms.Count; $i++) {
        Write-Host "$($i+1): $($updatevms[$i].name)"
    }

    [int]$number = Read-Host "Press the number to select machine"
    $updatemachine = $updatevms[$number - 1].name
    write-host "you selected $updatemachine" -ForegroundColor Green
    $updatevm = Citrix.PVS.SnapIn\Get-PvsDeviceInfo -DeviceName $updatevm

}

if ($updatevm.Type -ne 2) {
    Throw "$($updatevm.Nam) is not configured for maintenance mode. Please check the VM under $UpdateCollection collection"

}
if ($updatevm.Active -eq "True") {
    Throw "$($updatevm.Name) $($updatevm.Ip) is powered on. That is not expected. Machine may be in use. Please check the VM and re run the script"

}

#create new version
$diskcreate = Citrix.PVS.SnapIn\New-PvsDiskMaintenanceVersion -DiskLocatorId $updateDiskLocatorID

#Label version via desciption
Citrix.PVS.SnapIn\set-pvsdiskversion -DiskLocatorId $updateDiskLocatorID  -Version $diskcreate.Version -Description "SDK-created update disk on $(Get-Date -Format yyyy-MM-dd-hh-mm-ss)"
write-host "`nCreated writable version of" $($($disklocator.StoreName) + "\" + $($disklocator.DiskLocatorName)) -ForegroundColor Green

#boot update VM
write-host "`nStarting" $updatevm.Name -ForegroundColor Yellow
Citrix.PVS.SnapIn\Start-PvsDeviceBoot -DeviceName $updatevm.name | Out-Null
#check for IP and timeout if not found
Start-Sleep $BootTimeout
#Configure and start timer
$CheckEvery = 10
$timer = [Diagnostics.Stopwatch]::StartNew()

#Check IP address
while ((Citrix.PVS.SnapIn\Get-PvsDeviceInfo -DeviceName $updatevm.Name).Ip.IPAddressToString -eq '0.0.0.0') {
    ## If the timer has waited greater than or equal to the timeout, throw an exception exiting the loop
    if ($timer.Elapsed.TotalSeconds -ge $BootTimeout) {
        Throw "Timeout exceeded. Giving up on booting $updatevm.Name. Please check manually"
    }
    ## Stop the loop every $CheckEvery seconds
    Start-Sleep -Seconds $CheckEvery >$null
}

## When finished, stop the timer
$timer.Stop()
Write-Host "`nThe device name is" $updatevm.Name "and device IP is" $(Citrix.PVS.SnapIn\Get-PvsDeviceInfo -DeviceName $updatevm.Name).Ip.IPAddressToString -ForegroundColor Green