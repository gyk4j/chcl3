using namespace System.ServiceProcess

Add-Type -AssemblyName PresentationCore,PresentationFramework

[string]$CRLF = "`r`n"
[string]$OK = "OK"
[bool]$DEBUG = $false

# Schedule Service
<#
New-Variable -Name TASK_STATE_UNKNOWN -Value 0 -Option Constant
New-Variable -Name TASK_STATE_DISABLED -Value 1 -Option Constant
New-Variable -Name TASK_STATE_QUEUED -Value 2 -Option Constant
New-Variable -Name TASK_STATE_READY -Value 3 -Option Constant
New-Variable -Name TASK_STATE_RUNNING -Value 4 -Option Constant
#>

# Installer
<#
New-Variable -Name ORC_NOT_STARTED -Value 0 -Option Constant
New-Variable -Name ORC_IN_PROGRESS -Value 1 -Option Constant
New-Variable -Name ORC_SUCCEEDED -Value 2 -Option Constant
New-Variable -Name ORC_SUCCEEDED_WITH_ERRORS -Value 3 -Option Constant
New-Variable -Name ORC_FAILED -Value 4 -Option Constant
New-Variable -Name ORC_ABORTED -Value 5 -Option Constant
#>

[string]$global:PrintBuffer

Function Change-ScriptDirectory {
    Set-Location -Path $PSScriptRoot
}

Function Print {
    Param( [string]$Message )

    if ([string]::IsNullOrEmpty($global:PrintBuffer)) {
        $global:PrintBuffer = ""
    }

    $global:PrintBuffer = "$global:PrintBuffer$Message$CRLF"
}

Function Flush {
    $OK = [System.Windows.MessageBox]::Show($global:PrintBuffer)
    $global:PrintBuffer = ""
}

Function Read-TextFile {
    Param ( [string]$Path )

    return Get-Content -Path $Path -Raw
}

Function Read-Line {
    Param(
        [string]$Path, 
        [string]$Delimiter, 
        [int]$Length, 
        [scriptblock]$Callback
    )

    Get-Content -Path $Path | ForEach-Object {
        [string]$Buffer = $_
        # Remove comment
        [int]$SemiColon = $Buffer.IndexOf(";")
        if ($SemiColon -gt -1) {
            $Buffer = $Buffer.Remove($SemiColon).Trim()
        }

        if ( ![string]::IsNullOrEmpty($Buffer) -and ![string]::IsNullOrWhiteSpace($Buffer) ) {
            # Split into tokens
            $Tokens = $Buffer -split $Delimiter

            if ( $Tokens.Count -gt 0 -and $Tokens.Count -ge $Length ) {
                #foreach( $t in $Tokens ){
                #    Write-Host "T: $t"
                #}
                $Callback.Invoke($Tokens) | Out-Null
            }
            #else {
            #    Write-Host "Skipped: $_"
            #}
        }
        #else {
        #    Write-Host "Skipped: $_"
        #}
    }
}

Function For-Each {
    Param(
        [string]$Path, 
        [string]$Delimiter, 
        [int]$Length, 
        [scriptblock]$Lambda
    )

    [scriptblock]$SubRef = $Lambda
    Read-Line -Path $Path -Delimiter $Delimiter -Length $Length -Callback $SubRef
    Flush
}

Function Display-License {
    [string]$License = Read-TextFile -Path "LICENSE"
    $License = $License.Replace($CRLF + $CRLF, "~~~").Replace($CRLF, "").Replace("~~~", $CRLF + $CRLF)
    $License = $License + $CRLF + $CRLF + "Click Cancel to exit now or OK to accept the license." + $CRLF

    if ($DEBUG) {
        return $OK
    }
    else {
        return [System.Windows.MessageBox]::Show($License, "License Agreement", "OKCancel", "Information")
    }
}

Function Display-Warning {
    [string]$Warning = @"
This script disables and/or removes log data, Windows 
services, registry keys, scheduled tasks Windows updates associated 
with Windows Telemetry. 
It also blocks IPs and domain names to prevent the uploading of 
collected telemetry data.

WARNING: These changes may cause operating system damage or 
impairments!

By proceeding with the use of this script, you accept the license, 
terms and conditions and all associated risks.

Click Cancel to exit now or OK to continue.
"@

    $Warning = $Warning.Replace($CRLF + $CRLF, "~~~").Replace($CRLF, "").Replace("~~~", $CRLF + $CRLF)

    if ($DEBUG) {
        return $OK
    }
    else {
        return [System.Windows.MessageBox]::Show($Warning, "Warning", "OKCancel", "Exclamation")
    }
}

Function Stop-Services {
    [ScriptBlock]$Handler = {
        Param( [string]$ServiceName )
        $Service = Get-Service -Name $ServiceName

        $Status = "?"
        if ($Service -ne $null -and $Service.Status -eq 'Running') {
            Stop-Service -Name $ServiceName
            #Start-Sleep -Milliseconds 5000
        }

        Set-Service -Name $ServiceName -StartupType Disabled
        
        if($Service -ne $null -and $Service.Status -eq 'Stopped' -and $Service.StartType -eq 'Disabled') {
            $Status = "-"
        }
        elseif ($Service -eq $null) {
            $Status = "?"
        }
        else {
            $Status = "!"
        }

        [string]$Message = "$Status $ServiceName ($($Service.StartType))"
        Print -Message $Message
    }

    For-Each -Path "data\services.txt" -Delimiter " " -Length 1 -Lambda $Handler
}

Function OverWrite-Files {
    [ScriptBlock]$Handler = {
        Param( [string]$FilePath )

        [string]$Status = "-"

        Clear-Content $FilePath
        Print -Message "$Status $FilePath"
    }

    For-Each -Path "data\files.txt" -Delimiter " " -Length 1 -Lambda $Handler
}

Function Update-RegistryKeyValues {
    [ScriptBlock]$Handler = {
        Param(
            [string]$Key,
            [string]$Value,
            [string]$Type,
            [string]$Data
        )

        $Key = $Key.Replace("HKLM\", "HKLM:\").Replace("HKCU\", "HKCU:\")

        $TypeMappings = @{
            REG_SZ = 'String';
            REG_MULTI_SZ = 'MultiString';
            REG_EXPAND_SZ = 'ExpandString';
            REG_DWORD = 'DWord';
            REG_QWORD = 'Qword';
            REG_BINARY = 'Binary';
            REG_NONE = 'Unknown'
        }

        $Type = $TypeMappings[$Type]
        
        [object]$ParsedData = $null
        if ($Type -eq 'DWord'){
            $ParsedData = [Int32]::Parse($Data)
        }
        elseif ($Type -eq 'Qword') {
            $ParsedData = [Int64]::Parse($Data)
        }
        else {
            $ParsedData = $Data
        }


        # Create the key if it does not exist
        If (-NOT (Test-Path $Key)) {
            New-Item -Path $Key -Force | Out-Null
        }

        # Now set the value
        New-ItemProperty -Path $Key -Name $Value -Value $ParsedData -PropertyType $Type -Force

        Print -Message "$Key\$Value=$Data ($Type)"
    }

    For-Each -Path "data\registry.txt" -Delimiter "," -Length 4 -Lambda $Handler
}

Function Disable-ScheduledTasks {
    $ScheduleService = New-Object -ComObject("Schedule.Service")
    $ScheduleService.Connect()
    $RootFolder = $ScheduleService.GetFolder("\")

    [ScriptBlock]$Handler = {
        Param( [string]$TaskName )
        [string]$Status = ""

        if ($RootFolder -eq $null){
            Write-Host "Error: Root folder is null"
            return 1
        }
       
        try {
            $RegisteredTask = $null
            $RegisteredTask = $RootFolder.GetTask($TaskName)

            # Stop the task if it is running
            if ($RegisteredTask.State -eq $TASK_STATE_RUNNING) {
                $RegisteredTask.Stop()
            }

            # Disable the scheduled task
            $RegisteredTask.Enabled = $false
            
            $Status = "-"
        }
        catch {
            $Status = "!"
        }
        
        Print -Message "$Status $TaskName $State"
    }

    For-Each -Path "data\schtasks.txt" -Delimiter ";" -Length 1 -Lambda $Handler    
}

Function Uninstall-WindowsUpdates {
    <#
    For Windows with Internet connection to download and install required NuGet.
    Source: https://powershellisfun.com/2024/01/19/using-the-powershell-pswindowsupdate-module/

    Examples:

    # Install NuGet (if required)
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    # Use NuGet to install PSWindowsUpdate cmdlet (https://www.powershellgallery.com/packages/PSWindowsUpdate)
    Install-Module PSWindowsUpdate

    # Import module for use
    Import-Module PSWindowsUpdate

    # List the commands provided by PSWindowsUpdate
    Get-Command -Module PSWindowsUpdate | Sort-Object CommandType, Name

    # Get list of available Windows Updates
    Get-WindowsUpdate

    # Install available updates
    Install-WindowsUpdate -AcceptAll

    # List installed updates
    Get-WUHistory
    Get-WUHistory -Last 2
    Get-WUHistory | Format-List

    # Uninstall an update
    Uninstall-WindowsUpdate -KBArticleID KB4023057

    # Install an update
    Install-WindowsUpdate -KBArticleID KB4052623
    #>

    <#
    But since I am assuming this script may be used on a non-Internet 
    connected offline system without any NuGet pre-installed, and access to 
    PowerShell Gallery is restricted, let's fallback onto the old COM objects 
    instead.
    #>
    
    $Session = New-Object -ComObject("Microsoft.Update.Session")
	$Session.ClientApplicationID = "MSDN Sample Script"
    
	$Searcher = $Session.CreateUpdateSearcher()
	$SearchResult = $Searcher.Search("IsInstalled=1")
	$UpdatesToUninstall = New-Object -ComObject("Microsoft.Update.UpdateColl")
    
    [ScriptBlock]$Handler = {
        Param( [string]$KB )
        
        # Exit if $SearchResult and $UpdatesToUninstall are uninitialized
        if ($SearchResult -eq $null) {
            Write-Host "SearchResult = null"
            return
        }
        elseif ($UpdatesToUninstall -eq $null) {
            Write-Host "UpdatesToUninstall = null"
            return
        }

        $Found = $false
        for ($i=0; $i -lt $SearchResult.Updates.Count; $i++){
            $Item = $SearchResult.Updates.Item($i)

            # Add all matching updates from search result to be uninstalled
            if ($Item.Title.EndsWith("(KB$KB)")) {
                $UpdatesToUninstall.Add($Item)
                $Found = $true
            }
        }

        if ($Found) {
            Print("- KB$KB")
        }
        else {
            Print("- KB$KB")
        }
    }

    For-Each -Path "data\updates.txt" -Delimiter " " -Length 1 -Lambda $Handler

    if ($UpdatesToUninstall.Count -gt 0) {
        $Installer = $Session.CreateUpdateInstaller()
		$Installer.Updates = $UpdatesToUninstall
        $UninstallResult = $Installer.Uninstall()

        switch ($UninstallResult.ResultCode)
        {
            $ORC_NOT_STARTED { Write-Host "Not started" }
            $ORC_IN_PROGRESS { Write-Host "In progress" }
            $ORC_SUCCEEDED { Write-Host "Succeeded" }
            $ORC_SUCCEEDED_WITH_ERRORS { Write-Host "Succeeded with errors" }
            $ORC_FAILED { Write-Host "Failed" }
            $ORC_ABORTED { Write-Host "Aborted" }
            default { Write-Host "Unknown operation result code: $($UninstallResult.ResultCode)" }
        }
    }
    else {
        Write-Host "No update is required to be uninstalled" 
    }
}

Function Block-IPs {
    [System.Collections.Generic.List[string]]$IPs = New-Object System.Collections.Generic.List[string]

    [ScriptBlock]$Handler = {
        Param( [string]$IPAddr )

        $IPs.Add( $IPAddr )
        Print ( "$($IPs.Count-1): $IPAddr" )
    }

    For-Each -Path "data\ip.txt" -Delimiter " " -Length 1 -Lambda $Handler

    if ($IPs -eq $null) {
        Write-Host "IPs are null."
        return
    }

    if ($IPs.Count -lt 0) {
        Write-Host "Count < 0"
        return
    }

    $CurrentProfiles = $null
    # Profiles
	New-Variable -Name NET_FW_PROFILE2_DOMAIN -Value 0x1 -Option Constant
	New-Variable -Name NET_FW_PROFILE2_PRIVATE -Value 0x2 -Option Constant
	New-Variable -Name NET_FW_PROFILE2_PUBLIC -Value 0x4 -Option Constant
	New-Variable -Name NET_FW_PROFILE2_ALL -Value 0x7fffffff -Option Constant

	# Protocol
	New-Variable -Name NET_FW_IP_PROTOCOL_TCP -Value 6 -Option Constant
	New-Variable -Name NET_FW_IP_PROTOCOL_UDP -Value 17 -Option Constant
	New-Variable -Name NET_FW_IP_PROTOCOL_ANY -Value 256 -Option Constant

	# Direction
	New-Variable -Name NET_FW_RULE_DIR_IN -Value 1 -Option Constant
	New-Variable -Name NET_FW_RULE_DIR_OUT -Value 2 -Option Constant

	# Action
	New-Variable -Name NET_FW_ACTION_BLOCK -Value 0 -Option Constant
	New-Variable -Name NET_FW_ACTION_ALLOW -Value 1 -Option Constant

    <#
    On newer Windows version (Windows 8 and Server 2012) and PowerShell 5.1 
    onward, we can use the built-in NetSecurity module and its Firewall 
    commands.

    On older Windows (e.g. Windows 7, Vista, XP, Server 2008, Server 2003), we
    need to fallback on the traditional COM objects.

    We can rewrite this to use the newer commands when the baseline Windows 
    and PowerShell version is changed. Modern Windows 10 and 11 should have the
    required NetSecurity module already built-in.
    #>

    # Create the FwPolicy2 object.
    $FwPolicy2 = New-Object -ComObject("HNetCfg.FwPolicy2")

    # Get the Rules object
    $RulesObject = $FwPolicy2.Rules

    $CurrentProfiles = $FwPolicy2.CurrentProfileTypes

    # Remove any existing rule from a previous run
    $RulesObject.Remove("Block PowerShell Telemetry")

    # Create a Rule Object.
    $NewRule = New-Object -ComObject("HNetCfg.FWRule")

    $NewRule.Name = "Block PowerShell Telemetry"
	$NewRule.Description = "Block PowerShell Telemetry"
	#$NewRule.Applicationname = "%systemDrive%\Program Files\MyApplication.exe"
	$NewRule.Protocol = $NET_FW_IP_PROTOCOL_ANY
	$NewRule.RemoteAddresses = [string]::Join(",", $IPs)
	#$NewRule.LocalPorts = 8080
	#$NewRule.RemotePorts = 443,80
	$NewRule.Direction = $NET_FW_RULE_DIR_OUT
	$NewRule.Enabled = $true
	#$NewRule.Grouping = "@firewallapi.dll,-23255"
	$NewRule.Profiles = $NET_FW_PROFILE2_ALL #$CurrentProfiles
	$NewRule.Action = $NET_FW_ACTION_BLOCK

    # Add a new rule
	$RulesObject.Add($NewRule)
}

Function Main {
    Change-ScriptDirectory

    $Accepted = Display-License    
    if ($Accepted -ne $OK) {
        return 1
    }

    $Accepted = Display-Warning    
    if ($Accepted -ne $OK) {
        return 2
    }

    Stop-Services
    OverWrite-Files
    Update-RegistryKeyValues
    Disable-ScheduledTasks
    Uninstall-WindowsUpdates
    Block-IPs

    return 0
}

Function CleanUp {
    #Write-Host "Cleaning up..."
}

[int]$ExitCode = Main
CleanUp
$ExitCode
#$Host.SetShouldExit($ExitCode)
#Exit $ExitCode
