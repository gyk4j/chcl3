@echo off

cls

echo ###########################################################################
type ..\LICENSE
echo.
echo       ^<Press CTRL-C to exit now or *any key* to accept the license.^>
pause > nul

cls

echo ###########################################################################
echo This script disables and/or removes log data, Windows services, registry 
echo keys, scheduled tasks Windows updates associated with Windows Telemetry. 
echo It also blocks IPs and domain names to prevent the uploading of collected 
echo telemetry data.
echo.
echo WARNING: These changes may cause operating system damage or impairments!
echo.
echo By proceeding with the use of this script, you accept the license, terms
echo and conditions and all associated risks.
echo.
echo           ^<Press CTRL-C to exit now or *any key* to continue.^>
pause > nul

cls

CD %~dp0

echo # Stopping services...
for /f %%A IN (data\services.txt) DO (
	sc query %%A > NUL
	
	if ERRORLEVEL 1060 (
		ECHO ! %%A
	) else (
		sc stop %%A > NUL
		sc config %%A start= disabled > NUL
		REM sc delete %%A
		ECHO - %%A
	)
)
echo.

echo # Overwriting files...
for /f %%A IN (data\files.txt) DO (
	echo "" > %%A
)
echo.

echo # Disabling Customer Experience Improvement Program (CEIP)...
REG ADD "HKLM\SOFTWARE\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f
echo.

echo # Disabling Windows Error Reporting...
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v DontShowUI /t REG_DWORD /d 1 /f
echo.

echo # Disabling Windows Updates...
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 1 /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v IncludeRecommendedUpdates /t REG_DWORD /d 0 /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v ElevateNonAdmins /t REG_DWORD /d 0 /f
echo.

echo # Disabling scheduled tasks...
for /f "delims=" %%A IN (data\schtasks.txt) DO (
	SCHTASKS /Query /TN "%%A" 2> NUL
	
	if ERRORLEVEL 1 (
		ECHO ! %%A
	) else (
		SCHTASKS /End /TN "%%A"
		SCHTASKS /Change /TN "%%A" /DISABLE
		REM SCHTASKS /Delete /TN "%%A" /F
		ECHO - %%A
	)
)
echo.

echo # Uninstalling telemetry Windows Updates
for /f "delims=" %%A IN (data\updates.txt) DO (
	WUSA /uninstall /kb:%%A /quiet /norestart
	if ERRORLEVEL 0 (
		ECHO - KB%%A
	) else (
		ECHO ! KB%%A
	)
)
echo.

echo # Blocking telemetry by IP...
SETLOCAL EnableDelayedExpansion
for /f %%A IN (data\ip.txt) DO (
	echo - %%A
	if not "%%A" == "" set blockedips=!blockedips!,%%A
)
netsh advfirewall firewall delete rule name="Block CEIP Telemetry"
netsh advfirewall firewall add rule name="Block CEIP Telemetry" dir=out remoteip=!blockedips! action=block
ENDLOCAL
echo.


echo # Blocking telemetry by DNS resolution...
for /f "delims=" %%A IN (data\dns.txt) DO (
	FIND /I "%%A" C:\Windows\System32\drivers\etc\hosts > NUL
	IF ERRORLEVEL 1 (
		ECHO - %%A
	) ELSE ( 
		REM ECHO ! %%A
	)
)
echo.

pause