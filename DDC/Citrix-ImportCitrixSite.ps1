<#
 .Synopsis
 Import the configuration from XML file

 .Description
 Import the configuration from a specified XML file to Citrix Site.
 Icons encoded data are imported from a "resources" folder set as a parameter.
 Created element are:
 - Site Properties (Trust XML, Tags)
 - Administrators (ADGroup/ADUser, scopes, roles)
 - Catalogs (including Provisioning Schemes and Identity Pools)
 - Delivery Groups (including Power Management rules and Reboot Schedules)
 - Published Applications (including icons and File Type Associations)
 If a resource (administrators, catalogs, applications and so on) with the same name already exists, 
 the script won't altered the existing one.
 and will display a warning.

 .Parameter XMLFile
 XML File to import configuration from.
 Must be generated from Export-CitrixSite.ps1 (it can be modified afterwards
 but the structure must match one from the previous powershell script).

 .Parameter ResourcesFolder
 Specifiy the folder where are stored Icon encoded data for published applications.
 efault, it will create a file in the current directory.

 .Example
 # Import the configuration from export.xml file
 Import-CitrixSite.ps1 -XMLFile "./export.xml"
 
 .Example
 # Connect to "CTXDDC01" to import the configuration from export.xml file
 Import-CitrixSite.ps1 -DeliveryController "CTXDDC01" -XMLFile "./export.xml"

 .Example
 # Import the configuration from export.xml file and use "resources" directory to import icon
 # encoded data
 Import-CitrixSite.ps1 -XMLFile "./export.xml" -resourcesfolder "./resources"

.Example
 # Import the configuration from export.xml file and log the output in C:\Temp\test.log
 Import-CitrixSite.ps1 -XMLFile "./export.xml" -Log "C:\temp\test.log"


 .Example
 # Provision 10 VMs to the "Windows 10" catalog and assign them to the "Desktop" delivery group.
 VDI_Provisionning.ps1 -VDICount 10 -Catalog "Windows10" -DeliveryGroup "Desktop"
 #>

[CmdletBinding()]
Param(
    # Declaring input variables for the script
    [Parameter(Mandatory=$true)] [string]$XMLFile,
    [Parameter(Mandatory=$false)] [string]$ResourcesFolder,
    [Parameter(Mandatory=$false)] [string]$DeliveryController,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()] [string]$LogFile=".\Import-CitrixSite.log"
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
}
if(($DDC)){
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    Write-Host "Cannot contact the Delivery Controller. Please, check the role is installed on the target computer and your account is allowed to communicate with it." -ForegroundColor Red
}

#TODO Check if current DDC = DDC in the XML
#WARN about lauching the script on the same DDC as the one in export file!

#Check if export file exists
Write-Host "Checking XML file... " -NoNewline
Try{
    #TODO improve check (google to check XML)
    $xdoc = New-Object System.Xml.XmlDocument
    $file = Resolve-Path($XMLFile)
    $xdoc.load($file)
}
catch{
    Write-Host "An error occured while importing XML file" -ForegroundColor Red
    Stop-Transcript
    break
}
Write-Host "OK" -ForegroundColor Green


#Check if resources folder exists (to import icon)
Write-Host "Checking resources folder... " -NoNewline
#TODO improve check (uid.txt as childitem)
if(Test-Path -path $ResourcesFolder){
    Write-Host "OK" -ForegroundColor Green
} else {
    Write-Host "An error occured while checking resources folder. Ensure the path is correct." -ForegroundColor Red
    Stop-Transcript
    break
}

################################################################################################
#Setting Site's Properties
################################################################################################
if($xdoc.site.Properties.TrustXML.InnerText){
    Write-Host "Setting Site's TrustXML Property... " -NoNewline
    try {
        $value = [bool]$xdoc.site.Properties.TrustXML.InnerText
        Set-BrokerSite -TrustRequestsSentToTheXmlServicePort $value
    }
    catch {
        Write-Host "An error occured while setting Site's TrustXML Property" -ForegroundColor Red
        Stop-Transcript
        break
    }
    Write-Host "OK" -ForegroundColor Green
}

################################################################################################
#Setting Site's Tags
################################################################################################

Write-Host "Setting Site's Tags... " -NoNewline
if($xdoc.site.tags){
    $tags = $xdoc.site.tags.tag
    foreach($tag in $tags){
        if(!(Get-BrokerTag -Name $tag.Name -errorAction SilentlyContinue)){
            Write-host "Adding new tag" $tag.Name"... " -NoNewline
            try {
                New-BrokerTag -Name $scope.Name  | out-null
                Write-Host "OK" -ForegroundColor Green
            }
            catch {
                Write-Host "An error occured while adding a new tag" -ForegroundColor Red
                Stop-Transcript
                break
            }
        } else {
            Write-Host $tag.Name "already exists. tag won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually tag's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No tags to import" -ForegroundColor Yellow
}

################################################################################################
#Setting Site's Administrators
################################################################################################

Write-Host "Setting Roles config... "
if($xdoc.site.Roles){
    $roles = $xdoc.site.roles.role
    foreach($role in $roles){
        if(!(Get-AdminRole -Name $role.Name -errorAction SilentlyContinue)){
            Write-host "Adding new role" $role.Name"... " -NoNewline
            try {
                New-AdminRole -Name $role.Name -description $role.description | out-null
                Write-Host "OK" -ForegroundColor Green
                Write-host "Adding permissions to" $role.name"... " -NoNewline
                try {
                    Add-AdminPermission -Role $role.name -Permission $role.permission
                    Write-host "OK" -ForegroundColor Green
                }
                catch {
                    Write-Host "An error occured while setting permissions for" $role.name -ForegroundColor Red                        
                    Stop-Transcript
                    break
                }
            }
            catch {
                Write-Host "An error occured while adding a new role" -ForegroundColor Red
                Stop-Transcript
                break
            }
        } else {
            Write-Host $role.name "already exists. Role won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually role's properties." -ForegroundColor Yellow
        }
    }
}else {
    Write-Host "No roles to import" -ForegroundColor Yellow
}

Write-Host "Setting Scopes config... "
if($xdoc.site.scopes){
    $scopes = $xdoc.site.scopes.scope
    foreach($scope in $scopes){
        if(!(Get-AdminScope -Name $scope.Name -errorAction SilentlyContinue)){
            Write-host "Adding new scope" $scope.Name"... " -NoNewline
            try {
                New-AdminScope -Name $scope.Name -description $scope.description | out-null
                Write-Host "OK" -ForegroundColor Green
            }
            catch {
                Write-Host "An error occured while adding a new scope" -ForegroundColor Red
                Stop-Transcript
                break
            }
        } else {
            Write-Host $scope.Name "already exists. Scope won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually scope's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No scopes to import" -ForegroundColor Yellow
}

Write-Host "Setting Administrators config... "
if($xdoc.site.administrators){
    $administrators = $xdoc.site.administrators.administrator
    foreach($administrator in $administrators){
        if(!(get-adminadministrator -Name $administrator.name -errorAction SilentlyContinue)){
            Write-host "Adding new admin" $administrator.Name"... " -NoNewline
            try {
                New-AdminAdministrator -Name $administrator.Name | Out-Null
                Write-Host "OK" -ForegroundColor Green
                Write-host "Setting permissions to" $administrator.name"... " -NoNewline
                try {
                    Add-AdminRight -Role $administrator.rolename -Scope $administrator.scopeName -Administrator $administrator.name
                    Write-host "OK" -ForegroundColor Green
                }
                catch {
                    Write-Host "An error occured while setting permissions for" $administrator.name -ForegroundColor Red                        
                    Stop-Transcript
                    break
                }
            }
            catch {
                Write-Host "An error occured while adding a new administrator" -ForegroundColor Red
                Stop-Transcript
                break
            }
        } else {
            Write-Host $administrator.Name "already exists. Administrator won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually administrator's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No administrators to import" -ForegroundColor Yellow
}

################################################################################################
#Setting AcctIdentityPool
################################################################################################

Write-Host "Setting AcctIdentityPool config... "
if($xdoc.site.AcctIdentityPools){
    $AcctIdentityPools = $xdoc.site.AcctIdentityPools.AcctIdentityPool
    foreach($AcctIdentityPool in $AcctIdentityPools){
        if(!(get-AcctIdentityPool -IdentityPoolName $AcctIdentityPool.IdentityPoolName -errorAction SilentlyContinue)){
            Write-host "Adding new AcctIdentityPool" $AcctIdentityPool.IdentityPoolName"... " -NoNewline
            $Command = "New-AcctIdentityPool -IdentityPoolName """ + $AcctIdentityPool.IdentityPoolName + """"
            $command += " -NamingScheme """ + $AcctIdentityPool.NamingScheme  + """"
            $command += " -NamingSchemeType """ + $AcctIdentityPool.NamingSchemeType + """"
            $command += " -OU """+ $AcctIdentityPool.OU + """"
            $command += " -Domain """+ $AcctIdentityPool.Domain + """"
            try {
                $count = $AcctIdentityPool.scope.count
                $i=0
                $command += " -Scope """
                while ($i -lt $count) {
                    $command += $AcctIdentityPool.scope[$i]
                    if($i -ne ($count - 1)){
                        $command += ""","""
                    } else {
                        $command += """"
                    }
                    $i++
                }
            }
            catch {
                try { #Only one scope is declared
                    $command += " -Scope """ + $provscheme.scope + """"
                }
                catch {
                    #No Scope to assign
                }
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new IdentityPoolName" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $AcctIdentityPool.IdentityPoolName "already exists. IdentityPoolName won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually IdentityPoolName's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No AcctIdentityPools to import" -ForegroundColor Yellow
}

################################################################################################
#Setting ProvSchemes
################################################################################################

Write-Host "Setting ProvSchemes config... "
if($xdoc.site.provschemes){
    $provschemes = $xdoc.site.provschemes.provscheme
    foreach($provscheme in $provschemes){
        if(!(get-ProvScheme -ProvisioningSchemeName $provscheme.ProvisioningSchemeName -errorAction SilentlyContinue)){
            Write-host "Adding new ProvScheme" $provscheme.ProvisioningSchemeName"... " -NoNewline
            $command = "New-ProvScheme -ProvisioningSchemeName """ + $provscheme.ProvisioningSchemeName + """"
            $command += " -HostingUnitName """ + $provscheme.HostingUnitName + """"
            $command += " -IdentityPoolName """ + $provscheme.IdentityPoolName + """"
            if($provscheme.CleanOnBoot){
                $command += " -CleanOnBoot"
            }
            $command += " -MasterImageVM """ + $provscheme.MasterImageVM + """"
            $command += " -VMCpuCount """ +  $provscheme.CpuCount + """"
            $command += " -VMMemoryMB """ + $provscheme.MemoryMB + """"
            if($provscheme.UsePersonalVDiskStorage -match "True"){ #it is not a boolean but a string
                $command += " -UsePersonalVDiskStorage"
                #Require PersonalVDiskDriveLetter parameter
            }
            if($ProvScheme.UseWriteBackCache -match "True"){ #it is not a boolean but a string
                $command += " -UseWriteBackCache"
                $command += " -WriteBackCacheDiskSize """ + $provscheme.WriteBackCacheDiskSize + """"
                $command += " -WriteBackCacheMemorySize """ + $provscheme.WriteBackCacheMemorySize + """"
            }
            try {
                $count = $provscheme.scope.count
                $i=0
                $command += " -Scope """
                while ($i -lt $count) {
                    $command += $provscheme.scope[$i]
                    if($i -ne ($count - 1)){
                        $command += ""","""
                    } else {
                        $command += """"
                    }
                    $i++
                }
            }
            catch {
                try { #Only one scope is declared
                    $command += " -Scope """ + $provscheme.scope + """"
                }
                catch {
                    #No Scope to assign
                }
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new ProvSchemes" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $provscheme.ProvisioningSchemeName "already exists. ProvScheme won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually ProvScheme's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No ProvSchemes to import" -ForegroundColor Yellow
}

################################################################################################
#Setting Catalogs
################################################################################################

Write-Host "Setting Catalogs config... "
if($xdoc.site.Catalogs){
    $Catalogs = $xdoc.site.Catalogs.Catalog
    foreach($Catalog in $Catalogs){
        if(!(Get-BrokerCatalog -Name $Catalog.Name -errorAction SilentlyContinue)){
            Write-host "Adding new Catalog" $Catalog.Name"... " -NoNewline
            $command = "New-BrokerCatalog -Name """ + $Catalog.Name + """"
            $command += " -AllocationType """ + $Catalog.AllocationType + """"
            $command += " -Description """ + $Catalog.Description + """"
            $command += " -ProvisioningType """ + $Catalog.ProvisioningType + """"
            $command += " -SessionSupport """ + $Catalog.SessionSupport + """"
            $command += " -PersistUserChanges """ + $Catalog.PersistUserChanges + """"
            if($Catalog.IsRemotePC -match "True"){
                $command += " -IsRemotePC `$True"
            }
            if($Catalog.IsRemotePC -match "False"){
                $command += " -IsRemotePC `$False"
            }
            if($Catalog.MachinesArePhysical -match "True"){
                $command += " -MachinesArePhysical `$True"
            }
            if($Catalog.MachinesArePhysical -match "False"){
                $command += " -MachinesArePhysical `$False"
            }
            if($Catalog.ProvisioningSchemeName){
                $ProvisioningSchemeUid = (Get-ProvScheme -ProvisioningSchemeName $Catalog.ProvisioningSchemeName).ProvisioningSchemeUid
                $command += " -ProvisioningSchemeId """ + $ProvisioningSchemeUid + """"
            }
            try {
                $count = $Catalog.scope.count
                $i=0
                $command += " -Scope """
                while ($i -lt $count) {
                    $command += $Catalog.scope[$i]
                    if($i -ne ($count - 1)){
                        $command += ""","""
                    } else {
                        $command += """"
                    }
                    $i++
                }
            }
            catch {
                try { #Only one scope is declared
                    $command += " -Scope """ + $Catalog.scope + """"
                }
                catch {
                    #No Scope to assign
                }
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new Catalog" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $Catalog.Name "already exists. Catalog won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually Catalog's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No Catalogs to import" -ForegroundColor Yellow
}

################################################################################################
#Setting DesktopGroups
################################################################################################

Write-Host "Setting DesktopGroups config... "
if($xdoc.site.DeliveryGroups){
    $DesktopGroups = $xdoc.site.DeliveryGroups.DeliveryGroup
    foreach($DesktopGroup in $DesktopGroups){
        if(!(Get-BrokerDesktopGroup -Name $DesktopGroup.Name -errorAction SilentlyContinue)){
            Write-host "Adding new DesktopGroup" $DesktopGroup.Name"... " -NoNewline
            $command = "New-BrokerDesktopGroup -Name """ + $DesktopGroup.Name + """"
            $command += " -PublishedName """ + $DesktopGroup.PublishedName + """"
            $command += " -Description """ + $DesktopGroup.Description + """"
            $command += " -DesktopKind """ + $DesktopGroup.DesktopKind + """"
            $command += " -SessionSupport """ + $DesktopGroup.SessionSupport + """"
            if($DesktopGroup.ShutdownDesktopsAfterUse -match "True"){
                $command += " -ShutdownDesktopsAfterUse `$True"
            }
            if($DesktopGroup.ShutdownDesktopsAfterUse -match "False"){
                $command += " -ShutdownDesktopsAfterUse `$False"
            }
            if($DesktopGroup.AutomaticPowerOnForAssigned -match "True"){
                $command += " -AutomaticPowerOnForAssigned `$True"
            }
            if($DesktopGroup.AutomaticPowerOnForAssigned -match "False"){
                $command += " -AutomaticPowerOnForAssigned `$False"
            }
            if($DesktopGroup.AutomaticPowerOnForAssignedDuringPeak -match "True"){
                $command += " -AutomaticPowerOnForAssignedDuringPeak `$True"
            }
            if($DesktopGroup.AutomaticPowerOnForAssignedDuringPeak -match "False"){
                $command += " -AutomaticPowerOnForAssignedDuringPeak `$False"
            }
            $command += " -DeliveryType """ + $DesktopGroup.DeliveryType + """"
            if($DesktopGroup.Enabled -match "True"){
                $command += " -Enabled `$True"
            }
            if($DesktopGroup.Enabled -match "False"){
                $command += " -Enabled `$False"
            }
            $iconUid = $DesktopGroup.IconUid
            if(test-path -Path "./resources/$iconuid.txt"){
                $encodedData = Get-Content -Path "./resources/$iconuid.txt"
                $brokericon = New-BrokerIcon -EncodedIconData $encodedData
                $command += " -IconUid """ + $brokericon.Uid + """"
            }
            if($DesktopGroup.IsRemotePC -match "True"){
                $command += " -IsRemotePC `$True"
            }
            if($DesktopGroup.IsRemotePC -match "False"){
                $command += " -IsRemotePC `$False"
            }
            $command += " -OffPeakBufferSizePercent """ + $DesktopGroup.OffPeakBufferSizePercent + """"
            $command += " -OffPeakDisconnectAction """ + $DesktopGroup.OffPeakDisconnectAction + """"
            $command += " -OffPeakDisconnectTimeout """ + $DesktopGroup.OffPeakDisconnectTimeout + """"
            $command += " -OffPeakExtendedDisconnectAction	 """ + $DesktopGroup.OffPeakExtendedDisconnectAction	 + """"
            $command += " -OffPeakExtendedDisconnectTimeout	 """ + $DesktopGroup.OffPeakExtendedDisconnectTimeout	 + """"
            $command += " -OffPeakLogOffAction	 """ + $DesktopGroup.OffPeakLogOffAction	 + """"
            $command += " -OffPeakLogOffTimeout	 """ + $DesktopGroup.OffPeakLogOffTimeout	 + """"
            $command += " -PeakBufferSizePercent	 """ + $DesktopGroup.PeakBufferSizePercent	 + """"
            $command += " -PeakDisconnectAction	 """ + $DesktopGroup.PeakDisconnectAction	 + """"
            $command += " -PeakDisconnectTimeout	 """ + $DesktopGroup.PeakDisconnectTimeout	 + """"
            $command += " -PeakExtendedDisconnectAction	 """ + $DesktopGroup.PeakExtendedDisconnectAction	 + """"
            $command += " -PeakExtendedDisconnectTimeout	 """ + $DesktopGroup.PeakExtendedDisconnectTimeout	 + """"
            $command += " -PeakLogOffAction	 """ + $DesktopGroup.PeakLogOffAction	 + """"
            $command += " -PeakLogOffTimeout	 """ + $DesktopGroup.PeakLogOffTimeout	 + """"
            try {
                $count = $DesktopGroup.scope.count
                $i=0
                $command += " -Scope """
                while ($i -lt $count) {
                    $command += $DesktopGroup.scope[$i]
                    if($i -ne ($count - 1)){
                        $command += ""","""
                    } else {
                        $command += """"
                    }
                    $i++
                }
            }
            catch {
                try { #Only one scope is declared
                    $command += " -Scope """ + $DesktopGroup.scope + """"
                }
                catch {
                    #No Scope to assign
                }
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new DesktopGroup" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $DesktopGroup.Name "already exists. DesktopGroup won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually DesktopGroup's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No DesktopGroups to import" -ForegroundColor Yellow
}

################################################################################################
#Setting EntitlementPolicyRules
################################################################################################

Write-Host "Setting EntitlementPolicyRules config... "
if($xdoc.site.EntitlementPolicyRules){
    $EntitlementPolicyRules = $xdoc.site.EntitlementPolicyRules.EntitlementPolicyRule
    foreach($EntitlementPolicyRule in $EntitlementPolicyRules){
        if(!(Get-BrokerEntitlementPolicyRule -Name $EntitlementPolicyRule.Name -errorAction SilentlyContinue)){
            Write-host "Adding new EntitlementPolicyRule" $EntitlementPolicyRule.Name"... " -NoNewline
            $command = "New-BrokerEntitlementPolicyRule -Name """ + $EntitlementPolicyRule.Name + """"
            $DesktopGroupUid = (Get-BrokerDesktopGroup -Name $EntitlementPolicyRule.DesktopGroupName).Uid
            $command += " -DesktopGroupUid """ + $DesktopGroupUid + """"
            $command += " -Description """ + $EntitlementPolicyRule.Description + """"
            $command += " -PublishedName """ + $EntitlementPolicyRule.PublishedName + """"
            if($EntitlementPolicyRule.ExcludedUserFilterEnabled -match "True"){
                $command += " -ExcludedUserFilterEnabled `$True"
                try {
                    $count = $EntitlementPolicyRule.ExcludedUser.count
                    $i=0
                    $command += " -ExcludedUsers """
                    while ($i -lt $count) {
                        $command += $EntitlementPolicyRule.ExcludedUser[$i]
                        if($i -ne ($count - 1)){
                            $command += ""","""
                        } else {
                            $command += """"
                        }
                        $i++
                    }
                }
                catch {
                    try { #Only one ExcludedUsers is declared
                        $command += " -ExcludedUsers """ + $EntitlementPolicyRule.ExcludedUser + """"
                    }
                    catch {
                        #No ExcludedUsers to assign
                    }
                }
            }
            if($EntitlementPolicyRule.ExcludedUserFilterEnabled -match "False"){
                $command += " -ExcludedUserFilterEnabled `$False"
            }
            if($EntitlementPolicyRule.IncludedUserFilterEnabled -match "True"){
                $command += " -IncludedUserFilterEnabled `$True"
                try {
                    $count = $EntitlementPolicyRule.IncludedUser.count
                    $i=0
                    $command += " -IncludedUsers """
                    while ($i -lt $count) {
                        $command += $EntitlementPolicyRule.IncludedUser[$i]
                        if($i -ne ($count - 1)){
                            $command += ""","""
                        } else {
                            $command += """"
                        }
                        $i++
                    }
                }
                catch {
                    try { #Only one IncludedUsers is declared
                        $command += " -IncludedUsers """ + $EntitlementPolicyRule.IncludedUser + """"
                    }
                    catch {
                        #No IncludedUsers to assign
                    }
                }
            }
            if($EntitlementPolicyRule.IncludedUserFilterEnabled -match "False"){
                $command += " -IncludedUserFilterEnabled `$False"
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new EntitlementPolicyRule" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $EntitlementPolicyRule.Name "already exists. EntitlementPolicyRule won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually EntitlementPolicyRule's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No EntitlementPolicyRules to import" -ForegroundColor Yellow
}

################################################################################################
#Setting BrokerAppEntitlementPolicyRules
################################################################################################

Write-Host "Setting BrokerAppEntitlementPolicyRules config... "
if($xdoc.site.BrokerAppEntitlementPolicyRules){
    $BrokerAppEntitlementPolicyRules = $xdoc.site.BrokerAppEntitlementPolicyRules.BrokerAppEntitlementPolicyRule
    foreach($BrokerAppEntitlementPolicyRule in $BrokerAppEntitlementPolicyRules){
        if(!(Get-BrokerAppEntitlementPolicyRule -Name $BrokerAppEntitlementPolicyRule.Name -errorAction SilentlyContinue)){
            Write-host "Adding new BrokerAppEntitlementPolicyRule" $BrokerAppEntitlementPolicyRule.Name"... " -NoNewline
            $command = "New-BrokerAppEntitlementPolicyRule -Name """ + $BrokerAppEntitlementPolicyRule.Name + """"
            $DesktopGroupUid = (Get-BrokerDesktopGroup -Name $BrokerAppEntitlementPolicyRule.DesktopGroupName).Uid
            $command += " -DesktopGroupUid """ + $DesktopGroupUid + """"
            $command += " -Description """ + $BrokerAppEntitlementPolicyRule.Description + """"
            if($BrokerAppEntitlementPolicyRule.Enabled -match "False"){
                $command += " -Enabled `$False"
            }
            if($BrokerAppEntitlementPolicyRule.Enabled -match "True"){
                $command += " -Enabled `$True"
            }
            if($BrokerAppEntitlementPolicyRule.LeasingBehavior -match "False"){
                $command += " -LeasingBehavior `$False"
            }
            if($BrokerAppEntitlementPolicyRule.LeasingBehavior -match "True"){
                $command += " -LeasingBehavior `$True"
            }
            if($BrokerAppEntitlementPolicyRule.SessionReconnection -match "False"){
                $command += " -SessionReconnection `$False"
            }
            if($BrokerAppEntitlementPolicyRule.SessionReconnection -match "True"){
                $command += " -SessionReconnection `$True"
            }
            if($BrokerAppEntitlementPolicyRule.ExcludedUserFilterEnable -match "False"){
                $command += " -ExcludedUserFilterEnable `$False"
            }
            if($BrokerAppEntitlementPolicyRule.ExcludedUserFilterEnable -match "True"){
                $command += " -ExcludedUserFilterEnable `$True"
            }
            if($BrokerAppEntitlementPolicyRule.IncludedUserFilterEnable -match "False"){
                $command += " -IncludedUserFilterEnable `$False"
            }
            if($BrokerAppEntitlementPolicyRule.IncludedUserFilterEnable -match "True"){
                $command += " -IncludedUserFilterEnable `$True"
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new BrokerAppEntitlementPolicyRule" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $BrokerAppEntitlementPolicyRule.Name "already exists. BrokerAppEntitlementPolicyRule won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually BrokerAppEntitlementPolicyRule's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No BrokerAppEntitlementPolicyRules to import" -ForegroundColor Yellow
}

################################################################################################
#Setting Brokerpowertimeschemes
################################################################################################

Write-Host "Setting Brokerpowertimeschemes config... "
if($xdoc.site.Brokerpowertimeschemes){
    $Brokerpowertimeschemes = $xdoc.site.Brokerpowertimeschemes.Brokerpowertimescheme
    foreach($Brokerpowertimescheme in $Brokerpowertimeschemes){
        if(!(Get-Brokerpowertimescheme -Name $Brokerpowertimescheme.Name -errorAction SilentlyContinue)){
            Write-host "Adding new Brokerpowertimescheme" $Brokerpowertimescheme.Name"... " -NoNewline
            $command = "New-Brokerpowertimescheme -Name """ + $Brokerpowertimescheme.Name + """"
            $DesktopGroupUid = (Get-BrokerDesktopGroup -Name $Brokerpowertimescheme.DesktopGroupName).Uid
            $command += " -DesktopGroupUid """ + $DesktopGroupUid + """"
            $command += " -DaysOfWeek """ + $Brokerpowertimescheme.DaysOfWeek + """"
            $command += " -DisplayName """ + $Brokerpowertimescheme.DisplayName + """"
            if($Brokerpowertimescheme.PoolUsingPercentage -match "True"){
                $command += " -PoolUsingPercentage `$True"
            }
            if($Brokerpowertimescheme.PoolUsingPercentage -match "False"){
                $command += " -PoolUsingPercentage `$False"
            }
            $count = $Brokerpowertimescheme.PeakHour.count
            $i=0
            $command += " -PeakHours @("
            while ($i -lt $count) {
                if($Brokerpowertimescheme.PeakHour[$i] -match "True"){
                    $command += "`$True"
                }
                if($Brokerpowertimescheme.PeakHour[$i] -match "False"){
                    $command += "`$False"
                }
                if($i -ne ($count - 1)){
                    $command += ","
                } else {
                    $command += ")"
                }
                $i++
            }
            $count = $Brokerpowertimescheme.PoolSize.count
            $i=0
            $command += " -PoolSize @("
            while ($i -lt $count) {
                $command += $Brokerpowertimescheme.PoolSize[$i]
                if($i -ne ($count - 1)){
                    $command += ","
                } else {
                    $command += ")"
                }
                $i++
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new Brokerpowertimescheme" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $Brokerpowertimescheme.Name "already exists. Brokerpowertimescheme won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually Brokerpowertimescheme's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No Brokerpowertimeschemes to import" -ForegroundColor Yellow
}

################################################################################################
#Setting BrokeraccesspolicyRules
################################################################################################

Write-Host "Setting BrokeraccesspolicyRules config... "
if($xdoc.site.BrokeraccesspolicyRules){
    $BrokeraccesspolicyRules = $xdoc.site.BrokeraccesspolicyRules.BrokeraccesspolicyRule
    foreach($BrokeraccesspolicyRule in $BrokeraccesspolicyRules){
        if(!(Get-BrokeraccesspolicyRule -Name $BrokeraccesspolicyRule.Name -errorAction SilentlyContinue)){
            Write-host "Adding new BrokeraccesspolicyRule" $BrokeraccesspolicyRule.Name"... " -NoNewline
            $command = "New-BrokeraccesspolicyRule -Name """ + $BrokeraccesspolicyRule.Name + """"
            $DesktopGroupUid = (Get-BrokerDesktopGroup -Name $BrokeraccesspolicyRule.DesktopGroupName).Uid
            $command += " -DesktopGroupUid """ + $DesktopGroupUid + """"
            $command += " -AllowedConnections """ + $BrokeraccesspolicyRule.AllowedConnections + """"
            $command += " -AllowedProtocols @(""" + $BrokeraccesspolicyRule.AllowedProtocols.Replace(" ",""",""") + """)"
            $command += " -AllowedUsers """ + $BrokeraccesspolicyRule.AllowedUsers + """"
            $command += " -Description """ + $BrokeraccesspolicyRule.Description + """"
            if($BrokeraccesspolicyRule.AllowRestart -match "True"){
                $command += " -AllowRestart `$True"
            }
            if($BrokeraccesspolicyRule.AllowRestart -match "False"){
                $command += " -AllowRestart `$False"
            }
            if($BrokeraccesspolicyRule.IncludedSmartAccessFilterEnabled -match "True"){
                $command += " -IncludedSmartAccessFilterEnabled `$True"
            }
            if($BrokeraccesspolicyRule.IncludedSmartAccessFilterEnabled -match "False"){
                $command += " -IncludedSmartAccessFilterEnabled `$False"
            }
            if($BrokeraccesspolicyRule.Enabled -match "True"){
                $command += " -Enabled `$True"
            }
            if($BrokeraccesspolicyRule.Enabled -match "False"){
                $command += " -Enabled `$False"
            }
            if($BrokeraccesspolicyRule.IncludedUserFilterEnabled -match "True"){
                $command += " -IncludedUserFilterEnabled `$True"
            }
            if($BrokeraccesspolicyRule.IncludedUserFilterEnabled -match "False"){
                $command += " -IncludedUserFilterEnabled `$False"
            }
            try {
                $count = $BrokeraccesspolicyRule.IncludedUser.count
                $i=0
                $command += " -IncludedUsers """
                while ($i -lt $count) {
                    $command += $BrokeraccesspolicyRule.IncludedUser[$i]
                    if($i -ne ($count - 1)){
                        $command += ""","""
                    } else {
                        $command += """"
                    }
                    $i++
                }
            }
            catch {
                try { #Only one IncludedUsers is declared
                    $command += " -IncludedUsers """ + $BrokeraccesspolicyRule.IncludedUser + """"
                }
                catch {
                    #No IncludedUsers to assign
                }
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new BrokeraccesspolicyRule" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $BrokeraccesspolicyRule.Name "already exists. BrokeraccesspolicyRule won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually BrokeraccesspolicyRule's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No BrokeraccesspolicyRules to import" -ForegroundColor Yellow
}

################################################################################################
#Setting Brokerrebootschedules
################################################################################################

Write-Host "Setting Brokerrebootschedules config... "
if($xdoc.site.Brokerrebootschedules){
    $Brokerrebootschedules = $xdoc.site.Brokerrebootschedules.Brokerrebootschedule
    foreach($Brokerrebootschedule in $Brokerrebootschedules){
        if(!(Get-BrokerrebootscheduleV2 -Name $Brokerrebootschedule.Name -errorAction SilentlyContinue)){
            Write-host "Adding new Brokerrebootschedule" $Brokerrebootschedule.Name"... " -NoNewline
            $command = "New-BrokerrebootscheduleV2 -Name """ + $Brokerrebootschedule.Name + """"
            $DesktopGroupUid = (Get-BrokerDesktopGroup -Name $Brokerrebootschedule.DesktopGroupName).Uid
            $command += " -DesktopGroupUid """ + $DesktopGroupUid + """"
            $command += " -RebootDuration """ + $Brokerrebootschedule.RebootDuration + """"
            $command += " -Description """ + $Brokerrebootschedule.Description + """"
            $command += " -Frequency """ + $Brokerrebootschedule.Frequency + """"
            if($Brokerrebootschedule.Frequency -notmatch "Daily"){
                $command += " -Day """ + $Brokerrebootschedule.Day + """"
            }
            $command += " -StartTime """ + $Brokerrebootschedule.StartTime + """"
            $command += " -WarningDuration """ + $Brokerrebootschedule.WarningDuration + """"
            $command += " -WarningMessage """ + $Brokerrebootschedule.WarningMessage + """"
            $command += " -WarningRepeatInterval """ + $Brokerrebootschedule.WarningRepeatInterval + """"
            $command += " -WarningTitle """ + $Brokerrebootschedule.WarningTitle + """"
            if($Brokerrebootschedule.Enabled -match "True"){
                $command += " -Enabled `$True"
            }
            if($Brokerrebootschedule.Enabled -match "False"){
                $command += " -Enabled `$False"
            }
            #write-host $command
            #Pause
            try {
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new Brokerrebootschedule" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $Brokerrebootschedule.Name "already exists. Brokerrebootschedule won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually Brokerrebootschedule's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No Brokerrebootschedules to import" -ForegroundColor Yellow
}

################################################################################################
#Setting PublishedApps
################################################################################################

Write-Host "Setting PublishedApps config... "
if($xdoc.site.PublishedApps){
    $PublishedApps = $xdoc.site.PublishedApps.PublishedApp
    foreach($PublishedApp in $PublishedApps){
        if(!(Get-Brokerapplication -Name $PublishedApp.Name -errorAction SilentlyContinue)){
            Write-host "Adding new PublishedApp" $PublishedApp.Name"... " -NoNewline
            $command = "New-Brokerapplication -Name """ + $PublishedApp.PublishedName + """"
            $command += " -CommandLineExecutable """ + $PublishedApp.CommandLineExecutable + """"
            $j=0
            try {
                $countj = $PublishedApp.AssociatedDesktopGroupName.count
                $command += " -DesktopGroup """ + $PublishedApp.AssociatedDesktopGroupName[$j] + """"
                $j++
            }
            catch {
                $command += " -DesktopGroup """ + $PublishedApp.AssociatedDesktopGroupName + """"
            }
            if(!(Get-BrokerAdminFolder -Name $PublishedApp.AdminFolderName -errorAction SilentlyContinue)){
                New-BrokerAdminFolder -FolderName $PublishedApp.AdminFolderName.Replace("\","") | Out-Null
            }
            $command += " -AdminFolder """ + $PublishedApp.AdminFolderName + """"
            $command += " -ApplicationType """ + $PublishedApp.ApplicationType + """"
            if($PublishedApp.CommandLineArguments -match "%" -and $PublishedApp.CommandLineArguments -notlike "%*"){
                $command += " -CommandLineArguments """ + "```"%*``"""""
            } else {
                if($PublishedApp.CommandLineArguments -match "%" -and $PublishedApp.CommandLineArguments -notlike "%*"){
                    $command += " -CommandLineArguments " + $PublishedApp.CommandLineArguments + ""
                } else {
                    $command += " -CommandLineArguments """ + $PublishedApp.CommandLineArguments.Replace("`"","```"") + """"
                }
            }
            $command += " -Description """ + $PublishedApp.Description + """"
            if($PublishedApp.Enabled -match "True"){
                $command += " -Enabled `$True"
            }
            if($PublishedApp.Enabled -match "False"){
                $command += " -Enabled `$False"
            }
            $IconPath = "./resources/" + $PublishedApp.iconuid + ".txt"
            $EncodedData = Get-Content $IconPath
            $Icon = New-BrokerIcon -EncodedIconData $EncodedData
            $command += " -IconUid """ + $Icon.Uid + """"
            $command += " -MaxPerUserInstances """ + $PublishedApp.MaxPerUserInstances + """"
            $command += " -MaxTotalInstances """ + $PublishedApp.MaxTotalInstances + """"
            $command += " -PublishedName """ + $PublishedApp.PublishedName + """"
            if($PublishedApp.ShortcutAddedToDesktop -match "True"){
                $command += " -ShortcutAddedToDesktop `$True"
            }
            if($PublishedApp.ShortcutAddedToDesktop -match "False"){
                $command += " -ShortcutAddedToDesktop `$False"
            }
            if($PublishedApp.ShortcutAddedToStartMenu -match "True"){
                $command += " -ShortcutAddedToStartMenu `$True"
            }
            if($PublishedApp.ShortcutAddedToStartMenu -match "False"){
                $command += " -ShortcutAddedToStartMenu `$False"
            }
            $command += " -StartMenuFolder """ + $PublishedApp.StartMenuFolder + """"
            if($PublishedApp.UserFilterEnabled -match "True"){
                $command += " -UserFilterEnabled `$True"
            }
            if($PublishedApp.UserFilterEnabled -match "False"){
                $command += " -UserFilterEnabled `$False"
            }
            if($PublishedApp.Visible -match "True"){
                $command += " -Visible `$True"
            }
            if($PublishedApp.Visible -match "False"){
                $command += " -Visible `$False"
            }
            $command += " -WorkingDirectory """ + $PublishedApp.WorkingDirectory + """"
            #write-host $command
            #Pause
            try {
                $App = Invoke-Expression $command
                try {
                    $count = $PublishedApp.AssociatedUserFullName.count
                    $i=0
                    while ($i -lt $count) {
                        $AssociatedUserFullName = "$env:USERDOMAIN\" + $PublishedApp.AssociatedUserFullName[$i]
                        Add-BrokerUser -Name $AssociatedUserFullName -Application $App
                        $i++
                    }
                }
                catch {
                    try{
                        $AssociatedUserFullName = "$env:USERDOMAIN\" + $PublishedApp.AssociatedUserFullName
                        Add-BrokerUser -Name $AssociatedUserFullName -Application $App
                    }
                    catch {
                        #No User to assign to
                    }
                }
                if($j -ne 0){
                    while($j -lt $countj){
                        Add-BrokerApplication $App -DesktopGroup $PublishedApp.AssociatedDesktopGroupName[$j]
                        $j++
                    }
                }
            }
            catch {
                Write-Host "An error occured while adding a new PublishedApp" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $PublishedApp.Name "already exists. PublishedApp won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually PublishedApp's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No PublishedApps to import" -ForegroundColor Yellow
}

################################################################################################
#Setting FileTypeAssociations
################################################################################################

Write-Host "Setting FileTypeAssociations config... "a
if($xdoc.site.FileTypeAssociations){
    $FileTypeAssociations = $xdoc.site.FileTypeAssociations.FileTypeAssociation
    foreach($FileTypeAssociation in $FileTypeAssociations){
        $AppUid = (Get-BrokerApplication -PublishedName $FileTypeAssociation.Application).Uid
        if(!(Get-BrokerConfiguredFTA -ApplicationUid $AppUid -ContentType $FileTypeAssociation.ContentType -ExtensionName $FileTypeAssociation.ExtensionName -errorAction SilentlyContinue)){
            Write-host "Adding new FTA for" $FileTypeAssociation.Application" and" $FileTypeAssociation.ExtensionName"... " -NoNewline
            $command = "New-Brokerconfiguredfta -ApplicationUid """ + $AppUid + """"
            $command += " -ExtensionName """ + $FileTypeAssociation.ExtensionName + """"
            $command += " -HandlerName """ + $FileTypeAssociation.HandlerName + """"
            $command += " -ContentType """ + $FileTypeAssociation.ContentType + """"
            #Write-host $command
            #pause
            try{
                Invoke-Expression $command | Out-Null
            }
            catch {
                Write-Host "An error occured while adding a new FileTypeAssociation" -ForegroundColor Red
                Stop-Transcript
                break
            }
            Write-Host "OK" -ForegroundColor Green
        } else {
            Write-Host $FileTypeAssociation.Name "already exists. FileTypeAssociation won't be modified by this script." -ForegroundColor Yellow
            Write-Host "Check manually FileTypeAssociation's properties." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "No FileTypeAssociations to import" -ForegroundColor Yellow
}

#TODO Delivering status once machines added?
#TODO Assign RemotePC

Stop-Transcript
break