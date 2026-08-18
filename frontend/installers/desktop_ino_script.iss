; ============================================================
; Anything EMR - Production Installer
; ============================================================

#define MyAppName "Anything EMR"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Anything Ventures"
#define MyAppURL "https://anythingventures.in/"
#define MyAppExeName "AnythingEMR.exe"

[Setup]

; IMPORTANT:
; Keep this AppId unchanged for future updates of the same application.
AppId={{8A78E223-B3A0-4010-BFAB-FC2B9DB461D3}

AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}

AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Install location
DefaultDirName={autopf}\{#MyAppName}

; Start Menu
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Uninstaller
UninstallDisplayIcon={app}\{#MyAppExeName}

; Windows architecture
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Installer behaviour
UsePreviousAppDir=yes
DisableDirPage=no

; Run as administrator because application is installed under Program Files
PrivilegesRequired=admin

; Installer appearance
WizardStyle=modern
WizardResizable=yes

; Compression
SolidCompression=yes
Compression=lzma2

; Installer output
OutputDir="D:\Works\Clinic EHR System\emr\frontend\installers"
OutputBaseFilename=Anything-EMR-Setup-{#MyAppVersion}

; Application icon
SetupIconFile="D:\Works\Clinic EHR System\emr\frontend\windows\runner\resources\app_icon.ico"

; Uninstaller settings
Uninstallable=yes

; ============================================================
; Languages
; ============================================================

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

; ============================================================
; Tasks
; ============================================================

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

; ============================================================
; Application Files
; ============================================================

[Files]

; Main executable
Source: "D:\Works\Clinic EHR System\emr\frontend\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; DLL files
Source: "D:\Works\Clinic EHR System\emr\frontend\build\windows\x64\runner\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Flutter application data
Source: "D:\Works\Clinic EHR System\emr\frontend\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ Redistributable
Source: "D:\Works\Clinic EHR System\emr\frontend\installers\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; ============================================================
; Shortcuts
; ============================================================

[Icons]

; Start Menu shortcut
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

; Desktop shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; ============================================================
; Installation / First Run
; ============================================================

[Run]

; Install Microsoft Visual C++ Runtime
Filename: "{tmp}\vcredist_x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ Runtime..."; Flags: waituntilterminated

; Launch application after installation
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent