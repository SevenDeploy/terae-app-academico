# Entra no app (já instalado no emulador, fonte local) como uma persona do Terae local: abre o app, digita e-mail e
# senha, espera o e-mail do código, lê o código no Mailpit e digita. Senha e código nunca são impressos nem gravados;
# a captura só é tirada DEPOIS do login (a tela do código mostra o código digitado).
#
# Uso: .\ferramentas\terae-local\entrar-no-emulador.ps1                   (Mariana, a mãe da Alice)
#      .\ferramentas\terae-local\entrar-no-emulador.ps1 -Persona rosa     (cuidadora)
#      .\ferramentas\terae-local\entrar-no-emulador.ps1 -Persona laura    (paciente adulta)
#      -Confiar   marca "Confiar neste aparelho por 30 dias" (a próxima entrada pula o código; o "Sair" esquece)
#
# Cada entrada gasta UM código da conta (tetos: 5 por hora e 10 por 24 h, ver docs/roteiro-de-amanha.md). O script
# confere isso no banco antes e para sem gastar nada se não houver cota.
#
# As coordenadas são do emulador Terae_Pixel (1080x2400). Só localhost/emulador: nada aqui toca a produção.
param(
  [ValidateSet('mariana', 'rosa', 'laura')][string]$Persona = 'mariana',
  [switch]$Confiar,
  [string]$Captura = (Join-Path $env:TEMP 'terae-entrada.png')
)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$ajudante = Join-Path $PSScriptRoot 'credenciais-da-persona.mjs'
$pacote = 'br.edu.unemat.terae_app'

# Posições (px do aparelho, 1080x2400).
$toque = @{
  Entrar = '540 1470'     # botão da capa
  Email = '540 770'
  Senha = '540 965'
  Continuar = '540 1150'
  PrimeiraCaixa = '125 908'
  Confiar = '552 1222'    # o texto "Confiar neste aparelho por 30 dias" (a caixinha fica sob a barra do teclado)
  EntrarComCodigo = '540 1584'
}
function Tocar($nome) { & $adb shell input tap ($toque[$nome] -split ' ') }

function Falha($texto) { Write-Host "  PARAR $texto" -ForegroundColor Yellow; exit 1 }

# 0. O que precisa estar de pé.
if (-not (& $adb devices | Select-String 'emulator-\d+\s+device')) { Falha 'emulador desligado (.\ferramentas\app-android.ps1 liga)' }
try { Invoke-WebRequest -Uri 'http://127.0.0.1:3000/api/saude' -UseBasicParsing -TimeoutSec 4 | Out-Null } catch { Falha 'API :3000 fora do ar (.\ferramentas\terae-local\subir-terae-local.ps1 -Subir)' }
try { Invoke-WebRequest -Uri 'http://127.0.0.1:8025/api/v1/info' -UseBasicParsing -TimeoutSec 4 | Out-Null } catch { Falha 'Mailpit :8025 fora do ar' }

# 1. Cota de códigos da conta (nada é gasto se não houver).
$email = & node $ajudante email $Persona
$consulta = "select count(*), count(*) filter (where criado_em > now()-interval '1 hour'), to_char((min(criado_em)+interval '24 hours') at time zone 'America/Cuiaba','DD/MM HH24:MI') from codigo_de_acesso where id_usuario=(select id from usuario where email='$email') and criado_em > now()-interval '24 hours';"
$linha = (& docker exec infra-postgres-1 psql -X -At -U postgres -d terae_app_local -c $consulta) -join ''
$partes = $linha -split '\|'
$em24h = [int]$partes[0]; $naHora = [int]$partes[1]
Write-Host "  $Persona`: $em24h código(s) em 24 h, $naHora na última hora (tetos 10 e 5)"
if ($em24h -ge 10) { Falha "sem cota: $Persona só libera outro código às $($partes[2]) (horário de Cuiabá). Use outra persona." }
if ($naHora -ge 5) { Falha "sem cota na hora: espere uma hora. Use outra persona." }

# 2. A senha só passa por esta variável, direto para o adb (nunca é mostrada).
$senha = & node $ajudante senha $Persona
if ($senha -notmatch '^[A-Za-z0-9._@+-]+$') { Falha 'a senha tem caracteres que o `adb input text` não digita com segurança: digite à mão' }

# 3. Abre o app do zero e entra.
& $adb shell am force-stop $pacote
& $adb shell monkey -p $pacote -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
Start-Sleep -Seconds 6
Tocar 'Entrar'; Start-Sleep -Seconds 2
Tocar 'Email'; Start-Sleep -Seconds 1; & $adb shell input text $email; Start-Sleep -Seconds 1
Tocar 'Senha'; Start-Sleep -Seconds 1; & $adb shell input text $senha; Start-Sleep -Seconds 1
Remove-Variable senha
& $adb shell input keyevent 4; Start-Sleep -Seconds 1

# 4. Pede o código (só depois de anotar qual era o e-mail mais novo, para não pegar um código velho).
$antes = & node $ajudante ultimo-id $Persona
Tocar 'Continuar'
$codigo = $null
for ($i = 0; $i -lt 20 -and -not $codigo; $i++) {
  Start-Sleep -Seconds 2
  $codigo = & node $ajudante codigo $Persona $antes 2>$null
  if ($LASTEXITCODE -ne 0) { $codigo = $null }
}
if (-not $codigo) { Falha 'o e-mail do código não chegou em 40 s (confira o worker e a senha da persona)' }

# 5. Digita o código e entra.
Tocar 'PrimeiraCaixa'; Start-Sleep -Seconds 1; & $adb shell input text $codigo; Remove-Variable codigo
Start-Sleep -Seconds 2
if ($Confiar) { Tocar 'Confiar'; Start-Sleep -Seconds 1 }
Tocar 'EntrarComCodigo'
Start-Sleep -Seconds 10

# 6. Só agora a captura (não mostra mais senha nem código).
# (o pipe do PowerShell estraga binário: a captura vai para o aparelho e volta por `adb pull`)
& $adb shell screencap -p /sdcard/terae-entrada.png
& $adb pull /sdcard/terae-entrada.png $Captura 2>&1 | Out-Null
& $adb shell rm /sdcard/terae-entrada.png
Write-Host "  ok    entrou como $Persona. Captura: $Captura" -ForegroundColor Green
