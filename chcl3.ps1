[bool]$DEBUG = $false

Function Main {
    return 0
}

Function CleanUp {
    Write-Host "Cleaning up..."
}

[int]$ExitCode = Main
CleanUp
#$Host.SetShouldExit($ExitCode)
#Exit $ExitCode
