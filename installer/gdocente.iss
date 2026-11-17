; Instalador de GDocente para Windows (Inno Setup 6).
; No compilar a mano: usar tools\crear_instalador.ps1, que compila la app,
; lee la versión de pubspec.yaml y pasa las rutas correctas.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\build\windows\x64\runner\Release"
#endif
#ifndef VcRuntimeDir
  #error "Falta VcRuntimeDir (carpeta Microsoft.VC14x.CRT de Visual Studio)"
#endif

[Setup]
; AppId identifica la app para actualizar/desinstalar: NO cambiarlo nunca.
AppId={{3075985A-806D-4076-8E90-8C0CD7891D16}
AppName=GDocente
AppVersion={#AppVersion}
AppVerName=GDocente {#AppVersion}
AppPublisher=Hermann Luciano
; Instalación por usuario: no pide permisos de administrador.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\GDocente
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\dist
OutputBaseFilename=GDocente-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\gdocente.exe
UninstallDisplayName=GDocente
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
; Si la app está abierta, la cierra para poder actualizarla.
CloseApplications=force

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "escritorio"; Description: "Crear un acceso directo en el escritorio"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Bibliotecas de Visual C++ junto a la app: así funciona aunque la PC no
; tenga instalado el "Visual C++ Redistributable".
Source: "{#VcRuntimeDir}\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VcRuntimeDir}\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#VcRuntimeDir}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\GDocente"; Filename: "{app}\gdocente.exe"
Name: "{autodesktop}\GDocente"; Filename: "{app}\gdocente.exe"; Tasks: escritorio

[Run]
Filename: "{app}\gdocente.exe"; Description: "Abrir GDocente"; Flags: nowait postinstall skipifsilent

; Los datos (alumnos, notas, etc.) están en %APPDATA%\Hermann Luciano\GDocente
; y NO se borran al desinstalar ni al actualizar.
