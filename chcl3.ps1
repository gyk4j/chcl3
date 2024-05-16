Add-Type -AssemblyName PresentationCore,PresentationFramework

[string]$CRLF = "`r`n"
[string]$OK = "OK"
[bool]$DEBUG = $false

Function Change-ScriptDirectory {
    Set-Location -Path $PSScriptRoot
}

Function Read-TextFile {
    Param ( [string]$Path )

    return Get-Content -Path $Path -Raw
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
