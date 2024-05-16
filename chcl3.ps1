Add-Type -AssemblyName PresentationCore,PresentationFramework

[string]$CRLF = "`r`n"
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

    return [System.Windows.MessageBox]::Show($License, "License Agreement", "OKCancel", "Information")
}

Function Main {
    Change-ScriptDirectory

    $Accepted = Display-License    
    if ($Accepted -ne "OK") {
        return -1
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
