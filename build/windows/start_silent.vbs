Set oShell = CreateObject("WScript.Shell")
Set oFSO   = CreateObject("Scripting.FileSystemObject")
Dim sDir : sDir = oFSO.GetParentFolderName(WScript.ScriptFullName)
Dim sBat : sBat = Chr(34) & sDir & "\start.bat" & Chr(34)

' Docker イメージが読み込み済みか確認（高速チェック）
Dim bQuick : bQuick = False
On Error Resume Next
Dim proc
Set proc = oShell.Exec("cmd /c docker image inspect hako-srt-app 2>nul")
If Not IsNull(proc) Then
    proc.StdOut.ReadAll
    bQuick = (proc.ExitCode = 0)
End If
On Error GoTo 0

If bQuick Then
    ' 通常起動: ウィンドウを非表示で実行
    oShell.Run sBat, 0, False
Else
    ' 初回起動 / Docker 未稼働: 進捗ウィンドウを表示して実行
    oShell.Run sBat, 1, False
End If
