#Requires -Version 3.0
<#
*********************************************************************************************************************************
Name:               Migrate-CVADapps
Author:             Kasper Johansen
Last modified by:   Kasper Johansen
Last modified Date: 12-01-2020
Version             2.0

.SYNOPSIS
    Migrates published apps between Virtual Apps and Desktops sites.

.DESCRIPTION
    This script migrates all published apps between Virtual Apps and Desktops sites.

    This script has been developed with inspiration from the XD7Export and XD7Import scripts from Peter Juncker at Atea Denmark.
    Credit goes out to Peter Juncker for the initial scripts.

    The script can export published applications from a Citrix XenApp and XeneDesktop and Citrix Virtual Apps and Desktops site.
    The script can import published applications to a Citrix XenApp and XeneDesktop and Citrix Virtual Apps and Desktops site.

    The script has been testet with:
    Citrix XenApp and XenDesktop 7.6 LTSR CU6
    Citrix XenApp and XenDesktop 7.9 
    Citrix Virtual Apps and Desktops 1808
    Citrix Virtual Apps and Desktops 1909

    The most common information (icon information, user/group access information, commandline, commandline arguments and workdir)
    is exported to 3 different CSV files.

    The names of the CSV files are hardcoded, but the path to the CSV files is customizable.
    The specific CSV produced when exporting are:

    Icons.csv:
    Contains the binary icon information for all published applications. This file may grow large in size
    depending on the amount of published applications.

    Apps.csv:
    Contains all published applications property information. This is a 1 to 1 extraction with no filtering.

    Users:
    Contains the published applications UID and any Active Direcoty User/Group information.

    All 3 CSV files are needed for a successfull import!

    .PARAMETER DesktopGroupName
    The name of the Delivery Group to import/export published applications. 
    If the Delivery Group name contains spaces if must be encased in double quotes!

    .PARAMETER CSVInput
    Specifies the path the CSV files. If not specified, the default path, 
    which is the directory from where the script is executed, is selected. 
    This parameter is only active when using the -Import switch.

    .PARAMETER CSVOutput
    Specifies the path the CSV files. If not specified, the default path, 
    which is the directory from where the script is executed, is selected. 
    This parameter is only active when using the -Export switch.

    .SWITCH Import
    Enables the import of published applications to a Citrix Virtual Apps and Desktop Site

    .SWITCH Export
    Enables the Export of published applications from a Citrix Virtual Apps and Desktop Site

    .PARAMETER LogDir
    Specifies the directory to store the transcription logfile. If not specified, the default 
    $env:SystemRoot\Temp directory is selected.
    
.EXAMPLES
    Export published applications:

        Citrix-MigrateApps.ps1 -DesktopGroupName "XenApp" -Export

    Export published applications with custom CSV output path:

        Citrix-MigrateApps.ps1 -DesktopGroupName "XenApp" -CSVOutput C:\CSVOutput -Export

    Import published applications:

        Citrix-MigrateApps.ps1 -DesktopGroupName "XenApp" -Import

    Import published applications with custom CSV input path:

        Citrix-MigrateApps.ps1 -DesktopGroupName "XenApp" -CSVInput C:\CSVInput -Import

*********************************************************************************************************************************
#>

# Function parameters
Param(
    [Parameter(Mandatory = $true)]
    [string]$DesktopGroupName,
    [Parameter(ParameterSetName = "Import")]
    [string]$CSVInput = (Split-Path -parent $MyInvocation.MyCommand.Definition),
    [Parameter(ParameterSetName = "Export")]
    [string]$CSVOutput = (Split-Path -parent $MyInvocation.MyCommand.Definition),
    [Parameter(ParameterSetName = "Import", Mandatory)]
    [switch]$Import,
    [Parameter(ParameterSetName = "Export", Mandatory)]
    [switch]$Export,
    [string]$LogDir = (Split-Path -parent $MyInvocation.MyCommand.Definition)
    )

# Add Citrix Broker Admin PowerShell snap-in
Write-Host "Adding Citrix Broker Admin PowerShell snap-in" -Verbose
Add-PSSnapin -Name Citrix.Broker.Admin.V2 -ErrorAction Stop

function Export-XAapps
    {
    param(
         $DesktopGroupName,
         $CSVOutput,
         $LogDir
        )

    # Start time measuring and transcription
    $LogPS = $LogDir + "\Export-CVADApps.log"
    $startDTM = (Get-Date)
    Start-Transcript $LogPS

        # CSV path variables
        $IconsCSV = $CSVOutput + "\Icons.csv"
        $AppsCSV = $CSVOutput + "\Apps.csv"
        $UsersCSV = $CSVOutput + "\Users.csv"

        # Get DesktopGroup
        $DesktopGroup = Get-BrokerDesktopGroup -Name $DesktopGroupName
                
            If (!($DesktopGroup))
            {
                Write-Host "$DesktopGroup does not exist" -Verbose
                break
            }
            else
            {
                # Export published apps icon information
                Write-Host "Exporting published apps icon information" -Verbose
                If (Test-Path -Path $IconsCSV)
                {
                    Remove-Item -Path $IconsCSV
                }
                Get-BrokerIcon | Export-Csv $IconsCSV -Encoding "UTF8" -Verbose
                
                    # Export published apps 
                    Write-Host "Exporting published apps" -Verbose
                    If (Test-Path -Path $AppsCSV)
                    {
                        Remove-Item -Path $AppsCSV
                    }
                    Get-BrokerApplication -AssociatedDesktopGroupUID $DesktopGroup.UID | Export-Csv $AppsCSV -Encoding "UTF8" -NoTypeInformation -Verbose

                        # Export published apps groups/users
                        Write-Host "Exporting published apps groups/users access information" -Verbose
                        If (Test-Path -Path $UsersCSV)
                        {
                            Remove-Item -Path $UsersCSV
                        }
                        
                        $PublishedApps = Get-BrokerApplication -AssociatedDesktopGroupUID $DesktopGroup.UID
                        Add-Content $UsersCSV "UID,Username" -Encoding "UTF8" -Verbose
                        ForEach ($App in $PublishedApps)
                        {
                            
                            If ($App.AssociatedUserNames -gt "1")
                            {
                                $UserName = $App.AssociatedUserNames
                                ForEach ($user in $UserName)
                                {
                                    $UID = $App.UID
                                    $AppGroupUIDs = $App.AssociatedDesktopGroupUids
                                    $UserName = $user

                                    Add-Content -Path $UsersCSV "$UID,$UserName" -Encoding "UTF8"
                                }
                            }
                            else
                            {
                                $UID = $App.UID
                                $AppGroupUIDs = $App.AssociatedDesktopGroupUids
                                $UserName = $App.AssociatedUserNames
                                                        
                                Add-Content -Path $UsersCSV "$UID,$UserName" -Encoding "UTF8"
                            }
                        }
            }
                
    # End time measuring and transcription
    $EndDTM = (Get-Date)
    Write-Output "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
    Stop-Transcript
    }

function Import-XAapps
    {
    param(
        $DesktopGroupName,
        $CSVInput,
        $LogDir
        )
    # Start time measuring and transcription
    $LogPS = $LogDir + "\Import-CVADApps.log"
    $startDTM = (Get-Date)
    Start-Transcript $LogPS

        # CSV path variables
        $IconsCSV = $CSVInput + "\Icons.csv"
        $AppsCSV = $CSVInput + "\Apps.csv"
        $UsersCSV = $CSVInput + "\Users.csv"

        # Get DesktopGroup
        $DesktopGroup = Get-BrokerDesktopGroup -Name $DesktopGroupName
                
            If (!($DesktopGroup))
            {
                Write-Host "$DesktopGroup does not exist" -Verbose
                break
            }
            else
            {
                # Import published apps icon information
                Import-Csv -path $AppsCSV|ForEach-Object {
                    
                    $AppApplicationName = $_.ApplicationName
	                $AppApplicationType=$_.ApplicationType
	                $AppBrowserName=$_.BrowserName
	                $AppClientFolder=$_.ClientFolder
	                $AppCommandLineArguments=$_.CommandLineArguments
	                $AppCommandLineExecutable=$_.CommandLineExecutable
	                $AppCpuPriorityLevel=$_.CpuPriorityLevel
	                $AppDescription=$_.Description
	                $AppEnabled=$_.Enabled -as [bool]
	                $AppIconFromClient=$_.IconFromClient -as [bool]
	                $AppIconUid=$_.IconUid
                    $AppAdminFolder=$_.AdminFolderName
	                $AppName=$_.Name
	                $AppPublishedName=$_.PublishedName
	                $AppSecureCmdLineArgumentsEnabled=$_.SecureCmdLineArgumentsEnabled -as [bool]
	                $AppShortcutAddedToDesktop=$_.ShortcutAddedToDesktop -as [bool]
	                $AppShortcutAddedToStartMenu=$_.ShortcutAddedToStartMenu -as [bool]
	                $AppStartMenuFolder=$_.StartMenuFolder
	                $AppUUID=$_.UUID
	                $AppUid=$_.Uid
	                $AppUserFilterEnabled=$_.UserFilterEnabled
	                $AppVisible=$_.Visible -as [bool]
	                $AppWaitForPrinterCreation=$_.WaitForPrinterCreation -as [bool]
	                $AppWorkingDirectory=$_.WorkingDirectory
                
                    # Import icon information
                    $IconData = Import-Csv $IconsCSV | Where-Object {$_.UID -eq $AppIconUid}
                    
                    # Import user/group access information
                    $UserAccess = import-csv -path $UsersCSV | Where-Object {$_.UID -eq $AppUid}

                    # Create icons
                    $IconID = New-BrokerIcon -EncodedIconData $IconData.EncodedIconData

                        If (Get-BrokerApplication | Where { $_.Name -eq $AppApplicationName })
                        {
                            Write-Host "$AppApplicationName already exists!" -Verbose
                            Write-Host
                        }
                        else
                        {
                            Write-Host "Importing $AppApplicationName" -Verbose
                            Write-Host "Importing icon for $AppApplicationName" -Verbose

                            New-BrokerApplication -Name $AppApplicationName -ApplicationType $AppApplicationType -AdminFolder $AppAdminFolder -ClientFolder $AppClientFolder -CommandLineArguments $AppCommandLineArguments -CommandLineExecutable $AppCommandLineExecutable -CpuPriorityLevel $AppCpuPriorityLevel -Description $AppDescription -DesktopGroup $DesktopGroup -Enabled $AppEnabled -IconUid $IconID.UID -Priority 0 -PublishedName $AppPublishedName -SecureCmdLineArgumentsEnabled $AppSecureCmdLineArgumentsEnabled -StartMenuFolder $AppStartMenuFolder -ShortcutAddedToDesktop $AppShortcutAddedToDesktop -ShortcutAddedToStartMenu $AppShortcutAddedToStartMenu -UserFilterEnabled $False -Visible $AppVisible -WaitForPrinterCreation $AppWaitForPrinterCreation -WorkingDirectory $AppWorkingDirectory -Verbose
                            
                            If ($AppUserFilterEnabled -eq "True")
                            {
                                Set-BrokerApplication -Name $AppApplicationName -UserFilterEnabled $True -Enable $False -Verbose
                                Add-BrokerApplication -Name $AppApplicationName -DesktopGroup $DesktopGroup -Verbose
                                                                    
                                    $UserAccess | ForEach-Object {
                                    Write-Host "Importing user/group access for $AppApplicationName" -Verbose
                                    Write-Host "Configuring AD Group/user:" $_.Username -Verbose
                                    Write-Host

                                        ForEach ($user in $_.Username)
                                        {
                                            Add-BrokerUser -Name $user -Application $AppApplicationName -Verbose -ErrorAction SilentlyContinue
                                        }
                                    }
                            }
                            else
                            {
                                Set-BrokerApplication -Name $AppApplicationName -UserFilterEnabled $False -Enable $False -Verbose
                                Add-BrokerApplication -Name $AppApplicationName -DesktopGroup $DesktopGroup -Verbose
                            }

                        }                
                }
                
            }
                
    # End time measuring and transcription
    $EndDTM = (Get-Date)
    Write-Output "Elapsed Time: $(($EndDTM-$StartDTM).TotalMinutes) Minutes" -Verbose
    Stop-Transcript
    }

function Migrate-CVADapps ($DesktopGroupName,$CSVInput,$CSVOutput,$LogDir,$Import,$Export)
    {
        If ($Export)
        {
            Export-XAapps -DesktopGroupName $DesktopGroupName -CSVOutput $CSVOutput -LogDir $LogDir
        }
            If ($Import)
            {
                Import-XAapps -DesktopGroupName $DesktopGroupName -CSVInput $CSVInput -LogDir $LogDir
            }
    }

Migrate-CVADapps $DesktopGroupName $CSVInput $CSVOutput $LogDir $Import $Export
