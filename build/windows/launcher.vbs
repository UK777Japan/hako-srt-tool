Option Explicit

Dim oShell, oFSO
Set oShell = CreateObject("WScript.Shell")
Set oFSO   = CreateObject("Scripting.FileSystemObject")

Dim installDir
installDir = oFSO.GetParentFolderName(WScript.ScriptFullName)

Dim pythonExe
pythonExe = installDir & "\python\python.exe"

If Not oFSO.FileExists(pythonExe) Then
    MsgBox "Python が見つかりません。" & vbCrLf & _
           "再インストールしてください。" & vbCrLf & "(" & pythonExe & ")", _
           vbCritical, "ハコ割り生成ツール"
    WScript.Quit 1
End If

' ---- すでに起動済みか確認 ----------------------------------------
Dim alreadyRunning
alreadyRunning = False
On Error Resume Next
Dim http
Set http = CreateObject("MSXML2.XMLHTTP")
http.Open "GET", "http://127.0.0.1:8503/_stcore/health", False
http.Send
If Err.Number = 0 Then
    If http.Status >= 200 And http.Status < 500 Then
        alreadyRunning = True
    End If
End If
On Error GoTo 0

If alreadyRunning Then
    oShell.Run "http://127.0.0.1:8503"
    WScript.Quit 0
End If

' ---- 出力ディレクトリ（Desktop/ハコ割り生成ツール_output） --------
Dim outputDir
outputDir = oShell.ExpandEnvironmentStrings("%USERPROFILE%") & "\Desktop\ハコ割り生成ツール_output"

' ---- 一時バッチファイルを書き出して起動 ---------------------------
Dim batPath
batPath = installDir & "\~startup.bat"

Dim f
Set f = oFSO.CreateTextFile(batPath, True)
f.WriteLine "@echo off"
f.WriteLine "title ハコ割り生成ツール"
f.WriteLine "set PATH=" & installDir & "\tools\ffmpeg\bin;%PATH%"
f.WriteLine "set HAKO_OUTPUT_DIR=" & outputDir
f.WriteLine "set WHISPER_CACHE_DIR=" & installDir & "\models\whisper"
f.WriteLine "if not exist """ & outputDir & """ mkdir """ & outputDir & """"
f.WriteLine """" & pythonExe & """ -m streamlit run """ & installDir & "\scripts\app.py"" " & _
            "--server.headless true " & _
            "--server.port 8503 " & _
            "--server.address 127.0.0.1"
f.WriteLine "echo."
f.WriteLine "echo Streamlit が終了しました。何かキーを押して閉じてください。"
f.WriteLine "pause > nul"
f.Close

' スタイル 7: タスクバーに最小化表示（エラー時は展開して確認できる）
oShell.Run """" & batPath & """", 7, False

' ---- サーバー起動を待つ（最大 3 分）------------------------------
Dim i, started
started = False
For i = 1 To 60
    WScript.Sleep 3000
    On Error Resume Next
    Dim http2
    Set http2 = CreateObject("MSXML2.XMLHTTP")
    http2.Open "GET", "http://127.0.0.1:8503/_stcore/health", False
    http2.Send
    If Err.Number = 0 Then
        If http2.Status >= 200 And http2.Status < 500 Then
            started = True
        End If
    End If
    On Error GoTo 0
    If started Then Exit For
Next

If Not started Then
    MsgBox "起動に時間がかかっています。" & vbCrLf & _
           "しばらく待ってからブラウザで以下を開いてください：" & vbCrLf & _
           "http://127.0.0.1:8503", _
           vbExclamation, "ハコ割り生成ツール"
End If

oShell.Run "http://127.0.0.1:8503"
