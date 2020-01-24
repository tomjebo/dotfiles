' OutlookVim.bas - Edit emails using Vim from Outlook
' ---------------------------------------------------------------
' Version:       14.0
' Authors:       David Fishburn <dfishburn dot vim at gmail dot com>
' Last Modified: 2016 Feb 17
' License:       VIM License
' Homepage:      http://www.vim.org/scripts/script.php?script_id=3087
'
' This VBScript should be installed as a macro inside of Microsoft Outlook.
' It will create two files and ask Vim to edit the file (body of the email)
' and Vim with use the second file to update the body of the email in
' Outlook with your changes.
'
' This code came from here originally:
'    http://barnson.org/node/295
' Some links might be useful
'    http://office.microsoft.com/en-us/help/HA010429591033.aspx
' Macro Security settings and creating digit certificates
'    http://www.pcreview.co.uk/forums/thread-854025.php
'
' It may be possible to pull the HTMLBody of an email, rather than
' plaintext as is currently used (in 5.0).  Instead of using
' item.body, we can reference item.htmlbody.  We can determine this
' ahead of time by checking (item.BodyFormat = olFormatHTML).
' I found out that for Outlook 2002, there is a constant called, OlBodyFormat.
'     olFormatUnspecified = 0
'     olFormatPlain = 1
'     olFormatHTML = 2
'     olFormatRichText = 3
' Another page related to Rich Text conversion:
'     http://msdn.microsoft.com/library/office/ff867828.aspx
'
'
' See http://msdn.microsoft.com/en-us/library/aa171418(v=office.11).aspx
'   - Documentation on HTMLBody Property (if above link no longer works)
'
' Having tried the htmlbody, the html Outlook produced for a 4 character
' email body was 300 lines long and extremely difficult to read.
'
' Writing files in Unicode format:
'     http://stackoverflow.com/questions/4143524/can-i-export-excel-data-with-utf-8-without-bom
'     http://www.alanwood.net/unicode/unicode_samples.html
' 
' Good HTML page with different character encoding to test with:
'     http://www.cyberactivex.com/unicodetutorialvb.htm
'
' VB 6.0 API
'     http://msdn.microsoft.com/en-us/library/aa265018%28v=VS.60%29.aspx


Option Explicit

Private Const OUTLOOK_VIM_VERSION = 14

Private Type STARTUPINFO
   cb As Long
   lpReserved As String
   lpDesktop As String
   lpTitle As String
   dwX As Long
   dwY As Long
   dwXSize As Long
   dwYSize As Long
   dwXCountChars As Long
   dwYCountChars As Long
   dwFillAttribute As Long
   dwFlags As Long
   wShowWindow As Integer
   cbReserved2 As Integer
   lpReserved2 As Long
   hStdInput As Long
   hStdOutput As Long
   hStdError As Long
End Type

Private Type PROCESS_INFORMATION
   hProcess As Long
   hThread As Long
   dwProcessID As Long
   dwThreadID As Long
End Type

#If VBA7 Then
Private Declare PtrSafe Function WaitForSingleObject Lib "kernel32" (ByVal _
   hHandle As Long, ByVal dwMilliseconds As Long) As Long
#Else
Private Declare Function WaitForSingleObject Lib "kernel32" (ByVal _
   hHandle As Long, ByVal dwMilliseconds As Long) As Long
#End If

#If VBA7 Then
Private Declare PtrSafe Function CreateProcessA Lib "kernel32" (ByVal _
   lpApplicationName As Long, ByVal lpCommandLine As String, ByVal _
   lpProcessAttributes As Long, ByVal lpThreadAttributes As Long, _
   ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, _
   ByVal lpEnvironment As Long, ByVal lpCurrentDirectory As Long, _
   lpStartupInfo As STARTUPINFO, lpProcessInformation As _
   PROCESS_INFORMATION) As Long
#Else
Private Declare Function CreateProcessA Lib "kernel32" (ByVal _
   lpApplicationName As Long, ByVal lpCommandLine As String, ByVal _
   lpProcessAttributes As Long, ByVal lpThreadAttributes As Long, _
   ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, _
   ByVal lpEnvironment As Long, ByVal lpCurrentDirectory As Long, _
   lpStartupInfo As STARTUPINFO, lpProcessInformation As _
   PROCESS_INFORMATION) As Long
#End If

#If VBA7 Then
Private Declare PtrSafe Function CloseHandle Lib "kernel32" (ByVal _
   hObject As Long) As Long
#Else
Private Declare Function CloseHandle Lib "kernel32" (ByVal _
   hObject As Long) As Long
#End If

Private Const NORMAL_PRIORITY_CLASS = &H20&
Private Const INFINITE = -1&

Private Function IsUnicode(xString As String) As Boolean
    Dim i, tmpchar

    IsUnicode = False
    For i = 1 To Len(xString)
        tmpchar = Mid(xString, i, 1)
        If AscW(tmpchar) > 255 Then
            IsUnicode = True
            Exit For
        End If
    Next i
End Function

Private Sub Save2File(sText, sFile, sEncoding)
    ' http://stackoverflow.com/questions/4125778/unicode-to-utf-8
    Dim oStream
    Set oStream = CreateObject("ADODB.Stream")
    With oStream
        .Open
        .Charset = sEncoding
        .WriteText sText
        ' 1 - Do not overwrite if exists
        ' 2 - Overwrite if exists
        .SaveToFile sFile, 2
    End With
    Set oStream = Nothing
End Sub

Sub ShowMsg(sText, debugMode)
    If debugMode Then
        MsgBox sText, vbInformation
    End If
End Sub


Private Sub VimEdit(item As Outlook.MailItem)
    On Error Resume Next

    Const TEMPORARYFOLDER = 2
    Const CRITICALERROR = 16

    Dim fso, tempfile, tfolder, tname, tfile, cfile, entryID, appRef, x, index
    Dim body As String, bodyFormat As String, msg As String
    Dim outlookVimVersion As String
    Dim startAt, allOccurrences
    Dim Vim, vimKeys, vimResponse, vimServerName, vimEncoding, vimOLEInstance
    Dim overwrite As Boolean, debugMode As Boolean
    Dim isUnicodeWanted As Boolean, useUnicodeFileFormat As Boolean, isUnicodeAllowed As Boolean, isUnicodeScanWanted As Boolean
    Dim isHTMLAllowed As Boolean, useHTML As Boolean
    Dim isRTFAllowed As Boolean, useRTF As Boolean

    If item Is Nothing Then
        ' MsgBox ("No current item")
        Exit Sub
    End If

    isUnicodeWanted = False
    isUnicodeAllowed = False
    isUnicodeScanWanted = False
    useUnicodeFileFormat = False
    isHTMLAllowed = False
    useHTML = False
    isRTFAllowed = False
    useRTF = False
    debugMode = False
    startAt = 1
    allOccurrences = -1
    ' MsgBox ("Just starting LaunchVim")

    ' MsgBox ("type:" & TypeName(item))
    ' MsgBox ("entryID type:" & TypeName(item.entryID))
    If item.entryID = "" Then
        ' If there is no EntryID, Vim will not be able to update
        ' the email during the save.
        ' Saving the item in Outlook will generate an EntryID
        ' and allow Vim to edit the contents.
       item.Save
       If Err.Number <> 0 Then
           ' Clear Err object fields.
           ' Err.Clear
           MsgBox "OutlookVim: Cannot edit with Vim, could not save item[" & _
                  Err.Description & _
                  "]", _
                  vbCritical
           Exit Sub
       End If
    End If

    ' Create an instance of Vim (if one does not already exist)
    Set Vim = CreateObject("Vim.Application")
    If Vim Is Nothing Then
        MsgBox "OutlookVim: Could not create a Vim OLE object, " & _
               "please ensure Vim has been installed." & _
               vbCrLf & _
               "Inside Vim, the command[:echo has('ole')] should echo 1", _
               vbCritical
        Exit Sub
    End If

    vimOLEInstance = Vim.Eval("v:servername")

    vimResponse = Vim.Eval("(exists('g:loaded_outlook')?(g:loaded_outlook):0)")
    If vimResponse = 0 Then
        MsgBox "OutlookVim: The Vim instance[" & _
               vimOLEInstance & _
               "] does not have the OutlookVim plugin installed.  " & _
               "You may need to restart your Vim instance(s).", _
               vbCritical
        Exit Sub
    Else
        outlookVimVersion = vimResponse
    End If

    vimResponse = Vim.Eval("(exists('g:outlook_debug')?(g:outlook_debug):0)")
    If vimResponse > 0 Then
        debugMode = True
        Call ShowMsg("OutlookVim: Enabling debug mode against Vim instance[" & vimOLEInstance & _
                     "] VB version[" & OUTLOOK_VIM_VERSION & _
                     "] Vim version[" & outlookVimVersion & "]" _
                    , debugMode)
    End If

    If outlookVimVersion <> OUTLOOK_VIM_VERSION Then
        MsgBox "OutlookVim: The OutlookVim VB script version[" & OUTLOOK_VIM_VERSION & _
               "] differs from the Vim OutlookVim plugin version[" & outlookVimVersion & _
               "] please ensure all versions are the same.", _
               vbCritical
        Exit Sub
    End If

    vimResponse = Vim.Eval("(exists('g:outlook_servername')?1:0)")
    If vimResponse = 0 Then
        MsgBox "OutlookVim: Please ensure g:outlook_servername is set " & _
               "in version 3.0 or above of OutlookVim", _
               vbCritical
        Exit Sub
    End If

    vimServerName = Vim.Eval("g:outlook_servername")
    If vimServerName <> "" Then
        Call ShowMsg("OutlookVim: Vim Servername specified:" & vimServerName, debugMode)
        vimResponse = Vim.Eval("match(serverlist(), '\<" & vimServerName & "\>')")
        If vimResponse = -1 Then
            MsgBox "OutlookVim: There are no Vim instances running named[" & _
                   vimServerName & _
                   "]. Found these Vim instances[\n" & _
                   Vim.Eval("serverlist()") & _
                   "]. Please start a new Vim instance using [" & _
                   "gvim --servername " & vimServerName & _
                   "]", _
                   vbCritical
            Exit Sub
        End If
    End If

    ' Not implemented, leaving at the default of utf-16le
    ' vimEncoding = Vim.Eval("(exists('g:outlook_encoding')?(g:outlook_encoding):'')")
    ' Call ShowMsg ("OutlookVim: Setting encoding to:" & vimEncoding, debugMode)

    vimResponse = Vim.Eval("(exists('g:outlook_always_use_unicode')?(g:outlook_always_use_unicode):0)")
    If vimResponse > 0 Then
        isUnicodeWanted = True
        Call ShowMsg("OutlookVim: Enabling isUnicodeWanted support due to g:outlook_always_use_unicode", debugMode)
        ' If vimEncoding = "" Then
        '     vimEncoding = "utf-16le"
        '     Call ShowMsg ("OutlookVim: Initially defaulting unicode encoding to:" & vimEncoding, debugMode)
        ' Else
        '     Call ShowMsg ("OutlookVim: Using specified encoding:" & vimEncoding, debugMode)
        ' End If
    End If

    vimResponse = Vim.Eval("(exists('g:outlook_supported_body_format')?(g:outlook_supported_body_format):'')")
    If vimResponse <> "" Then
        msg = "OutlookVim: Allowing body formats[plain"
        Select Case vimResponse
            Case "html", "HTML"
                isHTMLAllowed = True
                msg = msg & ",html"
            Case "rtf", "RTF"
                isRTFAllowed = True
                msg = msg & ",rtf"
            Case Else
                isHTMLAllowed = False
                isRTFAllowed = False
        End Select
        msg = msg & "]"
        Call ShowMsg(msg, debugMode)
    End If

    vimResponse = Vim.Eval("match(&fileencodings, '\<ucs-bom\|utf\>')")
    If vimResponse > -1 Then
        vimResponse = Vim.Eval("match(&encoding, '\<utf\>')")
        If vimResponse > -1 Then
            ' If the users Vim instance has encoding which support
            ' multibyte characters, turn on unicode support by default
            isUnicodeAllowed = True
            Call ShowMsg("OutlookVim: Unicode allowed due to global fileencodings", debugMode)
            If isUnicodeWanted Then
                useUnicodeFileFormat = True
                Call ShowMsg("OutlookVim: Defaulting all messages to use Unicode utf-16le", debugMode)
            End If
        Else
            If isUnicodeWanted Then
                MsgBox ("OutlookVim: Unicode format requested by g:outlook_always_use_unicode " & _
                        "but Vim's encoding option is not setup for unicode.  " & _
                        "In Vim, see :h outlook-unicode")
                isUnicodeWanted = False
            End If
        End If
    Else
        If isUnicodeWanted Then
            MsgBox ("OutlookVim: Unicode format requested by g:outlook_always_use_unicode " & _
                    "but Vim's fileencodings option is not setup for unicode.  " & _
                    "In Vim, see :h outlook-unicode")
            isUnicodeWanted = False
        End If
    End If

    If isUnicodeWanted = False Then
        vimResponse = Vim.Eval("(exists('g:outlook_scan_email_body_unicode')?(g:outlook_scan_email_body_unicode):0)")
        If vimResponse = 1 Then
            ' Unicode format has not been enabled by default.
            ' Scan the email to check if there are any unicode characters
            ' in it, show error message if Vim is not unicode capable.
            isUnicodeScanWanted = True
            Call ShowMsg("OutlookVim: Unicode scan allowed due to outlook_scan_email_body_unicode", debugMode)
        End If
    End If



    Set fso = CreateObject("Scripting.FileSystemObject")
    If Err.Number <> 0 Then
        MsgBox "OutlookVim: Could not create a file system object[" & Err.Number & "]" & vbCrLf & _
               "Please ensure the Windows Script Host utility has been installed and registered correctly." & vbCrLf & _
               "You may want to follow the Upgrade links to correct the problem." & vbCrLf & _
               "See http://msdn.microsoft.com/en-us/library/9bbdkx3k.aspx", _
               vbCritical
        Exit Sub
    End If

    Set tfolder = fso.GetSpecialFolder(TEMPORARYFOLDER)
    tname = fso.GetTempName
    tname = Left(tname, (Len(tname) - 3)) & "outlook"
    ' MsgBox ("Temp folder:" & tfolder.ShortPath)
    ' MsgBox ("InternetCodePage:" & item.InternetCodepage)

    ' Only edit the email in HTML if it is already in HTML
    ' otherwise, simply use the plain format.
    bodyFormat = "plain"
        ' Case "rtf", "RTF"
        '     ' http://www.cryptosys.net/pki/manpki/pki_stringstobytes.html
        '     body = StrConv(item.RTFBody, vbUnicode)
    Select Case item.bodyFormat
    Case olFormatHTML
        If isHTMLAllowed Then
            body = item.HTMLBody
            bodyFormat = "html"
        End If
        Call ShowMsg("OutlookVim: HTML body: " & item.bodyFormat & " using format:" & bodyFormat, debugMode)
    Case olFormatRichText
        If isRTFAllowed Then
            body = item.RTFBody
            bodyFormat = "rtf"
        End If
        Call ShowMsg("OutlookVim: RTF body: " & item.bodyFormat & " using format:" & bodyFormat, debugMode)
    Case Else
        body = item.body
        Call ShowMsg("OutlookVim: Plain body: " & item.bodyFormat & " using format:" & bodyFormat, debugMode)
    End Select


    If useUnicodeFileFormat <> True Then
        If isUnicodeScanWanted Then
            isUnicodeWanted = IsUnicode(body)
            If isUnicodeWanted Then
                Call ShowMsg("OutlookVim: Found unicode characters, setting isUnicodeWanted", debugMode)
                If isUnicodeAllowed Then
                    useUnicodeFileFormat = True
                    Call ShowMsg("OutlookVim: Switching to useUnicodeFileFormat", debugMode)
                Else
                    MsgBox "OutlookVim: Email contains unicode characters, cannot switch to " & _
                           "unicode format as Vim is not setup for unicode.  " & _
                           "In Vim, see :h outlook-unicode", _
                           vbCritical
                    Exit Sub
                End If
            End If
        End If
    End If

    ' Should be a new temporary file each time
    overwrite = False
    Set tfile = tfolder.CreateTextFile(tname, overwrite, useUnicodeFileFormat)
    If Err.Number <> 0 Then
        ' Clear Err object fields.
        ' Err.Clear
        MsgBox "OutlookVim: Could not create email file [" & _
            tfolder.ShortPath & "\" & tname & _
            "] Details[" & Err.Number & ":" & Err.Description & "]" & _
            " UnicodeFileFormat[" & useUnicodeFileFormat & "]", _
            vbCritical
        tfile.Close
        fso.DeleteFile (tfolder.ShortPath & "\" & tname)
        ' Quit will close Outlook
        ' Quit
        Exit Sub
    End If
    ' MsgBox ("Created body file:" & tfile.Name)

    ' Parameters
    '   Expression
    '       Type: System.String
    '       Required. String expression containing substring to replace.
    '   Find
    '       Type: System.String
    '       Required. Substring being searched for.
    '   Replacement
    '       Type: System.String
    '       Required. Replacement substring.
    '   Start
    '       Type: System.Int32
    '       Optional. Position within Expression that starts a substring used for replacement. The return value of Replace is a string that begins at Start, with appropriate substitutions. If omitted, 1 is assumed.
    '   Count
    '       Type: System.Int32
    '       Optional. Number of substring substitutions to perform. If omitted, the default value is �1, which means "make all possible substitutions."
    '   Compare
    '       Type: Microsoft.VisualBasic.CompareMethod
    '       Optional. Numeric value indicating the kind of comparison to use when evaluating substrings. See Settings for values.
    ' tfile.Write (Replace(body, Chr(13) & Chr(10), Chr(10)))
    ' Need the extra parameters (especially the binary compare) when using unicode files
    ' tfile.Write(Replace(body, Chr(13) & Chr(10), Chr(10), startAt, allOccurrences, vbBinaryCompare))
    tfile.Write (body)
    If Err.Number <> 0 Then
        ' Clear Err object fields.
        ' Err.Clear
        MsgBox "OutlookVim: Could not replace newline characters in file [" & _
               tfolder.ShortPath & "\" & tname & _
               "] Details[" & Err.Number & ":" & Err.Description & "]" & _
               " UnicodeFileFormat[" & useUnicodeFileFormat & "]", _
               vbCritical
        tfile.Close
        fso.DeleteFile (tfolder.ShortPath & "\" & tname)
        ' Quit will close Outlook
        ' Quit
        Exit Sub
    End If
    'Try
    '    tfile.Write (Replace(body, Chr(13) & Chr(10), Chr(10)))
    ' Catch ex As Exception
    'Catch
    '    tfile.Write (body)
    '    MsgBox ("Could not convert CRLFs:" & vbCrLf & ex.Message)
    'End Try

    tfile.Close
    ' MsgBox ("tfile:" & tname)

    ' Write out the control file so the outlookvim javascript file
    ' can tell Outlook which inspector to refresh
    Set cfile = tfolder.CreateTextFile(tname & ".ctl")
    ' MsgBox ("EntryID:" & Replace(item.entryID, Chr(13) & Chr(10), Chr(10)))
    cfile.Write (Replace(item.entryID, Chr(13) & Chr(10), Chr(10)))
    If Err.Number <> 0 Then
        ' Clear Err object fields.
        ' Err.Clear
        MsgBox "OutlookVim: Could not create control file [" & _
               tfolder.ShortPath & "\" & tname & _
               "] Details[" & Err.Description & "]", _
               vbCritical
        cfile.Close
        fso.DeleteFile (tfolder.ShortPath & "\" & tname)
        fso.DeleteFile (tfolder.ShortPath & "\" & tname & ".ctl")
        ' Quit will close Outlook
        ' Quit
        Exit Sub
    End If
    cfile.Close
    ' MsgBox ("id:" & item.EntryID)
    ' MsgBox tfolder.ShortPath & "\" & tname


    vimKeys = "<C-O>:call Outlook_EditFile( '" & tfolder.ShortPath & "\" & tname & "', '"
    If useUnicodeFileFormat Then
        If vimEncoding = "" Then
            vimEncoding = "utf-16le"
            ' Call ShowMsg ("OutlookVim: Defaulting unicode encoding to:" & vimEncoding, debugMode)
        End If
        vimKeys = vimKeys & vimEncoding
    End If
    vimKeys = vimKeys & "', '" & bodyFormat & "' )<Enter>"

    Call ShowMsg("OutlookVim: vimKeys:" & vimKeys, debugMode)
    ' Use Vim's OLE feature to edit the email
    ' This allows us to re-use the same Vim for multiple emails
    Vim.SendKeys vimKeys

    ' Force the Vim to the foreground
    Vim.SetForeground

Finished:
End Sub

Private Function GetSelectedItems() As Outlook.Selection
    ' http://support.microsoft.com/kb/240935
    ' This uses an existing instance if available (default Outlook behavior).
    Dim oApp As New Outlook.Application
    Dim oExp As Outlook.Explorer
    Dim oSel As Outlook.Selection   ' You need a selection object for getting the selection.
    Dim oItem As Object             ' You don't know the type yet.

    Set oExp = oApp.ActiveExplorer  ' Get the ActiveExplorer.
    Set oSel = oExp.Selection       ' Get the selection.
    Set GetSelectedItems = oSel       ' Get the selection.
    ' Set GetSelectedItems = oExp.Selection       ' Get the selection.
End Function

Private Sub GetSelectedItem_Click()
    ' This uses an existing instance if available (default Outlook behavior).
    Dim oApp As New Outlook.Application
    Dim oExp As Outlook.Explorer
    Dim oSel As Outlook.Selection   ' You need a selection object for getting the selection.
    Dim oItem As Object             ' You don't know the type yet.
    Dim i

    Set oExp = oApp.ActiveExplorer  ' Get the ActiveExplorer.
    Set oSel = oExp.Selection       ' Get the selection.

    For i = 1 To oSel.Count         ' Loop through all the currently .selected items
        Set oItem = oSel.item(i)    ' Get a selected item.
        DisplayInfo oItem           ' Display information about it.
    Next i
End Sub

Private Sub DisplayInfo(oItem As Object)

    Dim strMessageClass As String
    Dim oAppointItem As Outlook.AppointmentItem
    Dim oContactItem As Outlook.ContactItem
    Dim oMailItem As Outlook.MailItem
    Dim oJournalItem As Outlook.JournalItem
    Dim oNoteItem As Outlook.NoteItem
    Dim oTaskItem As Outlook.TaskItem

    ' You need the message class to determine the type.
    strMessageClass = oItem.MessageClass

    If (strMessageClass = "IPM.Appointment") Then       ' Calendar Entry.
        Set oAppointItem = oItem
        MsgBox oAppointItem.Subject
        MsgBox oAppointItem.start
    ElseIf (strMessageClass = "IPM.Contact") Then       ' Contact Entry.
        Set oContactItem = oItem
        MsgBox oContactItem.FullName
        MsgBox oContactItem.Email1Address
    ElseIf (strMessageClass = "IPM.Note") Then          ' Mail Entry.
        Set oMailItem = oItem
        MsgBox oMailItem.Subject
        MsgBox oMailItem.body
    ElseIf (strMessageClass = "IPM.Activity") Then      ' Journal Entry.
        Set oJournalItem = oItem
        MsgBox oJournalItem.Subject
        MsgBox oJournalItem.Actions
    ElseIf (strMessageClass = "IPM.StickyNote") Then    ' Notes Entry.
        Set oNoteItem = oItem
        MsgBox oNoteItem.Subject
        MsgBox oNoteItem.body
    ElseIf (strMessageClass = "IPM.Task") Then          ' Tasks Entry.
        Set oTaskItem = oItem
        MsgBox oTaskItem.DueDate
        MsgBox oTaskItem.PercentComplete
    End If

End Sub

Private Sub HandleMultipleItems(op As String)
    On Error Resume Next
    ' Dim ol, insp, i
    Dim i
    Dim oSel As Outlook.Selection
    Dim strMessageClass As String
    Dim oItem As Object
    Dim oMailItem As Outlook.MailItem
    Dim oMailResponse As Outlook.MailItem

    ' Set ol = Application
    Set oSel = GetSelectedItems()

    For i = 1 To oSel.Count         ' Loop through all the currently .selected items
        Set oItem = oSel.item(i)    ' Get a selected item.
        ' You need the message class to determine the type.
        strMessageClass = oItem.MessageClass

        If (strMessageClass = "IPM.Note") Then          ' Mail Entry.
            Set oMailItem = oItem
            ' oMailItem.Display
            If (op = "Reply") Then
                Set oMailResponse = oMailItem.Reply
            ElseIf (op = "ReplyToAll") Then
                Set oMailResponse = oMailItem.ReplyAll
            ElseIf (op = "Forward") Then          ' Mail Entry.
                Set oMailResponse = oMailItem.Forward
            End If
            oMailResponse.Display
            ' Set insp = ol.ActiveInspector
            Call VimEdit(oMailResponse)
        End If
    Next i
End Sub

Public Sub Edit()
    On Error Resume Next

    Dim ol, insp
    Dim oMailItem As Outlook.MailItem

    Set ol = Application
    Set insp = ol.ActiveInspector
    Set oMailItem = insp.CurrentItem
    If oMailItem Is Nothing Then
        ' MsgBox ("No current item")
        Exit Sub
    End If
    Call VimEdit(oMailItem)
End Sub

Public Sub Forward()
    On Error Resume Next
    HandleMultipleItems ("Forward")
End Sub

Public Sub Reply()
    On Error Resume Next
    HandleMultipleItems ("Reply")
End Sub

Public Sub ReplyToAll()
    On Error Resume Next
    HandleMultipleItems ("ReplyToAll")
End Sub

Public Sub Compose()
    On Error Resume Next
    Dim ol, insp
    Dim oMailItem As Outlook.MailItem

    Set ol = Application
    ' If you add the Vim Macro button to the Outlook Inbox
    ' instead of the menu for a new mail item when you launch
    ' the macro there is not active mailitem.  This will
    ' create a new mail item and launch Vim to edit it.
    Set oMailItem = ol.CreateItem(olMailItem)
    oMailItem.Display

    Set insp = ol.ActiveInspector
    If insp Is Nothing Then
        ' MsgBox ("No active inspector")
        Exit Sub
    End If
    Call VimEdit(oMailItem)
End Sub

Public Sub ExecCmd(cmdline$)

    Dim proc As PROCESS_INFORMATION
    Dim start As STARTUPINFO
    Dim ReturnValue As Integer

    ' Initialize the STARTUPINFO structure:
    start.cb = Len(start)

    ' Start the shelled application:
    ReturnValue = CreateProcessA(0&, cmdline$, 0&, 0&, 1&, _
      NORMAL_PRIORITY_CLASS, 0&, 0&, start, proc)

    ' Wait for the shelled application to finish:
    Do
        ReturnValue = WaitForSingleObject(proc.hProcess, 0)
        DoEvents
    Loop Until ReturnValue <> 258

    ReturnValue = CloseHandle(proc.hProcess)

End Sub
