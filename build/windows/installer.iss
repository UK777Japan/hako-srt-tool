; ハコ割り生成ツール インストーラー
; Inno Setup 6 (UTF-8 BOM 付きで保存してください)
; ビルド方法: Inno Setup をインストールし、このファイルを右クリック → Compile

#define AppName "ハコ割り生成ツール"
#define AppVersion "1.0.0"
#define AppPublisher "ハコ割り生成ツール"
#define AppExeName "start.bat"

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
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
DisableProgramGroupPage=no
UninstallDisplayName={#AppName}
ChangesEnvironment=no
; 日本語インストーラー
ShowLanguageDialog=no

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Messages]
; 日本語メッセージのカスタマイズ
WelcomeLabel1=ハコ割り生成ツール セットアップ
WelcomeLabel2=音声・映像ファイルとハコ割りテキストから%nSRTファイルを自動生成するツールです。%n%nセットアップを続けるには「次へ」をクリックしてください。
FinishedLabel=ハコ割り生成ツールのインストールが完了しました。%n%n初回起動時はWhisperモデル（約800MB）のダウンロードが発生するため、%n数分かかります。2回目以降は数秒で起動します。

[Tasks]
Name: "desktopicon"; Description: "デスクトップにショートカットを作成（起動・停止）"; GroupDescription: "追加タスク:"

[Files]
; アプリ本体
Source: "..\..\Dockerfile";            DestDir: "{app}";          Flags: ignoreversion
Source: "..\..\requirements.txt";      DestDir: "{app}";          Flags: ignoreversion
Source: "..\..\scripts\*";             DestDir: "{app}\scripts";    Flags: recursesubdirs ignoreversion; Excludes: "__pycache__,*.pyc"
Source: "..\..\.streamlit\*";          DestDir: "{app}\.streamlit"; Flags: recursesubdirs ignoreversion
; 配布用 docker-compose（scripts マウントなし・OUTPUT_DIR 変数化）
Source: "..\docker-compose.dist.yml";  DestDir: "{app}"; DestName: "docker-compose.yml"; Flags: ignoreversion
; ランチャー
Source: "start.bat";                   DestDir: "{app}";          Flags: ignoreversion
Source: "stop.bat";                    DestDir: "{app}";          Flags: ignoreversion
; マニュアル
Source: "..\..\docs\*";                DestDir: "{app}\docs";     Flags: recursesubdirs ignoreversion

[Icons]
; スタートメニュー
Name: "{group}\ハコ割り生成ツール 起動"; Filename: "{app}\start.bat"; WorkingDir: "{app}"
Name: "{group}\ハコ割り生成ツール 停止"; Filename: "{app}\stop.bat";  WorkingDir: "{app}"
Name: "{group}\マニュアル";              Filename: "{app}\docs\マニュアル.md"
Name: "{group}\クイックセットアップ";     Filename: "{app}\docs\クイックセットアップ.md"
Name: "{group}\アンインストール";         Filename: "{uninstallexe}"
; デスクトップ
Name: "{userdesktop}\ハコ割り生成ツール 起動"; Filename: "{app}\start.bat"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userdesktop}\ハコ割り生成ツール 停止"; Filename: "{app}\stop.bat";  WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\start.bat"; Description: "ハコ割り生成ツールを今すぐ起動する"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent shellexec

[UninstallRun]
Filename: "cmd.exe"; Parameters: "/c docker compose -f ""{app}\docker-compose.yml"" -p hako-srt-tool down"; Flags: runhidden waituntilterminated; RunOnceId: "StopContainer"

[Code]
function InitializeSetup(): Boolean;
var
  DockerDesktop1, DockerDesktop2: String;
begin
  Result := True;
  DockerDesktop1 := ExpandConstant('{pf}\Docker\Docker\Docker Desktop.exe');
  DockerDesktop2 := ExpandConstant('{pf64}\Docker\Docker\Docker Desktop.exe');

  if not FileExists(DockerDesktop1) and not FileExists(DockerDesktop2) then
  begin
    if MsgBox(
      '【重要】Docker Desktop が見つかりません。' + #13#10 + #13#10 +
      'ハコ割り生成ツールの動作には Docker Desktop が必要です。' + #13#10 +
      '先に以下の URL からインストールしてください：' + #13#10 +
      'https://www.docker.com/products/docker-desktop/' + #13#10 + #13#10 +
      'Docker Desktop なしでインストールを続けますか？' + #13#10 +
      '（後からインストールしても動作します）',
      mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
    end;
  end;
end;
