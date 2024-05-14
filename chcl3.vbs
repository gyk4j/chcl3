Option Explicit

Const OPEN_READ = 1

Dim ExitCode
Dim PrintBuffer

Dim fso, wso, wmi
Set fso = CreateObject("Scripting.FileSystemObject")
Set wso = CreateObject("WScript.Shell")
Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")

Sub Print(Message)
	If IsNull(PrintBuffer) Then
		PrintBuffer = ""
	End If
	
	PrintBuffer = PrintBuffer & Message & vbCrLf
End Sub

Sub Flush
	WScript.Echo PrintBuffer
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
		
		If Not IsNull(Tokens) And IsArray(Tokens) And UBound(Tokens) >= 0 Then
			Call Callback(Tokens)
		End If
	Loop
	fh.Close
	Set fh = Nothing
End Sub

Sub ForEach(Path, Lambda)
	Dim SubRef
	Set SubRef = GetRef(Lambda)
	Call ReadLine(Path, SubRef)
	Set SubRef = Nothing
	Call Flush
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
	Dim Status, ServiceName, Matches, Match, ErrReturnCode 
	ServiceName = Service(LBound(Service))
	
	Set Matches = wmi.ExecQuery("Select * from Win32_Service Where Name ='" & ServiceName & "'")
	
	Status = "?"
	For Each Match in Matches
		If Match.State = "Running" Then
			Match.StopService()
			Wscript.Sleep 5000
		End If
		
		ErrReturnCode = Match.ChangeStartMode("Disabled")
		
		If ErrReturnCode = 0 Then
			Status = "-"
		Else
			Status = "!" ' Failed to disable service for future runs
		End If
	Next
		
	Call Print(Status & " " & ServiceName & " (" & ErrReturnCode & ")")
End Sub

Sub StopServices
	Call ForEach("data\services.txt", "StopService")
End Sub

Sub OverWriteFile(File)
	Dim Status, FilePath
	FilePath = File(0)
	
	On Error Resume Next
	
	Set f = fso.CreateTextFile(FilePath, True)
	
	If Err.Number <> 0 Then
		Status = "! (" & Err.Number & ": " & Err.Description & ")"
		Err.Clear
	Else
		f.WriteLine("")
		f.Close
		Status = "-"
	End If	
	
	Call Print(Status & " " & FilePath)
End Sub

Sub OverWriteFiles
	Call ForEach("data\files.txt", "OverWriteFile")
End Sub

Function Main()
	Dim Accepted
	Accepted = vbOK 'DisplayLicense()
		
	If Accepted = vbOK Then
		Accepted = vbOK 'DisplayWarning()
		
		If Accepted = vbOK Then
			Call StopServices
			Call OverWriteFiles
		End If
	End If
	
	Main = 0 ' Report no error
End Function

Sub CleanUp
	Set fso = Nothing
	Set wso = Nothing
	'Never clean up WMI as it will stop services.msc from running.
	'Only clean up objects that are created.
End Sub

ExitCode = Main()
Call CleanUp
WScript.Quit(ExitCode)


