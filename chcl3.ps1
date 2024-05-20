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
