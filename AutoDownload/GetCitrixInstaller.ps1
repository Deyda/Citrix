<#
.SYNOPSIS
Download multiple VDA and ISO versions from Citrix.com
.DESCRIPTION
Download various Citrix components through a GUI without spending hours navigating through the various Citrix sub-sites.

.NOTES
  Version:          0.01.1
  Author:           Manuel Winkel <www.deyda.net>
  Creation Date:    2021-10-22

  // NOTE: Purpose/Change
  2020-06-20        Initial Version by Ryan Butler
  2021-10-22		Customization
  2021-12-22		Import of the download list into the script, no helper files needed anymore / Add Version Number and Version Check with Auto Update Function / Add Citrix 1912 CU4 and 2112 content

#>

$ProgressPreference = "SilentlyContinue"


$CSV = @"
"dlnumber","filename","name"
"19993","Citrix_Virtual_Apps_and_Desktops_7_1912_4000.iso","Citrix Virtual Apps and Desktops 7 1912 CU4 ISO"
"20115","Citrix_Virtual_Apps_and_Desktops_7_2112.iso","Citrix Virtual Apps and Desktops 7 2112 ISO"

"19994","VDAServerSetup_1912.exe","Multi-session OS Virtual Delivery Agent 1912 LTSR CU4"
"19995","VDAWorkstationSetup_1912.exe","Single-session OS Virtual Delivery Agent 1912 LTSR CU4"
"19996","VDAWorkstationCoreSetup_1912.exe","Single-session OS Core Services Virtual Delivery Agent 1912 LTSR CU4"

"20116","VDAServerSetup_2112.exe","Multi-session OS Virtual Delivery Agent 2112"
"20117","VDAWorkstationSetup_2112.exe","Single-session OS Virtual Delivery Agent 2112"
"20118","VDAWorkstationCoreSetup_2112.exe","Single-session OS Core Services Virtual Delivery Agent 2112"

"19997","ProfileMgmt_1912.zip","Profile Management 1912 LTSR CU4"
"19803","ProfileMgmt_2112.zip","Profile Management 2112"

"19999","Citrix_Provisioning_1912_19.iso","Citrix Provisioning 1912 CU4"
"20119","Citrix_Provisioning_2112.iso","Citrix Provisioning 2112"

"9803","Citrix_Licensing_11.17.2.0_BUILD_37000.zip","License Server for Windows - Version 11.17.2.0 Build 37000"

"19998","CitrixStoreFront-x64.exe ","StoreFront 1912 LTSR CU4"

"20209","Workspace-Environment-Management-v-2112-01-00-01.zip","Workspace Environment Management 2112"
"@

#Folder dialog
#https://stackoverflow.com/questions/25690038/how-do-i-properly-use-the-folderbrowserdialog-in-powershell
Function Get-Folder($initialDirectory)

{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return ($folder + "\") 
}

#Prompt for folder path
$path = Get-Folder

#Import Download Function
function get-ctxbinary {
	<#
.SYNOPSIS
  Downloads a Citrix VDA or ISO from Citrix.com utilizing authentication
.DESCRIPTION
  Downloads a Citrix VDA or ISO from Citrix.com utilizing authentication.
  Ryan Butler 2/6/2020
.PARAMETER DLNUMBER
  Number assigned to binary download
.PARAMETER DLEXE
  File to be downloaded
.PARAMETER DLPATH
  Path to store downloaded file. Must contain following slash (c:\temp\)
.PARAMETER CitrixUserName
  Citrix.com username
.PARAMETER CitrixPassword
  Citrix.com password
.EXAMPLE
  Get-CTXBinary -DLNUMBER "16834" -DLEXE "Citrix_Virtual_Apps_and_Desktops_7_1912.iso" -CitrixUserName "mycitrixusername" -CitrixPassword "mycitrixpassword" -DLPATH "C:\temp\"
#>
	Param(
		[Parameter(Mandatory = $true)]$DLNUMBER,
		[Parameter(Mandatory = $true)]$DLEXE,
		[Parameter(Mandatory = $true)]$DLPATH,
		[Parameter(Mandatory = $true)]$CitrixUserName,
		[Parameter(Mandatory = $true)]$CitrixPassword
	)
	#Initialize Session 
	Invoke-WebRequest "https://identity.citrix.com/Utility/STS/Sign-In?ReturnUrl=%2fUtility%2fSTS%2fsaml20%2fpost-binding-response" -SessionVariable websession -UseBasicParsing | Out-Null

	#Set Form
	$form = @{
		"persistent" = "on"
		"userName"   = $CitrixUserName
		"password"   = $CitrixPassword
	}

	#Authenticate
	try {
		Invoke-WebRequest -Uri ("https://identity.citrix.com/Utility/STS/Sign-In?ReturnUrl=%2fUtility%2fSTS%2fsaml20%2fpost-binding-response") -WebSession $websession -Method POST -Body $form -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -ErrorAction Stop | Out-Null
	}
	catch {
		if ($_.Exception.Response.StatusCode.Value__ -eq 500) {
			Write-Verbose "500 returned on auth. Ignoring"
			Write-Verbose $_.Exception.Response
			Write-Verbose $_.Exception.Message
		}
		else {
			throw $_
		}

	}
	$dlurl = "https://secureportal.citrix.com/Licensing/Downloads/UnrestrictedDL.aspx?DLID=${DLNUMBER}&URL=https://downloads.citrix.com/${DLNUMBER}/${DLEXE}"
	$download = Invoke-WebRequest -Uri $dlurl -WebSession $websession -UseBasicParsing -Method GET
	$webform = @{ 
		"chkAccept"            = "on"
		"clbAccept"            = "Accept"
		"__VIEWSTATEGENERATOR" = ($download.InputFields | Where-Object { $_.id -eq "__VIEWSTATEGENERATOR" }).value
		"__VIEWSTATE"          = ($download.InputFields | Where-Object { $_.id -eq "__VIEWSTATE" }).value
		"__EVENTVALIDATION"    = ($download.InputFields | Where-Object { $_.id -eq "__EVENTVALIDATION" }).value
	}

	$outfile = ($DLPATH + $DLEXE)
	#Download
	Invoke-WebRequest -Uri $dlurl -WebSession $websession -Method POST -Body $webform -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -OutFile $outfile
	return $outfile
}

# Script Version
# ========================================================================================================================================
Write-Output ""
Write-Host -BackgroundColor DarkGreen -ForegroundColor Yellow "   Evergreen Script - Update your Software, the lazy way    "
Write-Host -BackgroundColor DarkGreen -ForegroundColor Yellow "      Manuel Winkel - Deyda Consulting (www.deyda.net)      "
Write-Host -BackgroundColor DarkGreen -ForegroundColor Yellow "                      Version $eVersion                        "
$host.ui.RawUI.WindowTitle ="Evergreen Script - Update your Software, the lazy way - Manuel Winkel (www.deyda.net) - Version $eVersion"
If (Test-Path "$PSScriptRoot\update.ps1" -PathType leaf) {
    #Remove-Item -Path "$PSScriptRoot\Update.ps1" -Force
} Else {
    If (!(Test-Path -Path HKLM:SOFTWARE\EvergreenScript)) {
        New-Item -Path HKLM:SOFTWARE\EvergreenScript -ErrorAction SilentlyContinue | Out-Null
        New-ItemProperty -Path HKLM:SOFTWARE\EvergreenScript -Name Version -Value "$eVersion" -PropertyType STRING -ErrorAction SilentlyContinue | Out-Null
    }
    Else {
        If (!(Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EvergreenScript | Select-Object $_.Version).Version -ne "") {
            New-ItemProperty -Path HKLM:\SOFTWARE\EvergreenScript -Name Version -Value "$eVersion" -PropertyType STRING -ErrorAction SilentlyContinue | Out-Null
        } Else {
            Set-ItemProperty -Path HKLM:\SOFTWARE\EvergreenScript -Name Version -Value "$eVersion" -ErrorAction SilentlyContinue | Out-Null
        }
    }
    If (((Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EvergreenScript | Select-Object $_.UpdateLanguage).UpdateLanguage -eq "1") -eq $true) {
    } else {
        New-ItemProperty -Path HKLM:SOFTWARE\EvergreenScript -Name UpdateLanguage -Value 1 -PropertyType DWORD -ErrorAction SilentlyContinue | Out-Null
    }
}

If (!($NoUpdate)) {
    Write-Output ""
    Write-Host -Foregroundcolor DarkGray "Is there a newer Evergreen Script version?"
    
    If ($NewerVersion -eq $false) {
        # No new version available
        Write-Host -Foregroundcolor Green "OK, script is newest version!"
        Write-Output ""
        # Change old LastSetting.txt files to the new format (AddScript)
        If (!(Test-Path -Path HKLM:SOFTWARE\EvergreenScript)) {
            New-Item -Path HKLM:SOFTWARE\EvergreenScript -ErrorAction SilentlyContinue | Out-Null
            New-ItemProperty -Path HKLM:SOFTWARE\EvergreenScript -Name Version -Value "$eVersion" -PropertyType STRING -ErrorAction SilentlyContinue | Out-Null
        }
        Else {
            If (!(Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EvergreenScript | Select-Object $_.Version).Version -ne "") {
                New-ItemProperty -Path HKLM:\SOFTWARE\EvergreenScript -Name Version -Value "$eVersion" -PropertyType STRING -ErrorAction SilentlyContinue | Out-Null
            } Else {
                Set-ItemProperty -Path HKLM:\SOFTWARE\EvergreenScript -Name Version -Value "$eVersion" -ErrorAction SilentlyContinue | Out-Null
            }
        }
        If (((Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\EvergreenScript | Select-Object $_.UpdateLanguage).UpdateLanguage -eq "1") -eq $true) {
        } Else {
            If (!$GUIfile) {$GUIfile = "LastSetting.txt"}
            If (Test-Path "$PSScriptRoot\$GUIfile" -PathType leaf) {
                Write-Host -Foregroundcolor DarkGray "Update from version pre 2.7 --> Change LastSetting.txt file!"
                Write-Host -Foregroundcolor Red "Change language fields in $GUIfile to new format."
                Write-Output ""
                $LastSetting = Get-Content "$PSScriptRoot\$GUIfile"
                $Change_Language = $LastSetting[0] -as [int]
                Switch ($Change_Language) {
                    0 {$New_Language = "4"}
                    1 {$New_Language = "5"}
                    2 {$New_Language = "6"}
                    3 {$New_Language = "7"}
                    4 {$New_Language = "8"}
                    5 {$New_Language = "9"}
                    6 {$New_Language = "12"}
                    7 {$New_Language = "13"}
                    8 {$New_Language = "14"}
                    9 {$New_Language = "15"}
                    10 {$New_Language = "16"}
                    11 {$New_Language = "17"}
                    12 {$New_Language = "19"}
                    13 {$New_Language = "22"}
                    14 {$New_Language = "23"}
                }
                $LastSetting[0] = $New_Language
                $Change_AdobeReaderDC_Language = $LastSetting[95] -as [int]
                Switch ($Change_AdobeReaderDC_Language) {
                    0 {$New_AdobeReaderDC_Language = "0"}
                    1 {$New_AdobeReaderDC_Language = "3"}
                    2 {$New_AdobeReaderDC_Language = "4"}
                    3 {$New_AdobeReaderDC_Language = "5"}
                    4 {$New_AdobeReaderDC_Language = "6"}
                    5 {$New_AdobeReaderDC_Language = "7"}
                    6 {$New_AdobeReaderDC_Language = "8"}
                    7 {$New_AdobeReaderDC_Language = "10"}
                    8 {$New_AdobeReaderDC_Language = "11"}
                    9 {$New_AdobeReaderDC_Language = "12"}
                    10 {$New_AdobeReaderDC_Language = "13"}
                    11 {$New_AdobeReaderDC_Language = "14"}
                    12 {$New_AdobeReaderDC_Language = "16"}
                    13 {$New_AdobeReaderDC_Language = "19"}
                    14 {$New_AdobeReaderDC_Language = "20"}
                }
                $LastSetting[95] = $New_AdobeReaderDC_Language
                $Change_FoxitPDFEditor_Language = $LastSetting[100] -as [int]
                Switch ($Change_FoxitPDFEditor_Language) {
                    0 {$New_FoxitPDFEditor_Language = "0"}
                    1 {$New_FoxitPDFEditor_Language = "1"}
                    2 {$New_FoxitPDFEditor_Language = "2"}
                    3 {$New_FoxitPDFEditor_Language = "3"}
                    4 {$New_FoxitPDFEditor_Language = "4"}
                    5 {$New_FoxitPDFEditor_Language = "5"}
                    6 {$New_FoxitPDFEditor_Language = "6"}
                    7 {$New_FoxitPDFEditor_Language = "7"}
                    8 {$New_FoxitPDFEditor_Language = "8"}
                    9 {$New_FoxitPDFEditor_Language = "8"}
                    10 {$New_FoxitPDFEditor_Language = "9"}
                    11 {$New_FoxitPDFEditor_Language = "10"}
                    12 {$New_FoxitPDFEditor_Language = "11"}
                    13 {$New_FoxitPDFEditor_Language = "12"}
                    14 {$New_FoxitPDFEditor_Language = "13"}
                }
                $LastSetting[100] = $New_FoxitPDFEditor_Language
                $Change_KeePass_Language = $LastSetting[106] -as [int]
                Switch ($Change_KeePass_Language) {
                    0 {$New_KeePass_Language = "0"}
                    1 {$New_KeePass_Language = "5"}
                    2 {$New_KeePass_Language = "6"}
                    3 {$New_KeePass_Language = "7"}
                    4 {$New_KeePass_Language = "8"}
                    5 {$New_KeePass_Language = "9"}
                    6 {$New_KeePass_Language = "10"}
                    7 {$New_KeePass_Language = "13"}
                    8 {$New_KeePass_Language = "14"}
                    9 {$New_KeePass_Language = "15"}
                    10 {$New_KeePass_Language = "16"}
                    11 {$New_KeePass_Language = "17"}
                    12 {$New_KeePass_Language = "18"}
                    13 {$New_KeePass_Language = "20"}
                    14 {$New_KeePass_Language = "23"}
                    15 {$New_KeePass_Language = "24"}
                }
                $LastSetting[106] = $New_KeePass_Language
                $Change_MS365Apps_Language = $LastSetting[109] -as [int]
                Switch ($Change_MS365Apps_Language) {
                    0 {$New_MS365Apps_Language = "0"}
                    1 {$New_MS365Apps_Language = "5"}
                    2 {$New_MS365Apps_Language = "6"}
                    3 {$New_MS365Apps_Language = "7"}
                    4 {$New_MS365Apps_Language = "8"}
                    5 {$New_MS365Apps_Language = "9"}
                    6 {$New_MS365Apps_Language = "10"}
                    7 {$New_MS365Apps_Language = "13"}
                    8 {$New_MS365Apps_Language = "14"}
                    9 {$New_MS365Apps_Language = "15"}
                    10 {$New_MS365Apps_Language = "16"}
                    11 {$New_MS365Apps_Language = "18"}
                    12 {$New_MS365Apps_Language = "20"}
                    13 {$New_MS365Apps_Language = "23"}
                    14 {$New_MS365Apps_Language = "24"}
                }
                $LastSetting[109] = $New_MS365Apps_Language
                $Change_MS365Apps_Visio_Language = $LastSetting[111] -as [int]
                Switch ($Change_MS365Apps_Visio_Language) {
                    0 {$New_MS365Apps_Visio_Language = "0"}
                    1 {$New_MS365Apps_Visio_Language = "5"}
                    2 {$New_MS365Apps_Visio_Language = "6"}
                    3 {$New_MS365Apps_Visio_Language = "7"}
                    4 {$New_MS365Apps_Visio_Language = "8"}
                    5 {$New_MS365Apps_Visio_Language = "9"}
                    6 {$New_MS365Apps_Visio_Language = "10"}
                    7 {$New_MS365Apps_Visio_Language = "13"}
                    8 {$New_MS365Apps_Visio_Language = "14"}
                    9 {$New_MS365Apps_Visio_Language = "15"}
                    10 {$New_MS365Apps_Visio_Language = "16"}
                    11 {$New_MS365Apps_Visio_Language = "18"}
                    12 {$New_MS365Apps_Visio_Language = "20"}
                    13 {$New_MS365Apps_Visio_Language = "23"}
                    14 {$New_MS365Apps_Visio_Language = "24"}
                }
                $LastSetting[111] = $New_MS365Apps_Visio_Language
                $Change_MS365Apps_Project_Language = $LastSetting[113] -as [int]
                Switch ($Change_MS365Apps_Project_Language) {
                    0 {$New_MS365Apps_Project_Language = "0"}
                    1 {$New_MS365Apps_Project_Language = "5"}
                    2 {$New_MS365Apps_Project_Language = "6"}
                    3 {$New_MS365Apps_Project_Language = "7"}
                    4 {$New_MS365Apps_Project_Language = "8"}
                    5 {$New_MS365Apps_Project_Language = "9"}
                    6 {$New_MS365Apps_Project_Language = "10"}
                    7 {$New_MS365Apps_Project_Language = "13"}
                    8 {$New_MS365Apps_Project_Language = "14"}
                    9 {$New_MS365Apps_Project_Language = "15"}
                    10 {$New_MS365Apps_Project_Language = "16"}
                    11 {$New_MS365Apps_Project_Language = "18"}
                    12 {$New_MS365Apps_Project_Language = "20"}
                    13 {$New_MS365Apps_Project_Language = "23"}
                    14 {$New_MS365Apps_Project_Language = "24"}
                }
                $LastSetting[113] = $New_MS365Apps_Project_Language
                $Change_MSSQLServerManagementStudio_Language = $LastSetting[121] -as [int]
                Switch ($Change_MSSQLServerManagementStudio_Language) {
                    0 {$New_MSSQLServerManagementStudio_Language = "0"}
                    1 {$New_MSSQLServerManagementStudio_Language = "2"}
                    2 {$New_MSSQLServerManagementStudio_Language = "3"}
                    3 {$New_MSSQLServerManagementStudio_Language = "4"}
                    4 {$New_MSSQLServerManagementStudio_Language = "5"}
                    5 {$New_MSSQLServerManagementStudio_Language = "6"}
                    6 {$New_MSSQLServerManagementStudio_Language = "7"}
                    7 {$New_MSSQLServerManagementStudio_Language = "8"}
                    8 {$New_MSSQLServerManagementStudio_Language = "9"}
                    9 {$New_MSSQLServerManagementStudio_Language = "10"}
                }
                $LastSetting[121] = $New_MSSQLServerManagementStudio_Language
                $Change_Firefox_Language = $LastSetting[125] -as [int]
                Switch ($Change_Firefox_Language) {
                    0 {$New_Firefox_Language = "0"}
                    1 {$New_Firefox_Language = "6"}
                    2 {$New_Firefox_Language = "7"}
                    3 {$New_Firefox_Language = "9"}
                    4 {$New_Firefox_Language = "10"}
                    5 {$New_Firefox_Language = "13"}
                    6 {$New_Firefox_Language = "14"}
                    7 {$New_Firefox_Language = "18"}
                    8 {$New_Firefox_Language = "20"}
                    9 {$New_Firefox_Language = "23"}
                    10 {$New_Firefox_Language = "24"}
                }
                $LastSetting[125] = $New_Firefox_Language
                $Change_IrfanView_Language = $LastSetting[138] -as [int]
                Switch ($Change_IrfanView_Language) {
                    0 {$New_IrfanView_Language = "0"}
                    1 {$New_IrfanView_Language = "4"}
                    2 {$New_IrfanView_Language = "5"}
                    3 {$New_IrfanView_Language = "6"}
                    4 {$New_IrfanView_Language = "7"}
                    5 {$New_IrfanView_Language = "8"}
                    6 {$New_IrfanView_Language = "9"}
                    7 {$New_IrfanView_Language = "12"}
                    8 {$New_IrfanView_Language = "13"}
                    9 {$New_IrfanView_Language = "14"}
                    10 {$New_IrfanView_Language = "15"}
                    11 {$New_IrfanView_Language = "16"}
                    12 {$New_IrfanView_Language = "18"}
                    13 {$New_IrfanView_Language = "21"}
                    14 {$New_IrfanView_Language = "22"}
                }
                $LastSetting[138] = $New_IrfanView_Language
                $Change_MSOffice_Language = $LastSetting[139] -as [int]
                Switch ($Change_MSOffice_Language) {
                    0 {$New_MSOffice_Language = "0"}
                    1 {$New_MSOffice_Language = "5"}
                    2 {$New_MSOffice_Language = "6"}
                    3 {$New_MSOffice_Language = "7"}
                    4 {$New_MSOffice_Language = "8"}
                    5 {$New_MSOffice_Language = "9"}
                    6 {$New_MSOffice_Language = "10"}
                    7 {$New_MSOffice_Language = "13"}
                    8 {$New_MSOffice_Language = "14"}
                    9 {$New_MSOffice_Language = "15"}
                    10 {$New_MSOffice_Language = "16"}
                    11 {$New_MSOffice_Language = "18"}
                    12 {$New_MSOffice_Language = "20"}
                    13 {$New_MSOffice_Language = "23"}
                    14 {$New_MSOffice_Language = "24"}
                }
                $LastSetting[139] = $New_MSOffice_Language
                $Change_MSOffice_Visio_Language = $LastSetting[167] -as [int]
                Switch ($Change_MSOffice_Visio_Language) {
                    0 {$New_MSOffice_Visio_Language = "0"}
                    1 {$New_MSOffice_Visio_Language = "5"}
                    2 {$New_MSOffice_Visio_Language = "6"}
                    3 {$New_MSOffice_Visio_Language = "7"}
                    4 {$New_MSOffice_Visio_Language = "8"}
                    5 {$New_MSOffice_Visio_Language = "9"}
                    6 {$New_MSOffice_Visio_Language = "10"}
                    7 {$New_MSOffice_Visio_Language = "13"}
                    8 {$New_MSOffice_Visio_Language = "14"}
                    9 {$New_MSOffice_Visio_Language = "15"}
                    10 {$New_MSOffice_Visio_Language = "16"}
                    11 {$New_MSOffice_Visio_Language = "18"}
                    12 {$New_MSOffice_Visio_Language = "20"}
                    13 {$New_MSOffice_Visio_Language = "23"}
                    14 {$New_MSOffice_Visio_Language = "24"}
                }
                $LastSetting[167] = $New_MSOffice_Visio_Language
                $Change_MSOffice_Project_Language = $LastSetting[169] -as [int]
                Switch ($Change_MSOffice_Project_Language) {
                    0 {$New_MSOffice_Project_Language = "0"}
                    1 {$New_MSOffice_Project_Language = "5"}
                    2 {$New_MSOffice_Project_Language = "6"}
                    3 {$New_MSOffice_Project_Language = "7"}
                    4 {$New_MSOffice_Project_Language = "8"}
                    5 {$New_MSOffice_Project_Language = "9"}
                    6 {$New_MSOffice_Project_Language = "10"}
                    7 {$New_MSOffice_Project_Language = "13"}
                    8 {$New_MSOffice_Project_Language = "14"}
                    9 {$New_MSOffice_Project_Language = "15"}
                    10 {$New_MSOffice_Project_Language = "16"}
                    11 {$New_MSOffice_Project_Language = "18"}
                    12 {$New_MSOffice_Project_Language = "20"}
                    13 {$New_MSOffice_Project_Language = "23"}
                    14 {$New_MSOffice_Project_Language = "24"}
                }
                $LastSetting[169] = $New_MSOffice_Project_Language
                $Change_WinRAR_Language = $LastSetting[180] -as [int]
                Switch ($Change_WinRAR_Language) {
                    0 {$New_WinRAR_Language = "0"}
                    1 {$New_WinRAR_Language = "5"}
                    2 {$New_WinRAR_Language = "6"}
                    3 {$New_WinRAR_Language = "7"}
                    4 {$New_WinRAR_Language = "8"}
                    5 {$New_WinRAR_Language = "9"}
                    6 {$New_WinRAR_Language = "10"}
                    7 {$New_WinRAR_Language = "13"}
                    8 {$New_WinRAR_Language = "14"}
                    9 {$New_WinRAR_Language = "15"}
                    10 {$New_WinRAR_Language = "16"}
                    11 {$New_WinRAR_Language = "18"}
                    12 {$New_WinRAR_Language = "20"}
                    13 {$New_WinRAR_Language = "23"}
                    14 {$New_WinRAR_Language = "24"}
                }
                $LastSetting[180] = $New_WinRAR_Language
                $Change_MozillaThunderbird_Language = $LastSetting[183] -as [int]
                Switch ($Change_MozillaThunderbird_Language) {
                    0 {$New_MozillaThunderbird_Language = "0"}
                    1 {$New_MozillaThunderbird_Language = "3"}
                    2 {$New_MozillaThunderbird_Language = "4"}
                    3 {$New_MozillaThunderbird_Language = "5"}
                    4 {$New_MozillaThunderbird_Language = "6"}
                    5 {$New_MozillaThunderbird_Language = "7"}
                    6 {$New_MozillaThunderbird_Language = "8"}
                    7 {$New_MozillaThunderbird_Language = "9"}
                    8 {$New_MozillaThunderbird_Language = "10"}
                    9 {$New_MozillaThunderbird_Language = "11"}
                    10 {$New_MozillaThunderbird_Language = "12"}
                }
                $LastSetting[183] = $New_MozillaThunderbird_Language
            }
            Set-Content "$PSScriptRoot\$GUIfile" -Value $LastSetting
            New-ItemProperty -Path HKLM:SOFTWARE\EvergreenScript -Name UpdateLanguage -Value 1 -PropertyType DWORD -ErrorAction SilentlyContinue | Out-Null
            Write-Host -Foregroundcolor Green "Changes in the $GUIfile done!"
            Write-Output ""
        }
    }
    Else {
        # There is a new Evergreen Script Version
        Write-Host -Foregroundcolor Red "Attention! There is a new version of the Evergreen Script."
        Write-Output ""
        If ($file) {
            $update = @'
                Remove-Item -Path "$PSScriptRoot\Evergreen.ps1" -Force 
                Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Evergreen-Script/main/Evergreen.ps1 -OutFile ("$PSScriptRoot\" + "Evergreen.ps1")
                & "$PSScriptRoot\evergreen.ps1" -download -file $file
'@
            $update > $PSScriptRoot\update.ps1
            & "$PSScriptRoot\update.ps1"
            Break
        }
        ElseIf ($GUIfile) {
            $update = @'
                Remove-Item -Path "$PSScriptRoot\Evergreen.ps1" -Force 
                Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Evergreen-Script/main/Evergreen.ps1 -OutFile ("$PSScriptRoot\" + "Evergreen.ps1")
                & "$PSScriptRoot\evergreen.ps1" -download -GUIfile $GUIfile
'@
            $update > $PSScriptRoot\update.ps1
            & "$PSScriptRoot\update.ps1"
            Break
            
        }
        Else {
            $wshell = New-Object -ComObject Wscript.Shell
            $AnswerPending = $wshell.Popup("Do you want to download the new version?",0,"New Version Alert!",32+4)
            If ($AnswerPending -eq "6") {
                #Start-Process "https://www.deyda.net/index.php/en/evergreen-script/"
                $update = @'
                    Remove-Item -Path "$PSScriptRoot\Evergreen.ps1" -Force 
                    Invoke-WebRequest -Uri https://raw.githubusercontent.com/Deyda/Evergreen-Script/main/Evergreen.ps1 -OutFile ("$PSScriptRoot\" + "Evergreen.ps1")
                    & "$PSScriptRoot\evergreen.ps1"
'@
                $update > $PSScriptRoot\update.ps1
                & "$PSScriptRoot\update.ps1"
                Break
            }
        }
    }
}


$creds = Get-Credential -Message "Citrix Credentials"
$CitrixUserName = $creds.UserName
$CitrixPassword = $creds.GetNetworkCredential().Password

#Imports $CSV with download information
#$downloads = import-csv -Path ".\Helpers\Downloads.csv" -Delimiter ","
$downloads = $CSV | ConvertFrom-Csv -Delimiter ","

#Use CTRL to select multiple
$dls = $downloads | Out-GridView -PassThru -Title "Select Installer or ISO to download. CTRL to select multiple"

#Processes each download
foreach ($dl in $dls) {
    write-host "Downloading $($dl.filename)..."
    Get-CTXBinary -DLNUMBER $dl.dlnumber -DLEXE $dl.filename -CitrixUserName $CitrixUserName -CitrixPassword $CitrixPassword -DLPATH $path
}