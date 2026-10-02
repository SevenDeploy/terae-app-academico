# Abre o app acadêmico no emulador Android (Terae_Pixel), com hot reload.
# Uso: .\ferramentas\app-android.ps1            (roda em modo desenvolvimento)
#      .\ferramentas\app-android.ps1 -Apk       (só instala e abre o APK de depuração já gerado)
param([switch]$Apk)

$ErrorActionPreference = 'Stop'
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulador = Join-Path $sdk 'emulator\emulator.exe'
$flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) { 'flutter' } else { 'C:\src\flutter\bin\flutter.bat' }
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (& $adb devices | Select-String 'emulator-\d+\s+device')) {
  Write-Host 'Ligando o emulador Terae_Pixel...'
  Start-Process -FilePath $emulador -ArgumentList '-avd', 'Terae_Pixel', '-no-boot-anim'
  & $adb wait-for-device
  do { Start-Sleep -Seconds 2; $pronto = (& $adb shell getprop sys.boot_completed) -join '' } until ($pronto -match '1')
}

if ($Apk) {
  $arquivo = 'build\app\outputs\flutter-apk\app-debug.apk'
  if (-not (Test-Path $arquivo)) { & $flutter build apk --debug }
  & $adb install -r $arquivo
  & $adb shell monkey -p br.edu.unemat.terae_app -c android.intent.category.LAUNCHER 1 | Out-Null
  Write-Host 'App aberto no emulador.'
} else {
  & $flutter run -d emulator-5554
}
