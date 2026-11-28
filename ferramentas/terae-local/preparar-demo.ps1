# Deixa a demonstração do app integrado ao Terae web LOCAL pronta, num comando só (rode ~10 min antes):
#   1. sobe o que faltar do Terae local (Postgres, Mailpit, API, worker, clínica sem senha :5201 e :5202);
#   2. liga o emulador Terae_Pixel e confere se o app instalado é o da fonte local (instala só se não for,
#      porque reinstalar faz a Rosa perder o "confiar neste aparelho");
#   3. abre no navegador o Mailpit, o programa em casa da Alice (:5201) e a caixa da clínica (:5202);
#   4. abre o painel do back (o que o app grava no banco, ao vivo) numa janela à parte;
#   5. mostra a cota de códigos de cada persona.
#
# Uso (na pasta terae_app):  .\ferramentas\terae-local\preparar-demo.ps1
#                            .\ferramentas\terae-local\preparar-demo.ps1 -SemNavegador
param([switch]$SemNavegador)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Resolve-Path (Join-Path $aqui '..\..')
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$kit = Join-Path $env:USERPROFILE 'OneDrive\Documentos\Faculdade\Dispositivos Moveis\atividade5\demo'
$apkLocal = Join-Path $kit 'terae_app-demo-local.apk'
$pacote = 'br.edu.unemat.terae_app'
function Passo($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function Escutando($porta) { [bool](Get-NetTCPConnection -State Listen -LocalPort $porta -ErrorAction SilentlyContinue) }

Passo '1. Terae web local'
& (Join-Path $aqui 'subir-terae-local.ps1') -Subir | Out-Host
$portas = 3000, 8025, 5201, 5202
$limite = (Get-Date).AddMinutes(3)
while (($portas | Where-Object { -not (Escutando $_) }) -and (Get-Date) -lt $limite) { Start-Sleep 3 }
$faltam = $portas | Where-Object { -not (Escutando $_) }
if ($faltam) { Write-Host "  AINDA FORA: portas $($faltam -join ', '). Olhe as janelas do Git Bash." -ForegroundColor Red }
else { Write-Host '  ok    API :3000, Mailpit :8025, terapeuta :5201 e coordenação :5202 de pé' -ForegroundColor Green }
Write-Host '  (a SPA :5173 pede TOTP e não é usada na demo: a janela dela pode ficar aberta ou ser fechada)' -ForegroundColor DarkGray

Passo '2. Emulador e app da fonte local'
$ligado = ((& $adb devices) -match 'emulator-\d+\s+device')
if (-not $ligado) {
  $emulador = Join-Path $env:LOCALAPPDATA 'Android\Sdk\emulator\emulator.exe'
  Start-Process -FilePath $emulador -ArgumentList '-avd', 'Terae_Pixel' | Out-Null
  Write-Host '  ...   abrindo o Terae_Pixel (1 a 2 minutos)'
  $limite = (Get-Date).AddMinutes(5)
  do { Start-Sleep 3; $boot = ((& $adb shell getprop sys.boot_completed 2>$null) -join '').Trim() } until ($boot -eq '1' -or (Get-Date) -gt $limite)
}
$caminho = ((& $adb shell pm path $pacote 2>$null) -join '') -replace '^package:', ''
$md5Instalado = if ($caminho) { (((& $adb shell md5sum $caminho.Trim()) -join '') -split '\s+')[0] } else { '' }
$md5Kit = (Get-FileHash -Algorithm MD5 $apkLocal).Hash.ToLower()
if ($md5Instalado -eq $md5Kit) {
  Write-Host '  ok    o app instalado é o da fonte local (não reinstalei: a Rosa continua confiável, se estava)' -ForegroundColor Green
} else {
  Write-Host '  ...   o app instalado não é o da fonte local; instalando pelo kit (a Rosa vai pedir código)' -ForegroundColor Yellow
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit 'instalar-no-emulador.ps1') -Fonte local | Out-Host
}
& $adb shell monkey -p $pacote -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null

Passo '3. Navegador (front)'
if (-not $SemNavegador) {
  Start-Process 'http://127.0.0.1:8025'
  Start-Process 'http://localhost:5201/prontuario/01a219cc-f0e1-7000-9df3-39554ee6875d/programa'
  Start-Process 'http://localhost:5201/caixa-de-entrada'
  Start-Process 'http://localhost:5202/caixa-de-entrada'
  Write-Host '  ok    Mailpit, programa da Alice e caixa de entrada (:5201) e caixa da clínica (:5202) abertos'
}

Passo '4. Painel do back'
Start-Process powershell -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $aqui 'painel-do-back.ps1')
Write-Host '  ok    painel aberto numa janela à parte (Ctrl+C fecha)'

Passo '5. Cota de códigos (10 por conta em 24 h, 5 por hora)'
foreach ($p in @(@('Laura', 'paciente-adulta'), @('Rosa', 'cuidador-alice'), @('Mariana', 'responsavel-alice'))) {
  $linha = docker exec infra-postgres-1 psql -X -At -U postgres -d terae_app_local -c ("select count(*), " +
    "coalesce(to_char((min(criado_em)+interval '24 hours') at time zone 'America/Cuiaba','DD/MM HH24:MI'),'-') " +
    "from codigo_de_acesso where id_usuario=(select id from usuario where email='$($p[1])@homologacao.terae.invalid') " +
    "and criado_em>now()-interval '24 hours';")
  $n, $volta = "$linha".Split('|')
  Write-Host ("  {0,-8} {1,2} de 10 usados · {2} livres · o mais antigo libera em {3}" -f $p[0], $n, (10 - [int]$n), $volta)
}
Write-Host "`nPronto. Roteiro: atividade5\apresentacao\roteiro-da-demo.md (e terae_app\docs\demo-integracao.md)." -ForegroundColor Green
