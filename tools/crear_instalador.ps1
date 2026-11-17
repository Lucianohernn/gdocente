# Arma el instalador de Windows: dist\GDocente-Setup-<versión>.exe
# Uso (desde la carpeta del proyecto):
#   powershell -ExecutionPolicy Bypass -File tools\crear_instalador.ps1
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

# Versión visible desde pubspec.yaml (ej.: "version: 1.3.0+6" -> 1.3.0)
$linea = Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)' | Select-Object -First 1
if (-not $linea) { throw 'No se encontró la versión en pubspec.yaml' }
$version = $linea.Matches[0].Groups[1].Value

# Compilador de Inno Setup
$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'No se encontró Inno Setup 6 (ISCC.exe)' }

# Bibliotecas de Visual C++ (x64) de la instalación de Visual Studio
$vc = Get-ChildItem "$env:ProgramFiles\Microsoft Visual Studio" -Recurse -Directory -Filter 'Microsoft.VC14*.CRT' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\Redist\\MSVC\\[^\\]+\\x64\\' } |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $vc) { throw 'No se encontraron las DLL de Visual C++ (x64) en Visual Studio' }

Write-Host "Compilando GDocente $version para Windows..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Falló flutter build windows' }

Write-Host 'Armando el instalador...'
& $iscc "/DAppVersion=$version" "/DVcRuntimeDir=$($vc.FullName)" 'installer\gdocente.iss'
if ($LASTEXITCODE -ne 0) { throw 'Falló Inno Setup' }

Write-Host "Listo: dist\GDocente-Setup-$version.exe"
