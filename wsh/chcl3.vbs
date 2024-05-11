Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")

Function ReadTextFile(Path)
	Dim Buffer
	Set fh = fso.OpenTextFile(Path, 1)
	Buffer = fh.ReadAll()
	fh.Close
	Set fh = Nothing
	ReadTextFile = Buffer
End Function

Function DisplayLicense()
	Dim LicenseText
	LicenseText = ReadTextFile("..\LICENSE")
	
	'Reflow the text by removing unwanted new line characters. Keep the empty
	'line separating paragraphs.
	LicenseText = Replace(Replace(Replace(LicenseText, vbCrLf & vbCrLf, "~~~"), vbCrLf, " "), "~~~", vbCrLf & vbCrLf)
	
	LicenseText = LicenseText & vbCrLf & "Click No to exit now or Yes to accept the license." & vbCrLf
	DisplayLicense = MsgBox(LicenseText, vbYesNo + vbInformation + vbDefaultButton2, "License Agreement")
End Function

Function DisplayWarning
	Dim WarningText
	WarningText = "This script disables and/or removes log data, Windows " & _
		"services, registry keys, scheduled tasks Windows updates associated " & _
		"with Windows Telemetry. " & _
		"It also blocks IPs and domain names to prevent the uploading of " & _
		"collected telemetry data." & vbCrLf & _
		vbCrLf & _
		"WARNING: These changes may cause operating system damage or " & _
		"impairments!" & vbCrLf & _
		vbCrLf & _
		"By proceeding with the use of this script, you accept the license, " & _
		"terms and conditions and all associated risks." & vbCrLf & _
		vbCrLf & _
		"Click No to exit now or Yes to continue." & vbCrLf
	
	DisplayWarning = MsgBox(WarningText, vbYesNo + vbExclamation + vbDefaultButton2, "Warning")
End Function

Sub Main()
	Dim Accepted
	Accepted = DisplayLicense()
		
	If Accepted = vbYes Then
		Accepted = DisplayWarning()
		
		If Accepted = vbYes Then
			WScript.Echo "Continue..."
		End If
	End If
End Sub

Call Main

