Option Explicit

Dim oShell
Set oShell = CreateObject("WScript.Shell")

Dim answer
answer = MsgBox("ハコ割り生成ツールを停止しますか？", _
                vbQuestion + vbYesNo, "ハコ割り生成ツール 停止")

If answer = vbNo Then WScript.Quit 0

' ポート 8503 を使用しているプロセスを終了
oShell.Run "cmd /c FOR /F ""tokens=5"" %a IN ('netstat -aon ^| findstr :8503') DO taskkill /F /PID %a", _
           0, True

MsgBox "ハコ割り生成ツールを停止しました。", vbInformation, "ハコ割り生成ツール"
