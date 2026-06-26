; Script do Inno Setup para o OpenCode
#define MyAppName "OpenCode"
#define MyAppVersion "beta v1"
#define MyAppPublisher "OpenCode Team"
#define MyAppExeName "opencode.exe"

[Setup]
; Informações básicas do aplicativo
AppId={{D37E84B0-C2B1-4A59-86BC-DF253D32DF99}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={userpf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Configuração de saída (compilação)
OutputDir=installers
#ifndef OutputBaseFilename
  #define OutputBaseFilename "OpenCodeSetup-beta_v1"
#endif
OutputBaseFilename={#OutputBaseFilename}
SetupIconFile=bin\app.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Scripts inicializadores na raiz
Source: "d:\OpenCodePortable\opencode.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "d:\OpenCodePortable\opencode.bat"; DestDir: "{app}"; Flags: ignoreversion

; Subpastas necessárias para a execução
Source: "d:\OpenCodePortable\bin\*"; DestDir: "{app}\bin"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\OpenCodePortable\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\OpenCodePortable\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\OpenCodePortable\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\OpenCodePortable\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\OpenCodePortable\tools\*"; DestDir: "{app}\tools"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\OpenCodePortable\.opencode\*"; DestDir: "{app}\.opencode"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\OpenCodePortable\.brain\*"; DestDir: "{app}\.brain"; Flags: ignoreversion recursesubdirs createallsubdirs


[Icons]
; Atalhos apontando para o launcher do PowerShell
Name: "{group}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\opencode.ps1"""; IconFilename: "{app}\bin\app.ico"; Comment: "Iniciar o OpenCode"
Name: "{autodesktop}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\opencode.ps1"""; IconFilename: "{app}\bin\app.ico"; Tasks: desktopicon; Comment: "Iniciar o OpenCode"
Name: "{group}\Desinstalar {#MyAppName}"; Filename: "{uninstallexe}"; Comment: "Desinstalar o OpenCode"

[Run]
; Opção para iniciar o programa após a instalação
Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\opencode.ps1"""; Flags: postinstall nowait skipifsilent

[Code]
function InitializeSetup(): Boolean;
var
  ResultCode: Integer;
  UninstallExe: String;
  MsgRes: Integer;
begin
  Result := True;
  UninstallExe := '';
  
  // Check if uninstaller exists in Registry (both HKLM and HKCU)
  if RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{D37E84B0-C2B1-4A59-86BC-DF253D32DF99}_is1', 'UninstallString', UninstallExe) then
  begin
    // Found in HKLM
  end
  else if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{D37E84B0-C2B1-4A59-86BC-DF253D32DF99}_is1', 'UninstallString', UninstallExe) then
  begin
    // Found in HKCU
  end;

  if UninstallExe <> '' then
  begin
    // Strip quotes from UninstallString if present
    if Copy(UninstallExe, 1, 1) = '"' then
      UninstallExe := Copy(UninstallExe, 2, Length(UninstallExe) - 2);

    MsgRes := MsgBox('Uma versão anterior do OpenCode já está instalada.' + #13#10 + #13#10 +
                     'Deseja DESINSTALAR a versão anterior antes de continuar?' + #13#10 +
                     '(Clique em "Sim" para desinstalar, "Não" para apenas ATUALIZAR/sobrescrever, ou "Cancelar" para sair).',
                     mbConfirmation, MB_YESNOCANCEL);
    if MsgRes = IDYES then
    begin
      // Run the uninstaller silently
      if Exec(UninstallExe, '/SILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
      begin
        Sleep(1000); // Wait a second for file system to release locks
      end
      else
      begin
        MsgBox('Não foi possível executar a desinstalação automática. Continuando com a instalação...', mbInformation, MB_OK);
      end;
    end
    else if MsgRes = IDCANCEL then
    begin
      Result := False; // Cancel the installation
    end;
  end;
end;
