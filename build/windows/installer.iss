; ハコ割り生成ツール インストーラー（スタンドアロン版 / Docker 不要）
; Inno Setup 6 (UTF-8 BOM 付きで保存)
; ビルド方法: build.ps1 を実行してください（Inno Setup も自動呼び出し）

#define AppName "ハコ割り生成ツール"
#define AppVersion "1.1.0"
#define AppPublisher "ハコ割り生成ツール"

[Setup]
AppId={{F3A7D812-6C4B-4E9F-B2A1-D0E5C8F91234}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\HakoSRTTool
DefaultGroupName={#AppName}
AllowNoIcons=no
OutputDir=..\..\dist\windows
OutputBaseFilename=ハコ割り生成ツール_setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
DisableProgramGroupPage=no
UninstallDisplayName={#AppName}
ChangesEnvironment=no
ShowLanguageDialog=no

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Messages]
WelcomeLabel1=ハコ割り生成ツール セットアップ
WelcomeLabel2=音声・映像ファイルとハコ割りテキストから%nSRTファイルを自動生成するツールです。%n%nPython・ffmpeg・Whisper AI モデル（turbo）をすべて同梱しているため%nDocker Desktop は不要で、インストール後すぐに使い始めることができます。%n%nセットアップを続けるには「次へ」をクリックしてください。
FinishedLabel=ハコ割り生成ツールのインストールが完了しました。%n%nデスクトップの「ハコ割り生成ツール 起動」をダブルクリックすると%n自動でブラウザが開きます。

[Tasks]
Name: "desktopicon"; Description: "デスクトップにショートカットを作成（起動・停止）"; GroupDescription: "追加タスク:"

[Files]
; Python 3.11 embeddable（パッケージ含む）
Source: "dist\python\*";              DestDir: "{app}\python";            Flags: recursesubdirs ignoreversion
; ffmpeg バイナリ
Source: "dist\tools\ffmpeg\bin\*";    DestDir: "{app}\tools\ffmpeg\bin";  Flags: ignoreversion
; Whisper AI モデル（turbo / 同梱のため初回 DL 不要）
Source: "dist\models\whisper\*";      DestDir: "{app}\models\whisper";    Flags: ignoreversion
; アプリスクリプト
Source: "dist\scripts\*";             DestDir: "{app}\scripts";           Flags: recursesubdirs ignoreversion
Source: "dist\.streamlit\*";          DestDir: "{app}\.streamlit";        Flags: recursesubdirs ignoreversion
; ランチャー
Source: "dist\起動.vbs";              DestDir: "{app}";                   Flags: ignoreversion
Source: "dist\停止.vbs";              DestDir: "{app}";                   Flags: ignoreversion
; マニュアル
Source: "dist\docs\*";                DestDir: "{app}\docs";              Flags: recursesubdirs ignoreversion

[Icons]
; スタートメニュー
Name: "{group}\ハコ割り生成ツール 起動"; Filename: "wscript.exe"; Parameters: """{app}\起動.vbs"""; WorkingDir: "{app}"
Name: "{group}\ハコ割り生成ツール 停止"; Filename: "wscript.exe"; Parameters: """{app}\停止.vbs"""; WorkingDir: "{app}"
Name: "{group}\マニュアル";              Filename: "{app}\docs\マニュアル.html"
Name: "{group}\クイックセットアップ";     Filename: "{app}\docs\クイックセットアップ.html"
Name: "{group}\アンインストール";         Filename: "{uninstallexe}"
; デスクトップ
Name: "{userdesktop}\ハコ割り生成ツール 起動"; Filename: "wscript.exe"; Parameters: """{app}\起動.vbs"""; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userdesktop}\ハコ割り生成ツール 停止"; Filename: "wscript.exe"; Parameters: """{app}\停止.vbs"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "wscript.exe"; Parameters: """{app}\起動.vbs"""; Description: "ハコ割り生成ツールを今すぐ起動する"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "cmd.exe"; Parameters: "/c FOR /F ""tokens=5"" %a IN ('netstat -aon ^| findstr :8503') DO taskkill /F /PID %a"; Flags: runhidden waituntilterminated; RunOnceId: "StopStreamlit"
