# Abre o app acadêmico no navegador (Flutter Web), só para visualizar: o alvo do app é o Android.
# Uso: .\ferramentas\app-web.ps1                  (gera o build e serve em http://localhost:8090)
#      .\ferramentas\app-web.ps1 -Desenvolvimento (abre no Chrome com hot reload)
param([switch]$Desenvolvimento, [int]$Porta = 8090)

$ErrorActionPreference = 'Stop'
$flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) { 'flutter' } else { 'C:\src\flutter\bin\flutter.bat' }
Set-Location (Split-Path -Parent $PSScriptRoot)

if ($Desenvolvimento) {
  & $flutter run -d chrome
} else {
  & $flutter build web --release
  $env:PORTA = "$Porta"
  node ferramentas\servir-web.mjs
}
