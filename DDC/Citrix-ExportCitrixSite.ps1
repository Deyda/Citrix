<#



PS C:\Users\sleadm\Desktop> foreach($role in $roles.childnodes){write-host $role.name; foreach($permission in $role.perm
ission){write-host "permission: " $permission}}











 .Synopsis
 Provision a given number of VM(s) in one or more MCS DeliveryGroup(s) and assign the VM(s) to a delivery group.

 .Description
 Provision a given number of VM(s).
 This script supports to provision in several MCS catalogs.
 It also supports to attach the newly created VM(s) to a delivery group (only one is supported).
 Finally, you can specify to split equally the VM(s) to provision into different MCS catalogs (optionnal).

 .Parameter DeliveryController
 Specifiy the Delivery Controller to use for the provision
 This parameter is optionnal, by default it will use with the local machine.

 .Parameter VDICount
 Specify how much VM(s) to provision (integer).
 This parameter is mandatory.

 .Parameter Catalog
 Specify a list of MCS catalogs to provision the VM(s) to.
 This parameter is mandatory.

 .Parameter Split
 Split equally the number of VM(s) to provision into the MCS catalogs provided with -Catalog parameter.
 This paramater is optionnal.

 .Parameter DeliveryGroup
 Specifiy the DesktopGroup to attach to the newly created VM(s).
 This parameter is mandatory.

 .Parameter Log
 Specifiy the output file for the logs.
 This parameter is optionnal, by default, it will create a file in the current directory.

 .Example
 # Provision 10 VMs to the "Windows 10" catalog and assign them to the "Desktop" delivery group.
 VDI_Provisionning.ps1 -VDICount 10 -Catalog "Windows10" -DeliveryGroup "Desktop"

 .Example
 # Connect to "CTXDDC01" to provision 10 VMs to the "Windows 10" catalog and assign them to the "Desktop" delivery group.
 VDI_Provisionning.ps1 -DeliveryController "CTXDDC01" -VDICount 10 -Catalog "Windows10" -DeliveryGroup "Desktop"

.Example
 # Provision 10 VMs to the "DTC1" and "DTC2" catalogs    and assign them to the "Desktop" delivery group.
 VDI_Provisionning.ps1 -VDICount 10 -Catalog "DTC1","DTC2" -DeliveryGroup "Desktop"

 .Example
 # Provision 5 (10 split equally between two catalogs) VMs to the "DTC1" and "DTC2" catalogs, assign them 
 to the "Desktop" delivery group and log the output in C:\Temp
 VDI_Provisionning.ps1 -VDICount 10 -Catalog "DTC1","DTC2" -Split -DeliveryGroup "Desktop" -Log "C:\temp\test.log"
#>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Mandatory=$false)] [string]$DeliveryController,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()] [string]$LogFile=".\Export-CitrixSite.log"
)

#Start logging
Start-Transcript -Path $LogFile

#Setting variables prior to their usage is not mandatory
Set-StrictMode -Version 2

#Check Snapin can be loaded
#Could be improved by only loading the necessary modules but it would not be compatible with version older than 1912
Write-Host "Loading Citrix Snapin... " -NoNewline
if(!(Add-PSSnapin Citrix* -ErrorAction SilentlyContinue -PassThru )){
    Write-Host "Failed" -ForegroundColor Red
    Write-Host "Citrix Snapin cannot be loaded. Please, check the component is installed on the computer." -ForegroundColor Red
    #Stop logging
    Stop-Transcript 
    break
}
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Checking the parameters
################################################################################################

#Check if the DeliveryController parameter is set or if it has to use the local machine
if($DeliveryController){
    #Check if the parameter is a FQDN or not
    Write-Host "Trying to contact the Delivery Controller $DeliveryController... " -NoNewline
    if($DeliveryController -contains "."){
        $DDC = Get-BrokerController -DNSName "$DeliveryController"
    } else {
        $DDC = Get-BrokerController -DNSName "$DeliveryController.$env:USERDNSDOMAIN"
    }
} else {
    Write-Host "Trying to contact the Delivery Controller $env:COMPUTERNAME... " -NoNewline
    $DDC = Get-BrokerController -DNSName "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
    $DeliveryController = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
}
if(($DDC)){
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    Write-Host "Cannot contact the Delivery Controller. Please, check the role is installed on the target computer and your account is allowed to communicate with it." -ForegroundColor Red
}

#Check if export file already exists
Write-Host "Creating XML file... " -NoNewline
#Fixing path to save XML if $ExportFile is not set
$XMLPath = (Get-Location).Path
$ExportFile = "$XMLPath\export.xml"

if(Test-Path -Path $ExportFile){
    Write-Host "File already exists" -ForegroundColor Yellow
    $overwrite = $null
    while ($overwrite -notlike "y" -and $overwrite -notlike "n") {
        $overwrite = Read-Host "Do you want to overwrite existing file? Y/N"
    }
    if($overwrite -like "y"){
        try {
            Remove-Item -Path $ExportFile -Force | Out-Null
            [xml]$Doc = New-Object System.Xml.XmlDocument
            $Doc.CreateXmlDeclaration("1.0","UTF-8",$null) | Out-Null
            $oXMLRoot=$Doc.CreateElement("site")
            $Doc.AppendChild($oXMLRoot) | Out-Null
            Write-Host "OK" -ForegroundColor Green
        }
        catch {
            Write-Host "An error occured while deleting existing file" -ForegroundColor Red
            Stop-Transcript
            break
        }
    } else {
        Write-Host "Chose another file name to export the configuration" -ForegroundColor Yellow
        Stop-Transcript
        break
    }
} else {
    [xml]$Doc = New-Object System.Xml.XmlDocument
    $Doc.CreateXmlDeclaration("1.0","UTF-8",$null) | Out-Null
    $oXMLRoot=$Doc.CreateElement("site")
    $Doc.AppendChild($oXMLRoot) | Out-Null
    Write-Host "OK" -ForegroundColor Green
}

#Check if resources folder exists (to store icon)
if(Test-Path -path "./resources"){
    Remove-item -Path "./resources" -Force -Recurse | Out-Null
    New-Item -Name "resources" -ItemType Directory | Out-Null
} else {
    New-Item -Name "resources" -ItemType Directory | Out-Null
}

################################################################################################
#Enumerating Site's Properties
################################################################################################

Write-Host "Enumerating Site's Properties... " -NoNewline
try {
    $oXMLProperties = $oXMLRoot.appendChild($Doc.CreateElement("Properties"))
    $Site = Get-BrokerSite
    $oxmlDDC = $oXMLProperties.appendChild($Doc.CreateElement("DDC"))
    $oxmlDDC.InnerText = $DeliveryController
    $oxmlTrustXML = $oXMLProperties.appendChild($Doc.CreateElement("TrustXML"))
    $oxmltagName = $oxmlTrustXML.appendChild($Doc.CreateElement("Enabled"))
    $oxmltagName.InnerText = $Site.TrustRequestsSentToTheXmlServicePort
}
catch {
    Write-Host "An error occured while enumerating Site's Properties" -ForegroundColor Red
    Stop-Transcript
    break
}
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating Site's Tags
################################################################################################

Write-Host "Enumerating Site's Tags... " -NoNewline
try {
    $oXMLTags = $oXMLRoot.appendChild($Doc.CreateElement("Tags"))
    $tags = Get-BrokerTag
    foreach ($Tag in $Tags) {
        $oxmlTag = $oXMLTags.appendChild($Doc.CreateElement("Tag"))
        $oxmltagName = $oXMLTag.appendChild($Doc.CreateElement("Name"))
        $oxmltagName.InnerText = $Tag.Name
    }
}
catch {
    Write-Host "An error occured while enumerating Site's tags" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating Site's Administrators
################################################################################################

Write-Host "Enumerating Roles config... " -NoNewline
try {
    $oXMLRoles = $oXMLRoot.appendChild($Doc.CreateElement("Roles"))
    $Roles = get-adminRole
    foreach ($Role in $Roles) {
        $oxmlRole = $oXMLRoles.appendChild($Doc.CreateElement("Role"))
        $oxmlrolename = $oxmlRole.appendChild($Doc.CreateElement("Name"))
        $oxmlrolename.InnerText = $Role.Name
        $oxmlroleDescription = $oxmlRole.appendChild($Doc.CreateElement("Description"))
        $oxmlroleDescription.InnerText = $Role.Description
        $permissions = $Role.Permissions
        foreach ($permission in $permissions){
            $oxmlrolepermission = $oxmlrole.appendChild($Doc.CreateElement("Permission"))
            $oxmlrolepermission.InnerText = $permission
        }
    }
}
catch {
    Write-Host "An error occured while enumerating Roles config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

Write-Host "Enumerating Scopes config... " -NoNewline
try {
    $oXMLScopes = $oXMLRoot.appendChild($Doc.CreateElement("Scopes"))
    $scopes = get-adminscope
    foreach ($scope in $scopes) {
        $oxmlscope = $oXMLscopes.appendChild($Doc.CreateElement("Scope"))
        $oxmlscopename = $oxmlscope.appendChild($Doc.CreateElement("Name"))
        $oxmlscopename.InnerText = $scope.Name
        $oxmlscopeDescription = $oxmlscope.appendChild($Doc.CreateElement("Description"))
        $oxmlscopeDescription.InnerText = $scope.Description
    }
}
catch {
    Write-Host "An error occured while enumerating Scopes config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

Write-Host "Enumerating Administrators config... " -NoNewline
try {
    $oXMLadmins = $oXMLRoot.appendChild($Doc.CreateElement("Administrators"))
    $admins = get-adminadministrator
    foreach ($admin in $admins) {
        $oxmladmin = $oXMLadmins.appendChild($Doc.CreateElement("Administrator"))
        $oxmladminname = $oxmladmin.appendChild($Doc.CreateElement("Name"))
        $oxmladminname.InnerText = $admin.Name
        $oxmladminEnabled = $oxmladmin.appendChild($Doc.CreateElement("Enabled"))
        $oxmladminEnabled.InnerText = $admin.Enabled
        $oxmladminrolename = $oxmladmin.appendChild($Doc.CreateElement("RoleName"))
        $oxmladminrolename.InnerText = $admin.Rights.RoleName
        $oxmladminScopeName = $oxmladmin.appendChild($Doc.CreateElement("ScopeName"))
        $oxmladminScopeName.InnerText = $admin.Rights.ScopeName
    }
}
catch {
    Write-Host "An error occured while enumerating Administrators config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating Catalogs
################################################################################################

Write-Host "Enumerating Catalogs config... " -NoNewline
try {
    $oXMLCatalogs = $oXMLRoot.appendChild($Doc.CreateElement("Catalogs"))
    $Catalogs = Get-BrokerCatalog
    foreach ($Catalog in $Catalogs) {
        $oxmlCatalog = $oXMLCatalogs.appendChild($Doc.CreateElement("Catalog"))
        $oxmlCatalogname = $oxmlCatalog.appendChild($Doc.CreateElement("Name"))
        $oxmlCatalogname.InnerText = $Catalog.Name
        $oxmlCatalogDescription = $oxmlCatalog.appendChild($Doc.CreateElement("Description"))
        $oxmlCatalogDescription.InnerText = $Catalog.Description
        $oxmlCatalogAllocationType = $oxmlCatalog.appendChild($Doc.CreateElement("AllocationType"))
        $oxmlCatalogAllocationType.InnerText = $Catalog.AllocationType
        $oxmlCatalogProvisioningType = $oxmlCatalog.appendChild($Doc.CreateElement("ProvisioningType"))
        $oxmlCatalogProvisioningType.InnerText = $Catalog.ProvisioningType
        $oxmlCatalogSessionSupport = $oxmlCatalog.appendChild($Doc.CreateElement("SessionSupport"))
        $oxmlCatalogSessionSupport.InnerText = $Catalog.SessionSupport
        $oxmlCatalogPersistUserChanges = $oxmlCatalog.appendChild($Doc.CreateElement("PersistUserChanges"))
        $oxmlCatalogPersistUserChanges.InnerText = $Catalog.PersistUserChanges
        $oxmlCatalogIsRemotePC = $oxmlCatalog.appendChild($Doc.CreateElement("IsRemotePC"))
        $oxmlCatalogIsRemotePC.InnerText = $Catalog.IsRemotePC
        $oxmlCatalogMachinesArePhysical = $oxmlCatalog.appendChild($Doc.CreateElement("MachinesArePhysical"))
        $oxmlCatalogMachinesArePhysical.InnerText = $Catalog.MachinesArePhysical
        $oxmlCatalogProvisioningSchemeName = $oxmlCatalog.appendChild($Doc.CreateElement("ProvisioningSchemeName"))
        if($Catalog.ProvisioningSchemeId){ #Does not exist for Non-provisioned catalogs
            $ProvisioningSchemeName = (Get-ProvScheme -ProvisioningSchemeUid $Catalog.ProvisioningSchemeId).ProvisioningSchemeName
            $oxmlCatalogProvisioningSchemeNAme.InnerText = $ProvisioningSchemeName
        }
        $oxmlCatalogHypervisorConnectionUid = $oxmlCatalog.appendChild($Doc.CreateElement("HypervisorConnectionUid")) #NotUsed
        $oxmlCatalogHypervisorConnectionUid.InnerText = $Catalog.HypervisorConnectionUid #NotUsed
        $scopes = $Catalog.Scopes
        foreach ($scope in $scopes){
            $oxmlCatalogscope = $oxmlCatalog.appendChild($Doc.CreateElement("scope"))
            $oxmlCatalogscope.InnerText = $scope
        }
    }
}
catch {
    Write-Host "An error occured while enumerating Catalogs config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating ProvSchemes
################################################################################################

Write-Host "Enumerating ProvSchemes config... " -NoNewline
try {
    $oXMLProvSchemes = $oXMLRoot.appendChild($Doc.CreateElement("ProvSchemes"))
    $ProvSchemes = Get-ProvScheme
    foreach ($ProvScheme in $ProvSchemes) {
        $oxmlProvScheme = $oXMLProvSchemes.appendChild($Doc.CreateElement("ProvScheme"))
        $oxmlProvSchemeProvisioningSchemeName = $oxmlProvScheme.appendChild($Doc.CreateElement("ProvisioningSchemeName"))
        $oxmlProvSchemeProvisioningSchemeName.InnerText = $ProvScheme.ProvisioningSchemeName
        $oxmlProvSchemeProvisionSchemeUid = $oxmlProvScheme.appendChild($Doc.CreateElement("ProvisioningSchemeUid"))
        $oxmlProvSchemeProvisionSchemeUid.InnerText = $ProvScheme.ProvisioningSchemeUid
        $oxmlProvSchemeHostingUnitName = $oxmlProvScheme.appendChild($Doc.CreateElement("HostingUnitName"))
        $oxmlProvSchemeHostingUnitName.InnerText = $ProvScheme.HostingUnitName
        $oxmlProvSchemeMasterImageVM = $oxmlProvScheme.appendChild($Doc.CreateElement("MasterImageVM"))
        $oxmlProvSchemeMasterImageVM.InnerText = $ProvScheme.MasterImageVM
        $oxmlProvSchemeIdentityPoolName = $oxmlProvScheme.appendChild($Doc.CreateElement("IdentityPoolName"))
        $oxmlProvSchemeIdentityPoolName.InnerText = $ProvScheme.IdentityPoolName
        $oxmlProvSchemeCpuCount = $oxmlProvScheme.appendChild($Doc.CreateElement("CpuCount"))
        $oxmlProvSchemeCpuCount.InnerText = $ProvScheme.CpuCount
        $oxmlProvSchemeMemoryMB = $oxmlProvScheme.appendChild($Doc.CreateElement("MemoryMB"))
        $oxmlProvSchemeMemoryMB.InnerText = $ProvScheme.MemoryMB
        $oxmlProvSchemeDiskSize = $oxmlProvScheme.appendChild($Doc.CreateElement("DiskSize")) #NotUsed
        $oxmlProvSchemeDiskSize.InnerText = $ProvScheme.DiskSize #NotUsed
        $oxmlProvSchemeCleanOnBoot = $oxmlProvScheme.appendChild($Doc.CreateElement("CleanOnBoot"))
        $oxmlProvSchemeCleanOnBoot.InnerText = $ProvScheme.CleanOnBoot
        $oxmlProvSchemeUsePersonnalVDiskStorage = $oxmlProvScheme.appendChild($Doc.CreateElement("UsePersonalVDiskStorage"))
        $oxmlProvSchemeUsePersonnalVDiskStorage.InnerText = $ProvScheme.UsePersonalVDiskStorage
        $oxmlProvSchemeUseWriteBackCache = $oxmlProvScheme.appendChild($Doc.CreateElement("UseWriteBackCache"))
        $oxmlProvSchemeUseWriteBackCache.InnerText = $ProvScheme.UseWriteBackCache
        $oxmlProvSchemeWriteBackCacheDiskSize = $oxmlProvScheme.appendChild($Doc.CreateElement("WriteBackCacheDiskSize"))
        $oxmlProvSchemeWriteBackCacheDiskSize.InnerText = $ProvScheme.WriteBackCacheDiskSize
        $oxmlProvSchemeWriteBackCacheMemorySize = $oxmlProvScheme.appendChild($Doc.CreateElement("WriteBackCacheMemorySize"))
        $oxmlProvSchemeWriteBackCacheMemorySize.InnerText = $ProvScheme.WriteBackCacheMemorySize
        $oxmlProvSchemeWriteBackCacheDiskIndex = $oxmlProvScheme.appendChild($Doc.CreateElement("WriteBackCacheDiskIndex")) #NotUsed
        $oxmlProvSchemeWriteBackCacheDiskIndex.InnerText = $ProvScheme.WriteBackCacheDiskIndex #NotUsed
        $scopes = $ProvScheme.Scopes
        foreach ($scope in $scopes){
            $oxmlProvSchemescope = $oxmlProvScheme.appendChild($Doc.CreateElement("scope"))
            $oxmlProvSchemescope.InnerText = $scope.scopeName
        }
    }
}
catch {
    Write-Host "An error occured while enumerating ProvSchemes config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating AcctIdentityPool
################################################################################################

Write-Host "Enumerating AcctIdentityPool config... " -NoNewline
try {
    $oXMLAcctIdentityPools = $oXMLRoot.appendChild($Doc.CreateElement("AcctIdentityPools"))
    $AcctIdentityPools = Get-AcctIdentityPool
    foreach ($AcctIdentityPool in $AcctIdentityPools) {
        $oxmloXMLAcctIdentityPool= $oXMLAcctIdentityPools.appendChild($Doc.CreateElement("AcctIdentityPool"))
        $oxmloXMLAcctIdentityPoolIdentityPoolName = $oxmloXMLAcctIdentityPool.appendChild($Doc.CreateElement("IdentityPoolName"))
        $oxmloXMLAcctIdentityPoolIdentityPoolName.InnerText = $AcctIdentityPool.IdentityPoolName
        $oxmloXMLAcctIdentityPoolIdentityPoolUid = $oxmloXMLAcctIdentityPool.appendChild($Doc.CreateElement("IdentityPoolUid"))
        $oxmloXMLAcctIdentityPoolIdentityPoolUid.InnerText = $AcctIdentityPool.IdentityPoolUid
        $oxmloXMLAcctIdentityPoolIdentityPoolDomain = $oxmloXMLAcctIdentityPool.appendChild($Doc.CreateElement("Domain"))
        $oxmloXMLAcctIdentityPoolIdentityPoolDomain.InnerText = $AcctIdentityPool.Domain
        $oxmloXMLAcctIdentityPoolIdentityPoolNamingScheme = $oxmloXMLAcctIdentityPool.appendChild($Doc.CreateElement("NamingScheme"))
        $oxmloXMLAcctIdentityPoolIdentityPoolNamingScheme.InnerText = $AcctIdentityPool.NamingScheme
        $oxmloXMLAcctIdentityPoolIdentityPoolNamingSchemeType = $oxmloXMLAcctIdentityPool.appendChild($Doc.CreateElement("NamingSchemeType"))
        $oxmloXMLAcctIdentityPoolIdentityPoolNamingSchemeType.InnerText = $AcctIdentityPool.NamingSchemeType
        $oxmloXMLAcctIdentityPoolIdentityPoolOU = $oxmloXMLAcctIdentityPool.appendChild($Doc.CreateElement("OU"))
        $oxmloXMLAcctIdentityPoolIdentityPoolOU.InnerText = $AcctIdentityPool.OU
        $scopes = $AcctIdentityPool.Scopes
        foreach ($scope in $scopes){
            $oxmloXMLAcctIdentityPoolscope = $oxmloXMLAcctIdentityPool.appendChild($Doc.CreateElement("scope"))
            $oxmloXMLAcctIdentityPoolscope.InnerText = $scope.scopeName
        }
    }
}
catch {
    Write-Host "An error occured while enumerating AcctIdentityPool config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating DeliveryGroups
################################################################################################

Write-Host "Enumerating Delivery Groups config... " -NoNewline
try {
    $oXMLDeliveryGroups = $oXMLRoot.appendChild($Doc.CreateElement("DeliveryGroups"))
    $DeliveryGroups = Get-BrokerDesktopGroup
    foreach ($DeliveryGroup in $DeliveryGroups) {
        $oxmlDeliveryGroup = $oXMLDeliveryGroups.appendChild($Doc.CreateElement("DeliveryGroup"))
        $oxmlDeliveryGroupname = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("Name"))
        $oxmlDeliveryGroupname.InnerText = $DeliveryGroup.Name
        $oxmlDeliveryGroupPublishedName = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PublishedName"))
        $oxmlDeliveryGroupPublishedName.InnerText = $DeliveryGroup.PublishedName
        $oxmlDeliveryGroupDescription = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("Description"))
        $oxmlDeliveryGroupDescription.InnerText = $DeliveryGroup.Description
        $oxmlDeliveryGroupDeliveryType = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("DeliveryType"))
        $oxmlDeliveryGroupDeliveryType.InnerText = $DeliveryGroup.DeliveryType
        $oxmlDeliveryGroupIconUid = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("IconUid"))
        $oxmlDeliveryGroupIconUid.InnerText = $DeliveryGroup.IconUid
        $iconUid = $DeliveryGroup.IconUid
        if(!(test-path -Path "./resources/$iconuid.txt")){
            (Get-BrokerIcon -Uid $iconUid).EncodedIconData | Out-File "./resources/$iconuid.txt"
        }
        $oxmlDeliveryGroupDesktopKind = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("DesktopKind"))
        $oxmlDeliveryGroupDesktopKind.InnerText = $DeliveryGroup.DesktopKind
        $oxmlDeliveryGroupEnabled = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("Enabled"))
        $oxmlDeliveryGroupEnabled.InnerText = $DeliveryGroup.Enabled
        $oxmlDeliveryGroupAutomaticPowerOnForAssigned = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("AutomaticPowerOnForAssigned"))
        $oxmlDeliveryGroupAutomaticPowerOnForAssigned.InnerText = $DeliveryGroup.AutomaticPowerOnForAssigned
        $oxmlDeliveryGroupAutomaticPowerOnForAssignedDuringPeak = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("AutomaticPowerOnForAssignedDuringPeak"))
        $oxmlDeliveryGroupAutomaticPowerOnForAssignedDuringPeak.InnerText = $DeliveryGroup.AutomaticPowerOnForAssignedDuringPeak
        $oxmlDeliveryGroupIsRemotePC = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("IsRemotePC"))
        $oxmlDeliveryGroupIsRemotePC.InnerText = $DeliveryGroup.IsRemotePC
        $oxmlDeliveryGroupOffPeakBufferSizePercent = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("OffPeakBufferSizePercent"))
        $oxmlDeliveryGroupOffPeakBufferSizePercent.InnerText = $DeliveryGroup.OffPeakBufferSizePercent
        $oxmlDeliveryGroupOffPeakDisconnectAction = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("OffPeakDisconnectAction"))
        $oxmlDeliveryGroupOffPeakDisconnectAction.InnerText = $DeliveryGroup.OffPeakDisconnectAction
        $oxmlDeliveryGroupOffPeakDisconnectTimeout = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("OffPeakDisconnectTimeout"))
        $oxmlDeliveryGroupOffPeakDisconnectTimeout.InnerText = $DeliveryGroup.OffPeakDisconnectTimeout
        $oxmlDeliveryGroupOffPeakExtendedDisconnectAction = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("OffPeakExtendedDisconnectAction"))
        $oxmlDeliveryGroupOffPeakExtendedDisconnectAction.InnerText = $DeliveryGroup.OffPeakExtendedDisconnectAction
        $oxmlDeliveryGroupOffPeakExtendedDisconnectTimeout = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("OffPeakExtendedDisconnectTimeout"))
        $oxmlDeliveryGroupOffPeakExtendedDisconnectTimeout.InnerText = $DeliveryGroup.OffPeakExtendedDisconnectTimeout
        $oxmlDeliveryGroupOffPeakLogOffAction = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("OffPeakLogOffAction"))
        $oxmlDeliveryGroupOffPeakLogOffAction.InnerText = $DeliveryGroup.OffPeakLogOffAction
        $oxmlDeliveryGroupOffPeakLogOffTimeout = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("OffPeakLogOffTimeout"))
        $oxmlDeliveryGroupOffPeakLogOffTimeout.InnerText = $DeliveryGroup.OffPeakLogOffTimeout
        $oxmlDeliveryGroupPeakBufferSizePercent = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PeakBufferSizePercent"))
        $oxmlDeliveryGroupPeakBufferSizePercent.InnerText = $DeliveryGroup.PeakBufferSizePercent
        $oxmlDeliveryGroupPeakDisconnectAction = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PeakDisconnectAction"))
        $oxmlDeliveryGroupPeakDisconnectAction.InnerText = $DeliveryGroup.PeakDisconnectAction
        $oxmlDeliveryGroupPeakDisconnectTimeout = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PeakDisconnectTimeout"))
        $oxmlDeliveryGroupPeakDisconnectTimeout.InnerText = $DeliveryGroup.PeakDisconnectTimeout
        $oxmlDeliveryGroupPeakExtendedDisconnectAction = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PeakExtendedDisconnectAction"))
        $oxmlDeliveryGroupPeakExtendedDisconnectAction.InnerText = $DeliveryGroup.PeakExtendedDisconnectAction
        $oxmlDeliveryGroupPeakExtendedDisconnectTimeout = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PeakExtendedDisconnectTimeout"))
        $oxmlDeliveryGroupPeakExtendedDisconnectTimeout.InnerText = $DeliveryGroup.PeakExtendedDisconnectTimeout
        $oxmlDeliveryGroupPeakLogOffAction = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PeakLogOffAction"))
        $oxmlDeliveryGroupPeakLogOffAction.InnerText = $DeliveryGroup.PeakLogOffAction
        $oxmlDeliveryGroupPeakLogOffTimeout = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("PeakLogOffTimeout"))
        $oxmlDeliveryGroupPeakLogOffTimeout.InnerText = $DeliveryGroup.PeakLogOffTimeout
        $scopes = $DeliveryGroup.Scopes
        foreach ($scope in $scopes){
            $oxmlDeliveryGroupscope = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("scope"))
            $oxmlDeliveryGroupscope.InnerText = $scope
        }
        $oxmlDeliveryGroupSessionSupport = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("SessionSupport"))
        $oxmlDeliveryGroupSessionSupport.InnerText = $DeliveryGroup.SessionSupport
        $oxmlDeliveryGroupShutdownDesktopsAfterUse = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("ShutdownDesktopsAfterUse"))
        $oxmlDeliveryGroupShutdownDesktopsAfterUse.InnerText = $DeliveryGroup.ShutdownDesktopsAfterUse
        $Tags = $DeliveryGroup.Tags
        foreach ($Tag in $Tags){
            $oxmlDeliveryGroupTag = $oxmlDeliveryGroup.appendChild($Doc.CreateElement("Tag"))
            $oxmlDeliveryGroupTag.InnerText = $tag
        }
    }
}
catch {
    Write-Host "An error occured while enumerating Delivery Groups config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating EntitlementPolicyRules
################################################################################################

Write-Host "Enumerating EntitlementPolicyRules config... " -NoNewline
try {
    $oXMLEntitlementPolicyRules = $oXMLRoot.appendChild($Doc.CreateElement("EntitlementPolicyRules"))
    $EntitlementPolicyRules = Get-BrokerEntitlementPolicyRule
    foreach ($EntitlementPolicyRule in $EntitlementPolicyRules) {
        $oxmlEntitlementPolicyRule = $oXMLEntitlementPolicyRules.appendChild($Doc.CreateElement("EntitlementPolicyRule"))
        $oxmlEntitlementPolicyRulename = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("Name"))
        $oxmlEntitlementPolicyRulename.InnerText = $EntitlementPolicyRule.Name
        $oxmlEntitlementPolicyRulePublishedName = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("PublishedName"))
        $oxmlEntitlementPolicyRulePublishedName.InnerText = $EntitlementPolicyRule.PublishedName
        $oxmlEntitlementPolicyRuleDescription = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("Description"))
        $oxmlEntitlementPolicyRuleDescription.InnerText = $EntitlementPolicyRule.Description
        $oxmlEntitlementPolicyRuleDesktopGroupName = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("DesktopGroupName"))
        $DesktopGroupName = (Get-BrokerDesktopGroup -Uid $EntitlementPolicyRule.DesktopGroupUid).Name
        $oxmlEntitlementPolicyRuleDesktopGroupName.InnerText = $DesktopGroupName
        $oxmlEntitlementPolicyRuleEnabled = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("Enabled"))
        $oxmlEntitlementPolicyRuleEnabled.InnerText = $EntitlementPolicyRule.Enabled
        $oxmlEntitlementPolicyRuleExcludedUserFilterEnabled = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("ExcludedUserFilterEnabled"))
        $oxmlEntitlementPolicyRuleExcludedUserFilterEnabled.InnerText = $EntitlementPolicyRule.ExcludedUserFilterEnabled
        if($EntitlementPolicyRule.excludedusers){
            $excludedusers = $EntitlementPolicyRule.excludedusers
            foreach ($excludeduser in $excludedusers){
                $oxmlEntitlementPolicyRuleExcludedusers = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("excludeduser"))
                $oxmlEntitlementPolicyRuleExcludedusers.InnerText = $excludeduser.Name
            }
        }
        $oxmlEntitlementPolicyRuleIncludedUserFilterEnabled = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("IncludedUserFilterEnabled"))
        $oxmlEntitlementPolicyRuleIncludedUserFilterEnabled.InnerText = $EntitlementPolicyRule.IncludedUserFilterEnabled
        if($EntitlementPolicyRule.Includedusers){
            $Includedusers = $EntitlementPolicyRule.Includedusers
            foreach ($Includeduser in $Includedusers){
                $oxmlEntitlementPolicyRuleIncludedusers = $oxmlEntitlementPolicyRule.appendChild($Doc.CreateElement("Includeduser"))
                $oxmlEntitlementPolicyRuleIncludedusers.InnerText = $Includeduser.Name
            }
        }
    }
}
catch {
    Write-Host "An error occured while enumerating EntitlementPolicyRules config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating Brokerpowertimeschemes
################################################################################################

Write-Host "Enumerating Brokerpowertimeschemes config... " -NoNewline
try {
    $oXMLBrokerpowertimeschemes = $oXMLRoot.appendChild($Doc.CreateElement("Brokerpowertimeschemes"))
    $Brokerpowertimeschemes = Get-Brokerpowertimescheme
    foreach ($Brokerpowertimescheme in $Brokerpowertimeschemes) {
        $oxmlBrokerpowertimescheme = $oXMLBrokerpowertimeschemes.appendChild($Doc.CreateElement("Brokerpowertimescheme"))
        $oxmlBrokerpowertimeschemename = $oxmlBrokerpowertimescheme.appendChild($Doc.CreateElement("Name"))
        $oxmlBrokerpowertimeschemename.InnerText = $Brokerpowertimescheme.Name
        $oxmlBrokerpowertimeschemeDaysOfWeek = $oxmlBrokerpowertimescheme.appendChild($Doc.CreateElement("DaysOfWeek"))
        $oxmlBrokerpowertimeschemeDaysOfWeek.InnerText = $Brokerpowertimescheme.DaysOfWeek
        $oxmlBrokerpowertimeschemeDesktopGroupname = $oxmlBrokerpowertimescheme.appendChild($Doc.CreateElement("DesktopGroupname"))
        $oxmlBrokerpowertimeschemeDesktopGroupname.InnerText = (Get-BrokerDesktopGroup -Uid $Brokerpowertimescheme.DesktopGroupUid).Name
        $oxmlBrokerpowertimeschemeDisplayName = $oxmlBrokerpowertimescheme.appendChild($Doc.CreateElement("DisplayName"))
        $oxmlBrokerpowertimeschemeDisplayName.InnerText = $Brokerpowertimescheme.DisplayName
        $oxmlBrokerpowertimeschemePoolUsingPercentage = $oxmlBrokerpowertimescheme.appendChild($Doc.CreateElement("PoolUsingPercentage"))
        $oxmlBrokerpowertimeschemePoolUsingPercentage.InnerText = $Brokerpowertimescheme.PoolUsingPercentage
        $PeakHours = $Brokerpowertimescheme.PeakHours
        foreach ($PeakHour in $PeakHours){
            $oxmlBrokerpowertimeschemePoolUsingPeakHour = $oxmlBrokerpowertimescheme.appendChild($Doc.CreateElement("PeakHour"))
            $oxmlBrokerpowertimeschemePoolUsingPeakHour.InnerText = $PeakHour
        }
        $PoolSizes = $Brokerpowertimescheme.PoolSize
        foreach ($PoolSize in $PoolSizes){
            $oxmlBrokerpowertimeschemePoolUsingPoolSize = $oxmlBrokerpowertimescheme.appendChild($Doc.CreateElement("PoolSize"))
            $oxmlBrokerpowertimeschemePoolUsingPoolSize.InnerText = $PoolSize
        }
    }
}
catch {
    Write-Host "An error occured while enumerating Brokerpowertimeschemes config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating BrokeraccesspolicyRules
################################################################################################

Write-Host "Enumerating BrokeraccesspolicyRules config... " -NoNewline
try {
    $oXMLBrokeraccesspolicyRules = $oXMLRoot.appendChild($Doc.CreateElement("BrokeraccesspolicyRules"))
    $BrokeraccesspolicyRules = Get-BrokeraccesspolicyRule
    foreach ($BrokeraccesspolicyRule in $BrokeraccesspolicyRules) {
        $oxmlBrokeraccesspolicyRule = $oXMLBrokeraccesspolicyRules.appendChild($Doc.CreateElement("BrokeraccesspolicyRule"))
        $oxmlBrokeraccesspolicyRuleName = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("Name"))
        $oxmlBrokeraccesspolicyRuleName.InnerText = $BrokeraccesspolicyRule.Name
        $oxmlBrokeraccesspolicyRuleDesktopGroupName = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("DesktopGroupName"))
        $oxmlBrokeraccesspolicyRuleDesktopGroupName.InnerText = (Get-BrokerDesktopGroup -Uid $BrokeraccesspolicyRule.DesktopGroupUid).Name
        $oxmlBrokeraccesspolicyRuleAllowRestart = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("AllowRestart"))
        $oxmlBrokeraccesspolicyRuleAllowRestart.InnerText = $BrokeraccesspolicyRule.AllowRestart
        $oxmlBrokeraccesspolicyRuleAllowedConnections = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("AllowedConnections"))
        $oxmlBrokeraccesspolicyRuleAllowedConnections.InnerText = $BrokeraccesspolicyRule.AllowedConnections
        $oxmlBrokeraccesspolicyRuleAllowedProtocols = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("AllowedProtocols"))
        $oxmlBrokeraccesspolicyRuleAllowedProtocols.InnerText = $BrokeraccesspolicyRule.AllowedProtocols
        $oxmlBrokeraccesspolicyRuleAllowedUsers = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("AllowedUsers"))
        $oxmlBrokeraccesspolicyRuleAllowedUsers.InnerText = $BrokeraccesspolicyRule.AllowedUsers
        $oxmlBrokeraccesspolicyRuleDescription = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("Description"))
        $oxmlBrokeraccesspolicyRuleDescription.InnerText = $BrokeraccesspolicyRule.Description
        $oxmlBrokeraccesspolicyRuleEnabled = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("Enabled"))
        $oxmlBrokeraccesspolicyRuleEnabled.InnerText = $BrokeraccesspolicyRule.Enabled
        $oxmlBrokeraccesspolicyRuleIncludedSmartAccessFilterEnabled = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("IncludedSmartAccessFilterEnabled"))
        $oxmlBrokeraccesspolicyRuleIncludedSmartAccessFilterEnabled.InnerText = $BrokeraccesspolicyRule.IncludedSmartAccessFilterEnabled
        $oxmlBrokeraccesspolicyRuleIncludedUserFilterEnabled = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("IncludedUserFilterEnabled"))
        $oxmlBrokeraccesspolicyRuleIncludedUserFilterEnabled.InnerText = $BrokeraccesspolicyRule.IncludedUserFilterEnabled
        if($BrokeraccesspolicyRule.IncludedUsers){
            $Includedusers = $BrokeraccesspolicyRule.IncludedUsers
            foreach ($Includeduser in $Includedusers){
                $oxmlBrokeraccesspolicyRuleIncludedusers = $oxmlBrokeraccesspolicyRule.appendChild($Doc.CreateElement("Includeduser"))
                $oxmlBrokeraccesspolicyRuleIncludedusers.InnerText = $Includeduser.Name
            }
        }
    }
}
catch {
    Write-Host "An error occured while enumerating BrokeraccesspolicyRules config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating BrokerAppEntitlementPolicyRules
################################################################################################

Write-Host "Enumerating BrokerAppEntitlementPolicyRules config... " -NoNewline
try {
    $oXMLBrokerAppEntitlementPolicyRules = $oXMLRoot.appendChild($Doc.CreateElement("BrokerAppEntitlementPolicyRules"))
    $BrokerAppEntitlementPolicyRules = Get-BrokerAppEntitlementPolicyRule
    foreach ($BrokerAppEntitlementPolicyRule in $BrokerAppEntitlementPolicyRules) {
        $oxmlBrokerAppEntitlementPolicyRule = $oXMLBrokerAppEntitlementPolicyRules.appendChild($Doc.CreateElement("BrokerAppEntitlementPolicyRule"))
        $oxmlBrokerAppEntitlementPolicyRuleName = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("Name"))
        $oxmlBrokerAppEntitlementPolicyRuleName.InnerText = $BrokerAppEntitlementPolicyRule.Name
        $oxmlBrokerAppEntitlementPolicyRuleDesktopGroupName = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("DesktopGroupName"))
        $oxmlBrokerAppEntitlementPolicyRuleDesktopGroupName.InnerText = (Get-BrokerDesktopGroup -Uid $BrokerAppEntitlementPolicyRule.DesktopGroupUid).Name
        $oxmlBrokerAppEntitlementPolicyRuleDescription = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("Description"))
        $oxmlBrokerAppEntitlementPolicyRuleDescription.InnerText = $BrokerAppEntitlementPolicyRule.Description
        $oxmlBrokerAppEntitlementPolicyRuleEnabled = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("Enabled"))
        $oxmlBrokerAppEntitlementPolicyRuleEnabled.InnerText = $BrokerAppEntitlementPolicyRule.Enabled
        $oxmlBrokerAppEntitlementPolicyRuleLeasingBehavior = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("LeasingBehavior"))
        $oxmlBrokerAppEntitlementPolicyRuleLeasingBehavior.InnerText = $BrokerAppEntitlementPolicyRule.LeasingBehavior
        $oxmlBrokerAppEntitlementPolicyRuleSessionReconnection = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("SessionReconnection"))
        $oxmlBrokerAppEntitlementPolicyRuleSessionReconnection.InnerText = $BrokerAppEntitlementPolicyRule.SessionReconnection
        $oxmlBrokerAppEntitlementPolicyRuleExcludedUserFilterEnable = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("ExcludedUserFilterEnable"))
        $oxmlBrokerAppEntitlementPolicyRuleExcludedUserFilterEnable.InnerText = $BrokerAppEntitlementPolicyRule.ExcludedUserFilterEnabled
        $oxmlBrokerAppEntitlementPolicyRuleIncludedUserFilterEnable = $oxmlBrokerAppEntitlementPolicyRule.appendChild($Doc.CreateElement("IncludedUserFilterEnable"))
        $oxmlBrokerAppEntitlementPolicyRuleIncludedUserFilterEnable.InnerText = $BrokerAppEntitlementPolicyRule.IncludedUserFilterEnabled
    }
}
catch {
    Write-Host "An error occured while enumerating BrokerAppEntitlementPolicyRules config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating Brokerrebootschedule
################################################################################################

Write-Host "Enumerating Brokerrebootschedules config... " -NoNewline
try {
    $OXMLBrokerrebootschedules = $oXMLRoot.appendChild($Doc.CreateElement("Brokerrebootschedules"))
    $Brokerrebootschedules = Get-Brokerrebootschedulev2
    foreach ($Brokerrebootschedule in $Brokerrebootschedules) {
        $OXMLBrokerrebootscheduleRule = $OXMLBrokerrebootschedules.appendChild($Doc.CreateElement("Brokerrebootschedule"))
        $OXMLBrokerrebootscheduleName = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("Name"))
        $OXMLBrokerrebootscheduleName.InnerText = $Brokerrebootschedule.Name
        $OXMLBrokerrebootscheduleActive = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("Active"))
        $OXMLBrokerrebootscheduleActive.InnerText = $Brokerrebootschedule.Active
        $OXMLBrokerrebootscheduleDay = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("Day"))
        $OXMLBrokerrebootscheduleDay.InnerText = $Brokerrebootschedule.Day
        $OXMLBrokerrebootscheduleDescription = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("Description"))
        $OXMLBrokerrebootscheduleDescription.InnerText = $Brokerrebootschedule.Description
        $OXMLBrokerrebootscheduleDesktopGroupName = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("DesktopGroupName"))
        $OXMLBrokerrebootscheduleDesktopGroupName.InnerText = $Brokerrebootschedule.DesktopGroupName
        $OXMLBrokerrebootscheduleEnabled = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("Enabled"))
        $OXMLBrokerrebootscheduleEnabled.InnerText = $Brokerrebootschedule.Enabled
        $OXMLBrokerrebootscheduleFrequency = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("Frequency"))
        $OXMLBrokerrebootscheduleFrequency.InnerText = $Brokerrebootschedule.Frequency
        $OXMLBrokerrebootscheduleRebootDuration = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("RebootDuration"))
        $OXMLBrokerrebootscheduleRebootDuration.InnerText = $Brokerrebootschedule.RebootDuration
        $OXMLBrokerrebootscheduleStartTime = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("StartTime"))
        $OXMLBrokerrebootscheduleStartTime.InnerText = $Brokerrebootschedule.StartTime
        $OXMLBrokerrebootscheduleWarningDuration = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("WarningDuration"))
        $OXMLBrokerrebootscheduleWarningDuration.InnerText = $Brokerrebootschedule.WarningDuration
        $OXMLBrokerrebootscheduleWarningMessage = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("WarningMessage"))
        $OXMLBrokerrebootscheduleWarningMessage.InnerText = $Brokerrebootschedule.WarningMessage
        $OXMLBrokerrebootscheduleWarningRepeatInterval = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("WarningRepeatInterval"))
        $OXMLBrokerrebootscheduleWarningRepeatInterval.InnerText = $Brokerrebootschedule.WarningRepeatInterval
        $OXMLBrokerrebootscheduleWarningTitle = $OXMLBrokerrebootscheduleRule.appendChild($Doc.CreateElement("WarningTitle"))
        $OXMLBrokerrebootscheduleWarningTitle.InnerText = $Brokerrebootschedule.WarningTitle
    }
}
catch {
    Write-Host "An error occured while enumerating Brokerrebootschedules config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating PublishedApps
################################################################################################

Write-Host "Enumerating Published Apps config... " -NoNewline
try {
    $oXMLPublishedApps = $oXMLRoot.appendChild($Doc.CreateElement("PublishedApps"))
    $PublishedApps = Get-BrokerApplication
    foreach ($PublishedApp in $PublishedApps) {
        $oxmlPublishedApp = $oXMLPublishedApps.appendChild($Doc.CreateElement("PublishedApp"))
        $oxmlPublishedAppname = $oxmlPublishedApp.appendChild($Doc.CreateElement("Name"))
        $oxmlPublishedAppname.InnerText = $PublishedApp.Name
        $oxmlPublishedAppDescription = $oxmlPublishedApp.appendChild($Doc.CreateElement("Description"))
        $oxmlPublishedAppDescription.InnerText = $PublishedApp.Description
        $oxmlPublishedAppCommandLineExecutable = $oxmlPublishedApp.appendChild($Doc.CreateElement("CommandLineExecutable"))
        $oxmlPublishedAppCommandLineExecutable.InnerText = $PublishedApp.CommandLineExecutable
        $oxmlPublishedAppCommandLineArguments = $oxmlPublishedApp.appendChild($Doc.CreateElement("CommandLineArguments"))
        $oxmlPublishedAppCommandLineArguments.InnerText = $PublishedApp.CommandLineArguments
        $oxmlPublishedAppWorkingDirectory = $oxmlPublishedApp.appendChild($Doc.CreateElement("WorkingDirectory"))
        $oxmlPublishedAppWorkingDirectory.InnerText = $PublishedApp.WorkingDirectory
        $oxmlPublishedAppPublishedName = $oxmlPublishedApp.appendChild($Doc.CreateElement("PublishedName"))
        $oxmlPublishedAppPublishedName.InnerText = $PublishedApp.PublishedName
        $oxmlPublishedAppIconUid = $oxmlPublishedApp.appendChild($Doc.CreateElement("IconUid"))
        $oxmlPublishedAppIconUid.InnerText = $PublishedApp.IconUid
        $iconUid = $PublishedApp.IconUid
        if(!(test-path -Path "./resources/$iconuid.txt")){
            (Get-BrokerIcon -Uid $iconUid).EncodedIconData | Out-File "./resources/$iconuid.txt"
        }
        $oxmlPublishedAppAdminFolderName = $oxmlPublishedApp.appendChild($Doc.CreateElement("AdminFolderName"))
        $oxmlPublishedAppAdminFolderName.InnerText = $PublishedApp.AdminFolderName
        $oxmlPublishedAppApplicationName = $oxmlPublishedApp.appendChild($Doc.CreateElement("ApplicationName"))
        $oxmlPublishedAppApplicationName.InnerText = $PublishedApp.ApplicationName
        $oxmlPublishedAppApplicationType = $oxmlPublishedApp.appendChild($Doc.CreateElement("ApplicationType"))
        $oxmlPublishedAppApplicationType.InnerText = $PublishedApp.ApplicationType
        $AssociatedDesktopGroupUids = $PublishedApp.AssociatedDesktopGroupUids
        foreach ($AssociatedDesktopGroupUid in $AssociatedDesktopGroupUids){
            $oxmlPublishedAppAssociatedDesktopGroupName = $oxmlPublishedApp.appendChild($Doc.CreateElement("AssociatedDesktopGroupName"))
            $DesktopGroupName = (Get-BrokerDesktopGroup -Uid $AssociatedDesktopGroupUid).Name
            $oxmlPublishedAppAssociatedDesktopGroupName.InnerText = $DesktopGroupName
        }
        $AssociatedUserFullNames = $PublishedApp.AssociatedUserFullNames
        foreach ($AssociatedUserFullName in $AssociatedUserFullNames){
            $oxmlPublishedAppAssociatedUserFullName = $oxmlPublishedApp.appendChild($Doc.CreateElement("AssociatedUserFullName"))
            $oxmlPublishedAppAssociatedUserFullName.InnerText = $AssociatedUserFullName
        }
        $oxmlPublishedAppEnabled = $oxmlPublishedApp.appendChild($Doc.CreateElement("Enabled"))
        $oxmlPublishedAppEnabled.InnerText = $PublishedApp.Enabled
        $oxmlPublishedAppMaxPerUserInstances = $oxmlPublishedApp.appendChild($Doc.CreateElement("MaxPerUserInstances"))
        $oxmlPublishedAppMaxPerUserInstances.InnerText = $PublishedApp.MaxPerUserInstances
        $oxmlPublishedAppMaxTotalInstances = $oxmlPublishedApp.appendChild($Doc.CreateElement("MaxTotalInstances"))
        $oxmlPublishedAppMaxTotalInstances.InnerText = $PublishedApp.MaxTotalInstances
        $oxmlPublishedAppShortcutAddedToDesktop = $oxmlPublishedApp.appendChild($Doc.CreateElement("ShortcutAddedToDesktop"))
        $oxmlPublishedAppShortcutAddedToDesktop.InnerText = $PublishedApp.ShortcutAddedToDesktop
        $oxmlPublishedAppShortcutAddedToStartMenu = $oxmlPublishedApp.appendChild($Doc.CreateElement("ShortcutAddedToStartMenu"))
        $oxmlPublishedAppShortcutAddedToStartMenu.InnerText = $PublishedApp.ShortcutAddedToStartMenu
        $oxmlPublishedAppStartMenuFolder = $oxmlPublishedApp.appendChild($Doc.CreateElement("StartMenuFolder"))
        $oxmlPublishedAppStartMenuFolder.InnerText = $PublishedApp.StartMenuFolder
        $oxmlPublishedAppUserFilterEnabled = $oxmlPublishedApp.appendChild($Doc.CreateElement("UserFilterEnabled"))
        $oxmlPublishedAppUserFilterEnabled.InnerText = $PublishedApp.UserFilterEnabled
        $oxmlPublishedAppVisible = $oxmlPublishedApp.appendChild($Doc.CreateElement("Visible"))
        $oxmlPublishedAppVisible.InnerText = $PublishedApp.Visible
    }
}
catch {
    Write-Host "An error occured while enumerating Published Apps config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

################################################################################################
#Enumerating FileTypeAssociations
################################################################################################

Write-Host "Enumerating FileTypeAssociations config... " -NoNewline
try {
    $oXMLFileTypeAssociations = $oXMLRoot.appendChild($Doc.CreateElement("FileTypeAssociations"))
    $FileTypeAssociations = Get-BrokerConfiguredFTA
    foreach ($FileTypeAssociation in $FileTypeAssociations) {
        $oXMLFileTypeAssociation = $oXMLFileTypeAssociations.appendChild($Doc.CreateElement("FileTypeAssociation"))
        $Application= (Get-BrokerApplication -Uid $FileTypeAssociation.ApplicationUid).PublishedName
        $oXMLFileTypeAssociationApplication = $oXMLFileTypeAssociation.appendChild($Doc.CreateElement("Application"))
        $oXMLFileTypeAssociationApplication.InnerText = $Application
        $oXMLFileTypeAssociationContentType = $oXMLFileTypeAssociation.appendChild($Doc.CreateElement("ContentType"))
        $oXMLFileTypeAssociationContentType.InnerText = $FileTypeAssociation.ContentType
        $oXMLFileTypeAssociationExtensionName = $oXMLFileTypeAssociation.appendChild($Doc.CreateElement("ExtensionName"))
        $oXMLFileTypeAssociationExtensionName.InnerText = $FileTypeAssociation.ExtensionName
        $oXMLFileTypeAssociationHandlerName = $oXMLFileTypeAssociation.appendChild($Doc.CreateElement("HandlerName"))
        $oXMLFileTypeAssociationHandlerName.InnerText = $FileTypeAssociation.HandlerName
    }
}
catch {
    Write-Host "An error occured while enumerating FileTypeAssociations config" -ForegroundColor Red
    Stop-Transcript
    break
} 
Write-Host "OK" -ForegroundColor Green

$doc.save("$ExportFile")
Stop-Transcript
break