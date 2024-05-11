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

Sub Main()
	Dim Accepted
	Accepted = DisplayLicense()
	
	Dim ResponseText
	If Accepted = vbYes Then
		ResponseText = "Yea"
	Else
		ResponseText = "Nay"
	End If
	
	WScript.Echo ResponseText
End Sub

Call Main

