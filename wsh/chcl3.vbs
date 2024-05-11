Dim fso
Set fso = CreateObject("Scripting.FileSystemObject")

Function DisplayLicense()
	Dim LicenseText
	
	Set fh = fso.OpenTextFile("..\LICENSE", 1)
	strFileText = fh.ReadAll()
	fh.Close
	Set fh = Nothing
	
	LicenseText = Replace(Replace(Replace(strFileText, vbCrLf & vbCrLf, "~~~"), vbCrLf, " "), "~~~", vbCrLf & vbCrLf)	
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

