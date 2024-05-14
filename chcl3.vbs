Option Explicit

Const DEBUG_MODE = False
Const OPEN_READ = 1

' Schedule Service
Const TASK_STATE_UNKNOWN 	= 0
Const TASK_STATE_DISABLED 	= 1
Const TASK_STATE_QUEUED 	= 2
Const TASK_STATE_READY 		= 3
Const TASK_STATE_RUNNING 	= 4

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

Sub ReadLine(Path, Delimiter, Length, Callback)
	Dim fh, Buffer
	Set fh= fso.OpenTextFile(Path, OPEN_READ)
	Do While Not fh.AtEndOfStream
		Buffer = fh.ReadLine
		'Remove comment
		Dim SemiColon
		SemiColon = InStr(Buffer, ";")
		If Not IsNull(SemiColon) And SemiColon > 0 Then
			Buffer = Trim(Left(Buffer, SemiColon - 1))
		End If
		
		If Len(Buffer) > 0 Then 		
			'Split into tokens
			Dim Tokens
			Tokens = Split(Buffer, Delimiter)
			
			If Not IsNull(Tokens) _
				And IsArray(Tokens) _
				And LBound(Tokens) = 0 _
				And UBound(Tokens) = Length-1 _
			Then
				Call Callback(Tokens)
			Else
				Print "Skipped: " & Trim(Buffer)
			End If
		End If
	Loop
	fh.Close
	Set fh = Nothing
End Sub

Sub ForEach(Path, Delimiter, Length, Lambda)
	Dim SubRef
	Set SubRef = GetRef(Lambda)
	Call ReadLine(Path, Delimiter, Length, SubRef)
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
	
	If DEBUG_MODE Then
		DisplayLicense = vbOK
	Else
		DisplayLicense = wso.Popup(LicenseText, 0, "License Agreement", vbOKCancel + vbInformation + vbDefaultButton2)
	End If
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
	
	If DEBUG_MODE Then
		DisplayWarning = vbOK
	Else
		DisplayWarning = wso.Popup(WarningText, 0, "Warning", vbOKCancel + vbExclamation + vbDefaultButton2)
	End If
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
	Call ForEach("data\services.txt", " ", 1, "StopService")
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
	Call ForEach("data\files.txt", " ", 1, "OverWriteFile")
End Sub

Sub UpdateRegistryKeyValue(KeyValue)
	wso.RegWrite KeyValue(0) & "\" & KeyValue(1), KeyValue(3), KeyValue(2)
	Call Print(KeyValue(0) & "\" & KeyValue(1) & "=" & KeyValue(3))
End Sub

Sub UpdateRegistryKeyValues
	Call ForEach("data\registry.txt", ",", 4, "UpdateRegistryKeyValue")
End Sub

Sub DisableScheduledTask(Task)
	Dim Status, TaskName
	TaskName = Task(0)

	' Create the TaskService object and connect
	Dim ScheduleService
	Set ScheduleService = CreateObject("Schedule.Service")
	Call ScheduleService.Connect()

	' Get the task folder that contains the tasks. 
	Dim RootFolder
	Set RootFolder = ScheduleService.GetFolder("\")
	
	Dim RegisteredTask
	'WScript.Echo "Getting " & TaskName
	On Error Resume Next
	Set RegisteredTask = RootFolder.GetTask(TaskName)
	
	If Err.Number <> 0 Then
		'WScript.Echo Err.Description & ": " & TaskName
		Err.Clear
		Status = "!"
	Else
		'WScript.Echo "Found " & RegisteredTask.Name & " (" & RegisteredTask.State & ")"
		
		' Stop the task if it is running
		If RegisteredTask.State = TASK_STATE_RUNNING Then
			RegisteredTask.Stop
		End If
		
		' Disable the scheduled task
		RegisteredTask.Enabled = False
		Status = "-"
	End If

	Call Print(Status & " " & TaskName)
End Sub

Sub DisableScheduledTasks
	Call ForEach("data\schtasks.txt", ";", 1, "DisableScheduledTask")
End Sub

Function Main()	
	If DisplayLicense() <> vbOK Then
		Main = 1
		Exit Function
	End If
	
	If DisplayWarning() <> vbOK Then
		Main = 2
		Exit Function
	End If
	
	Call StopServices
	Call OverWriteFiles
	Call UpdateRegistryKeyValues
	Call DisableScheduledTasks
	Main = 0 ' Report success/no error
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


