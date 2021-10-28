# Auto Download Scripts
PowerShell Scripts that download Citrix media used in a pipeline, Packer job, task sequence, etc.

**NOTE: There are currently no error handling if credentials are mistyped!**

## GetVDAS.ps1
Example to download multiple VDAs or ISOs using `Get-CTXBinary` function

## Helpers/Get-CTXBinary.ps1
Function to download ISO or VDA binary.  See **Helpers/Downloads.csv** for mapping

`Get-CTXBinary -DLNUMBER "16834" -DLEXE "Citrix_Virtual_Apps_and_Desktops_7_1912.iso" -CitrixUserName "mycitrixusername" -CitrixPassword "mycitrixpassword" -DLPATH "C:\temp\"`

## Currently Works with
| DL Number | Download | Name |
| --- | --- |
|19425|Citrix_Virtual_Apps_and_Desktops_7_1912_3000.iso|Citrix Virtual Apps and Desktops 7 1912 CU3 ISO|
|19426|VDAServerSetup_1912.exe|Citrix Virtual Apps and Desktops 7 1912 CU3 ISO|Multi-session OS Virtual Delivery Agent 1912 LTSR CU3|
|19427|VDAWorkstationSetup_1912.exe|Single-session OS Virtual Delivery Agent 1912 LTSR CU3|
|19428|VDAWorkstationCoreSetup_1912.exe|Single-session OS Core Services Virtual Delivery Agent 1912 LTSR CU3|
|19429|ProfileMgmt_1912.zip|Profile Management 1912 LTSR CU3|
|19431|Citrix_Provisioning_1912_13.iso|Citrix Provisioning 1312 CU3|
|19799|Citrix_Virtual_Apps_and_Desktops_7_2109.iso|Citrix Virtual Apps and Desktops 7 2109 ISO|
|19800|VDAServerSetup_2109.exe|Multi-session OS Virtual Delivery Agent 2109|
|19801|VDAWorkstationSetup_2109.exe|Single-session OS Virtual Delivery Agent 2109|
|19802|VDAWorkstationCoreSetup_2109.exe|Single-session OS Core Services Virtual Delivery Agent 2109|
|9803|Citrix_Licensing_11.17.2.0_BUILD_36000.zip|License Server for Windows - Version 11.17.2.0 Build 36000|
|19803|ProfileMgmt_2109.zip|Profile Management 2109|
|19430|CitrixStoreFront-x64.exe |StoreFront 1912 LTSR CU3|
|19804|Citrix_Provisioning_2109.iso|Citrix Provisioning 2109|

## Currently Works with
| DL Number | Download |
| --- | --- |
|16834|Citrix_Virtual_Apps_and_Desktops_7_1912.iso|
|16837|VDAServerSetup_1912.exe|
|16838|VDAWorkstationSetup_1912.exe|
|16839|VDAWorkstationCoreSetup_1912.exe|
|16555|Citrix_Virtual_Apps_and_Desktops_7_1909.iso|
|16558|VDAServerSetup_1909.exe|
|16559|VDAWorkstationSetup_1909.exe|
|16560|VDAWorkstationCoreSetup_1909.exe|
|16107|Citrix_Virtual_Apps_and_Desktops_7_1906.iso|
|16110|VDAServerSetup_1906.exe|
|16111|VDAWorkstationSetup_1906.exe|
|16112|VDAWorkstationCoreSetup_1906.exe|
|15901|VDAServerSetup_1903.exe|
|15902|VDAWorkstationSetup_1903.exe|
|15903|VDAWorkstationCoreSetup_1903.exe|
