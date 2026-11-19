[Setup]
AppName=Qodex CafeFlow
AppVersion=1.0.0
AppPublisher=Qodex Software
DefaultDirName={autopf}\QodexCafeFlow
DefaultGroupName=Qodex CafeFlow
OutputDir=build\installer
OutputBaseFilename=QodexCafeFlow_Setup_v1.0.0
Compression=lzma2/max
SolidCompression=yes
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\cafe_flow.exe
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Qodex CafeFlow"; Filename: "{app}\cafe_flow.exe"
Name: "{autodesktop}\Qodex CafeFlow"; Filename: "{app}\cafe_flow.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\cafe_flow.exe"; Description: "Launch Qodex CafeFlow"; Flags: nowait postinstall skipifsilent
