# Crea la clave propia de GDocente (se hace UNA sola vez) y el archivo
# android/key.properties que usa Gradle para firmar la app.
#
# Ejecutar desde la carpeta del proyecto:
#   powershell -ExecutionPolicy Bypass -File tools\crear_clave.ps1
#
# IMPORTANTE: guardá una copia de la carpeta de la clave y de la contraseña
# en un lugar seguro (Drive, pendrive). Si se pierden, no vas a poder publicar
# actualizaciones que se instalen encima de la app que ya tienen los docentes.

$ErrorActionPreference = 'Stop'

$proyecto   = Split-Path -Parent $PSScriptRoot
$carpeta    = Join-Path (Split-Path -Parent $proyecto) 'gdocente-clave'
$archivoJks = Join-Path $carpeta 'gdocente.jks'
$propsPath  = Join-Path $proyecto 'android\key.properties'
$alias      = 'gdocente'
$keytool    = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'

if (-not (Test-Path $keytool)) {
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { throw 'No se encontró keytool (viene con Android Studio).' }
    $keytool = $cmd.Source
}

if (Test-Path $archivoJks) {
    Write-Host "Ya existe una clave en $archivoJks. No se crea otra para no reemplazarla." -ForegroundColor Yellow
    Write-Host 'Si necesitás regenerar key.properties, borralo y escribilo a mano (ver README).'
    exit 1
}

Write-Host ''
Write-Host 'Elegí una contraseña para la clave de GDocente.' -ForegroundColor Cyan
Write-Host '- Mínimo 6 caracteres, solo letras sin acentos, números y símbolos comunes.'
Write-Host '- No uses la barra invertida (\).'
Write-Host '- Anotala en un lugar seguro: no se puede recuperar.'
Write-Host ''

while ($true) {
    $s1 = Read-Host 'Contraseña' -AsSecureString
    $s2 = Read-Host 'Repetí la contraseña' -AsSecureString
    $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s1))
    $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s2))
    if ($p1 -ne $p2)              { Write-Host 'No coinciden. Probá de nuevo.' -ForegroundColor Red; continue }
    if ($p1.Length -lt 6)         { Write-Host 'Tiene que tener al menos 6 caracteres.' -ForegroundColor Red; continue }
    if ($p1 -match '[^\x21-\x7E]') { Write-Host 'Usá solo letras sin acentos, números y símbolos (sin espacios).' -ForegroundColor Red; continue }
    if ($p1.Contains('\'))        { Write-Host 'No uses la barra invertida (\).' -ForegroundColor Red; continue }
    break
}

New-Item -ItemType Directory -Force $carpeta | Out-Null

& $keytool -genkeypair -v `
    -keystore $archivoJks -storetype PKCS12 `
    -alias $alias -keyalg RSA -keysize 2048 -validity 10000 `
    -dname 'CN=GDocente, O=GDocente, C=AR' `
    -storepass $p1 -keypass $p1 | Out-Null

if (-not (Test-Path $archivoJks)) { throw 'keytool no pudo crear la clave.' }

# key.properties en ASCII sin BOM (Java lo lee como ISO-8859-1).
$jksGradle = $archivoJks -replace '\\', '/'
$contenido = @(
    "storePassword=$p1",
    "keyPassword=$p1",
    "keyAlias=$alias",
    "storeFile=$jksGradle"
) -join "`n"
[IO.File]::WriteAllText($propsPath, $contenido + "`n", [Text.Encoding]::ASCII)

$p1 = $null; $p2 = $null

Write-Host ''
Write-Host 'Listo.' -ForegroundColor Green
Write-Host "  Clave:           $archivoJks"
Write-Host "  Configuración:   $propsPath"
Write-Host ''
Write-Host 'Ahora guardá una copia de la carpeta' -NoNewline
Write-Host " $carpeta " -ForegroundColor Yellow -NoNewline
Write-Host 'y de la contraseña en un lugar seguro.'
