Option Explicit

Const OPEN_READ = 1

Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")

Function ReadTextFile(Path)
	Dim fh, Buffer
	Set fh = fso.OpenTextFile(Path, OPEN_READ)
	Buffer = fh.ReadAll()
	fh.Close
	Set fh = Nothing
	ReadTextFile = Buffer
End Function

Sub ReadLine(Path, Callback)
	Dim fh, Buffer
	Set fh= fso.OpenTextFile(Path, OPEN_READ)
	Do While Not fh.AtEndOfStream
		Buffer = fh.ReadLine
		'Remove comment
		Dim SemiColon
		SemiColon = InStr(Buffer, ";")
		If Not IsNull(SemiColon) And SemiColon > 0 Then
			Buffer = Left(Buffer, SemiColon - 1)
		End If
		
		'Split into tokens
		Dim Tokens
		Tokens = Split(Buffer)
		
		If Not IsNull(Tokens) And IsArray(Tokens) And UBound(Tokens) > 0 Then
			Call Callback(Tokens)
		End If
	Loop
	fh.Close
	Set fh = Nothing
End Sub

Function DisplayLicense()
	Dim LicenseText
	LicenseText = ReadTextFile("LICENSE")
	
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

Sub StopService(Service)
	WScript.Echo Service(LBound(Service))
End Sub

Sub StopServices
	Dim SubRef
	Set SubRef = GetRef("StopService")
	Call ReadLine("data\services.txt", SubRef)
	Set SubRef = Nothing
End Sub

Sub Main()
	Dim Accepted
	Accepted = DisplayLicense()
		
	If Accepted = vbYes Then
		Accepted = DisplayWarning()
		
		If Accepted = vbYes Then
			Call StopServices
		End If
	End If
End Sub

Call Main

