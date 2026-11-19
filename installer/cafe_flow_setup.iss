; Script for Qodex CafeFlow
; Inno Setup 6 Script for Qodex CafeFlow Windows Application

#define MyAppName "Qodex CafeFlow"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Qodex Software"
#define MyAppExeName "cafe_flow.exe"
#define MyAppIcon "..\windows\runner\resources\app_icon.ico"
#define MySourceDir "..\build\windows\x64\runner\Release"
#define MyOutputDir "..\build\installer"

[Setup]
; Unique application GUID for updates & uninstalls
AppId={{A78C5B9E-3D2F-4A61-8C10-E5D619F47B2A}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Modern visual installer styling
WizardStyle=modern
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir={#MyOutputDir}
OutputBaseFilename=QodexCafeFlow_Setup_v1.0.0
Compression=lzma2/max
SolidCompression=yes
; Allows user to choose between installing for current user or all users (administrator)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
DisableDirPage=no
DisableProgramGroupPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main application binaries, assets, and flutter/plugin dlls
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Agreement & License documentation
Source: "..\SOFTWARE_AGREEMENT.html"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\SOFTWARE_AGREEMENT.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Start Menu shortcuts
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; Desktop shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Option to launch the app immediately after setup completes
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
