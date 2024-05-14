Option Explicit

Const OPEN_READ = 1

Dim ExitCode
Dim PrintBuffer

Dim fso, wso
Set fso = CreateObject("Scripting.FileSystemObject")
Set wso = CreateObject("WScript.Shell")

Sub Print(Message)
	If IsNull(PrintBuffer) Then
		PrintBuffer = ""
	End If
	
	PrintBuffer = PrintBuffer & Message & vbCrLf
End Sub

Sub Flush(Title)
	Call wso.Popup(PrintBuffer, 0, Title)
	PrintBuffer = ""
End Sub

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
	
	LicenseText = LicenseText & vbCrLf & vbCrLf & "Click Cancel to exit now or OK to accept the license." & vbCrLf
	DisplayLicense = wso.Popup(LicenseText, 0, "License Agreement", vbOKCancel + vbInformation + vbDefaultButton2)
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
		"Click Cancel to exit now or OK to continue." & vbCrLf
	
	DisplayWarning = wso.Popup(WarningText, 0, "Warning", vbOKCancel + vbExclamation + vbDefaultButton2)
End Function

Sub StopService(Service)
	Call Print(Service(LBound(Service)))
End Sub

Sub StopServices
	Dim SubRef
	Set SubRef = GetRef("StopService")
	Call ReadLine("data\services.txt", SubRef)
	Set SubRef = Nothing
	Call Flush("StopServices")
End Sub

Function Main()
	Dim Accepted
	Accepted = DisplayLicense()
		
	If Accepted = vbOK Then
		Accepted = DisplayWarning()
		
		If Accepted = vbOK Then
			Call StopServices
		End If
	End If
	
	Main = 0 ' Report no error
End Function

Sub CleanUp
	Set fso = Nothing
	Set wso = Nothing
End Sub

ExitCode = Main()
Call CleanUp
WScript.Quit(ExitCode)


