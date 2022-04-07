#requires -version 5
<#
.SYNOPSIS
Reading the required WriteCache for non-persistent machines that are provisioned via PVS.
.DESCRIPTION
Passing the server names via the -Server parameter. The server names can be separated by comma. If no server name is specified, localhost is used.

.NOTES
  Version:          0.01
  Author:           Manuel Winkel <www.deyda.net>
  Creation Date:    2022-04-07

  // NOTE: Purpose/Change
  2022-04-07        Initial Version

.PARAMETER Server

List of servers seperated with comma

.EXAMPLE

.\Citrix-PVSWriteCache.ps1 -Server XenApp01,XenApp02,XenApp03,XenApp04,XenApp05,XenApp06,XenApp07

Show the WriteCache usage of the defined machines

.EXAMPLE

.\Citrix-PVSWriteCache.ps1

Show the WriteCache usage of localhost

#>

[CmdletBinding()]

Param (
    
        [Parameter(
            HelpMessage='List of Servers, Comma seperated',
            ValuefromPipelineByPropertyName = $true
        )]
        [string]$Server
    
)


Function Get-IniContent {

    [CmdletBinding()]  
    Param(  
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath  
    )  
    
    $ini = @{}  
            switch -regex -file $FilePath  
            {  
                "^\[(.+)\]$" # Section  
                {  
                    $section = $matches[1]  
                    $ini[$section] = @{}  
                    $CommentCount = 0  
                }  
                "^(;.*)$" # Comment  
                {  
                    if (!($section))  
                    {  
                        $section = "No-Section"  
                        $ini[$section] = @{}  
                    }  
                    $value = $matches[1]  
                    $CommentCount = $CommentCount + 1  
                    $name = "Comment" + $CommentCount  
                    $ini[$section][$name] = $value  
                }   
                "(.+?)\s*=\s*(.*)" # Key  
                {  
                    if (!($section))  
                    {  
                        $section = "No-Section"  
                        $ini[$section] = @{}  
                    }  
                    $name,$value = $matches[1..2]  
                    $ini[$section][$name] = $value  
                }  
            }  
            Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"  
            Return $ini  
}

If (!$server) {
    $server ="localhost"    
}


If (!(Test-Path HKLM:System\CurrentControlSet\Services\bnistack\pvsagent)) {
    Write-Host "This computer does not use PVS. Please pick another computer."
    Exit 1
}

$content = Get-IniContent "C:\Personality.ini"
$CacheType = $content["StringData"]["`$WriteCacheType"]
$CacheDrive = (Get-ItemProperty HKLM:System\CurrentControlSet\Services\bnistack\pvsagent).WriteCacheDrive

foreach ($machine in $server) {

    # Percent Free Disk space (is the cache drive in danger of being full?)
    $Disk = Get-WmiObject -class Win32_LogicalDisk -computername $machine -filter "DeviceID='$CacheDrive'"
    $DiskFreePercent = [System.Math]::Round($Disk.freespace / $Disk.size * 100, 1)

    If ($CacheType -eq "4") {
        # Cache on hard drive only
        $PvsWriteCache   = "$CacheDrive\.vdiskcache"

        # CacheDiskOverflowSize
        $CacheDiskMB = [Math]::Round((Get-Item $PvsWriteCache -Force).length/1MB)
        Write-Host -ForegroundColor Magenta "Computername -- $Machine"
        Write-Host "PVS Cache type = hard disk only"
        Write-Host "vDisk Cache file: $PvsWriteCache"
        Write-Host "vDisk Cache Drive free space: $DiskFreePercent %"
        Write-Host "vDisk Cache file size: $CacheDiskMB MB"
        Write-Host ""
    } ElseIf ($CacheType -eq "9") {
        # RAM Cache with disk overflow
        $PvsWriteCache   = "$CacheDrive\vdiskdif.vhdx"

        # CacheDiskOverflowSize
        $CacheDiskMB = [Math]::Round((Get-Item $PvsWriteCache -Force).length/1MB)

        # NonPaged Pool Memory (RAM Cache in use) adjusted for likely kernel usage
        $NPPM = [math]::Round((Get-WmiObject Win32_PerfFormattedData_PerfOS_Memory -ComputerName $machine).PoolNonPagedBytes /1MB)

        Write-Host -ForegroundColor Magenta "Computername -- $Machine"
        Write-Host "PVS Cache type = RAM cache with disk overflow"
        Write-Host "vDisk Cache file: $PvsWriteCache"
        Write-Host "vDisk Cache file size: $CacheDiskMB MB"
        Write-Host "vDisk Cache Drive free space: $DiskFreePercent %"
        Write-Host "vDisk RAM Cache usage: $NPPM MB"
        Write-Host ""

    } Else {
        Write-Host "The disk cache type is not supported in this script. Please choose another computer and try again."
    }
}