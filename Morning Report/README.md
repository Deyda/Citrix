# Citrix-Morning-Report
This script is something that can be scheduled to be run every morning to understand what the environment looks like.  Also takes corrective actions if needed.

Tested with XA/XD 7.15LTSR and 7.18, however this should work with pretty much all 7.x versions.

Note: Use the -LogOnly option to run the script in Log Only mode, which doesn't take any actions on any machines.

If you're looking for a Deep Dive video on overall use of this script, check out https://youtu.be/axpU49cNh3E

# Prerequisites
You can run this on a Delivery Controller or a machine that has Studio installed.  See link for more information: https://developer-docs.citrix.com/projects/delivery-controller-sdk/en/latest/?_ga=2.136519158.731763323.1530151703-1594485461.1522783813#use-the-sdk 

# Functions
## Function ListUnregs
This Function lists Unregistered Machines.

## Function ListOff
This Function lists Powered Off machines.

## Function MaintMode
This Function lists Machines in Maintenance Mode. Proactively disables maintnenace mode on machines. If machine has a 'Maintenance*' tag on it, it leave it in Maintenance mode.  This has been added as a parameter for custom Tag names.  Note: If you hvae a VDA in maintenance mode, but do not have it tagged, the script will take it out of maintenance mode.  Also, if you have a machine tagged for Maintenance, but it's not actually in Maintenance Mode, the script will enable Maintenance Mode.

## Function PowerState
This Function lists Machines that have a 'bad' Power State.  An Example might be a Power State that is 'Unknown' to the hypervisor (hosting connection) or maybe stuck in a 'Turning On' state.  Note: If you added the $MaintTag parameter, the script will not try to turn the VDA on.

## Function UpTime
This Function lists Machines that haven't been restarted in a certain period of time.

## Function DGStats
This Function lists Delivery Group statistics, including Name, # of Session, Maintenance Mode, and Functional Level

## Function Reset-BadLoadEvaluators
This Function checks VDAs that come up from nightly reboot with Load Evaluator at 100% but 0 user sessions. These hosts will not take new sessions until this is reset.  This function identifies VDAs that need this and restarts the service accordingly.

## Function Get-RDSGracePeriod
This Function will check VDAs with RDS installed and confirm the RDS Grace Period is at 0, which means it has checked in with the RDS Licensing server and functioning correclty.

## Function Get-MoveLogs
This Function copies over certain log files that you may need.  In this case I'm copying over MOVE log files.  Feel free to substitute whatever log file you need to copy.  (Be sure to change the \\NAS\Share path).

## Function Check-AppVLogs
This Function checks the VDA for App-V Scheduler service and checks the event viewer for certain errors that may indicate a problem.

#
Be Sure to comment out certain functions that aren't tailored to your environment.  This is done at the bottom of the script.

# Examples
```
.\Citrix-MorningReport.ps1 -DeliveryControllers xd7-dc01 -LogDir c:\temp -MaintTag "MaintenanceMode-Manual"
```
This Example runs the script on Delivery Controller 'xd7-dc01' and logs the results to 'C:\Temp'.  It will also not take any action on machines tagged with the value of "MaintenanceMode-Manual".
```
.\Citrix-MorningReport.ps1 -DeliveryControllers xd7-dc01 -LogDir c:\temp -LogOnly
```
This Example puts the script in 'Log Mode' in which it will report everything, but won't take any action.  Such as restarting Machines or Powering them on.
```
.\Citrix-MorningReport.ps1 -DeliveryControllers xd7-dc01 -LogDir c:\temp -Email -SMTPserver smtp.domain.local -ToAddress "Steve@adf.com","John@adf.com" -FromAddress Steve@adf.com
```
This uses the '-Email' Flag along with the SMTP Server and To/From Address
