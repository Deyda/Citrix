# Citrix Delivery Controller

## Citrix-CloseDisconnectedSessions.ps1
Find disconnected XenApp sessions disconnected over a specified threshold and terminate them. Can also terminate specified processes in case they are preventing logoff.

## Citrix-EnableSSL-DDC.ps1
Script to enable SSL on DDC (Version >= 1912)

## Citrix-DailyCheck.ps1
Send an HTML email report of some Citrix health checkpoints such as machines not rebooted recently, machines not powered up, not registered or in maintenance mode, users disconnected for too long, file share capacities

## Citrix-AdminLogs.ps1
Produce grid view or csv report of Citrix XenApp/XenDesktop admin logs such as from actions in Studio or Director

## Citrix-GhostSession.ps1
Search for sessions that Citrix report as being disconnected where that session no longer exists on the specified server.

## Citrix-StudioAccess.ps1
Show all individual Citrix XenApp 7.x admins as defined in Studio by using the Active Directory PowerShell module to recursively expand groups.

## Citrix-DirectorOData.ps1
Send queries to a Citrix Delivery Controller or Citrix Cloud and present the results back as PowerShell objects

## Citrix-MigrateApps.ps1
Export and Import Apps out of a Desktop Group to another Site (save as CSV file)
