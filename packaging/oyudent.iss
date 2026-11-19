[Setup]
AppId=Oyudent.POS.Desktop
AppName=Oyudent POS
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Oyudent POS
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\oyudent_pos.exe
OutputDir=..\build\installers
OutputBaseFilename=Oyudent-POS-{#AppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#CRTRoot}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userprograms}\Oyudent POS"; Filename: "{app}\oyudent_pos.exe"
