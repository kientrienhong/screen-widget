; Inno Setup script: packs the whole Flutter release folder (exe, DLLs, data\)
; into one ScreenWidget-Setup.exe.
; Built by tool\build_windows.ps1 -Release -Installer, or by the GitHub workflow.
; Manual build:  iscc /DAppVersion=1.0.0 /DSourceDir=<release folder> windows\installer\screen_widget.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; Keep this AppId forever: it is how Windows recognises updates of the same app.
AppId={{F9BF8034-E6DA-4682-94AA-337788C6400C}
AppName=Screen Widget
AppVersion={#AppVersion}
AppPublisher=Harley
DefaultDirName={localappdata}\Programs\Screen Widget
DefaultGroupName=Screen Widget
DisableProgramGroupPage=yes
; Per-user install: no admin prompt.
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=ScreenWidget-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\screen_widget.exe
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
; Close a running Screen Widget before updating or uninstalling.
CloseApplications=force
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"
Name: "autostart"; Description: "Open Screen Widget automatically when I sign in to Windows"; GroupDescription: "Start-up:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Screen Widget"; Filename: "{app}\screen_widget.exe"
Name: "{group}\Uninstall Screen Widget"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Screen Widget"; Filename: "{app}\screen_widget.exe"; Tasks: desktopicon

[Registry]
; Uninstall always removes the "Launch at login" entry (the app can also create it, see lib/desktop.dart).
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "ScreenWidget"; ValueType: none; Flags: uninsdeletevalue
; Same value the app writes, so the app's "Launch at login" toggle shows it as on.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "ScreenWidget"; ValueType: string; ValueData: """{app}\screen_widget.exe"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\screen_widget.exe"; Description: "Start Screen Widget"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/f /im screen_widget.exe"; Flags: runhidden; RunOnceId: "StopScreenWidget"
