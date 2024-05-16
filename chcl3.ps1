using namespace System.ServiceProcess

Add-Type -AssemblyName PresentationCore,PresentationFramework

[string]$CRLF = "`r`n"
[string]$OK = "OK"
[bool]$DEBUG = $true

Function Change-ScriptDirectory {
    Set-Location -Path $PSScriptRoot
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
                $Callback.Invoke($Tokens)
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
        Param( [string[]]$Tokens )
        $ServiceName = $Tokens[0]
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

    }

    For-Each -Path "data\services.txt" -Delimiter " " -Length 1 -Lambda $Handler
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
