# Confere (e, com -Subir, sobe) o Terae web LOCAL que o app consome em TERAE_FONTE=local.
# Só localhost: nada aqui aponta para a produção. Não guarda nem imprime segredo (as senhas ficam no
# .credenciais/contas-de-dev.json do terae, fora dos dois repositórios).
#
# Uso: .\ferramentas\terae-local\subir-terae-local.ps1                 (só confere e diz o que falta)
#      .\ferramentas\terae-local\subir-terae-local.ps1 -Subir          (liga os contêineres e abre o que falta, cada um numa janela)
#      .\ferramentas\terae-local\subir-terae-local.ps1 -Terae D:\terae (outro caminho do monorepo)
param(
  [switch]$Subir,
  [string]$Terae = (Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'terae')
)

$ErrorActionPreference = 'Continue'
$falta = New-Object System.Collections.Generic.List[string]
function Ok($texto) { Write-Host "  ok    $texto" -ForegroundColor Green }
function Falta($texto) { Write-Host "  FALTA $texto" -ForegroundColor Yellow; $falta.Add($texto) }
function Escutando($porta) {
  [bool](Get-NetTCPConnection -State Listen -LocalPort $porta -ErrorAction SilentlyContinue)
}
function ProcessoNode($padrao) {
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match $padrao } | Select-Object -First 1
}
$bash = 'C:\Program Files\Git\bin\bash.exe'
function AbrirNoBash($titulo, $comando) {
  # Cada processo carrega o .env no próprio shell (README do terae, "Modo API"): a API e os Vite não leem o arquivo.
  $linha = "cd '$($Terae -replace '\\','/')' && set -a && . ./.env && set +a && echo '== $titulo' && $comando"
  Start-Process -FilePath $bash -ArgumentList '-lc', "`"$linha`"" | Out-Null
  Write-Host "  ...   abrindo: $titulo" -ForegroundColor Cyan
}

Write-Host "Terae local para o app (monorepo: $Terae)"

# 1. Monorepo e .env
if (-not (Test-Path (Join-Path $Terae 'package.json'))) { Falta "monorepo do terae em $Terae (use -Terae)"; exit 1 }
$env_ = Join-Path $Terae '.env'
if (-not (Test-Path $env_)) {
  Falta ".env do terae: copie o .env.exemplo, gere CHAVE_DADOS_V1 e SENHA_DAS_CONTAS_DE_DEMONSTRACAO (LEIA-ME, passo 2)"
} else {
  $linhas = Get-Content $env_
  $banco = ($linhas | Where-Object { $_ -match '^DATABASE_URL=' }) -replace '.*/', ''
  if ($banco -eq 'terae_app_local') { Ok ".env aponta para o banco terae_app_local" } else { Falta ".env aponta para o banco '$banco' (esperado terae_app_local)" }
  if ($linhas -match '^CHAVE_DADOS_V1=.+') { Ok 'CHAVE_DADOS_V1 preenchida' } else { Falta 'CHAVE_DADOS_V1 vazia no .env' }
  if ($linhas -match '^NODE_ENV=development') { Ok 'NODE_ENV=development' } else { Falta 'NODE_ENV não é development' }
}
if (Test-Path (Join-Path $Terae '.credenciais\contas-de-dev.json')) { Ok 'contas-de-dev.json existe (senhas ficam lá)' } else { Falta 'contas de demonstração (LEIA-ME, passo 3)' }

# 2. Docker e contêineres do terae (só os dois; os de outros projetos não são tocados)
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Falta 'Docker Desktop parado: abra o Docker Desktop e rode de novo'
} else {
  Ok 'Docker respondendo'
  foreach ($nome in 'infra-postgres-1', 'infra-mailpit-1') {
    $estado = docker inspect -f '{{.State.Status}}' $nome 2>$null
    if ($estado -eq 'running') { Ok "$nome rodando" }
    elseif ($Subir -and $estado) { docker start $nome | Out-Null; Write-Host "  ...   $nome ligado" -ForegroundColor Cyan }
    else { Falta "$nome ($(if ($estado) { $estado } else { 'não existe' })): docker start $nome" }
  }
  $temBanco = docker exec infra-postgres-1 psql -U postgres -tAc "select 1 from pg_database where datname='terae_app_local'" 2>$null
  if ($temBanco -match '1') { Ok 'banco terae_app_local existe' } else { Falta 'banco terae_app_local (LEIA-ME, passo 2)' }
}

# 3. Processos
$api = Escutando 3000
if ($api) {
  try { $s = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 http://127.0.0.1:3000/api/saude; Ok "API em :3000 (saúde $($s.StatusCode))" }
  catch { Falta 'API escuta em :3000, mas /api/saude não respondeu 200' }
} elseif ($Subir) { AbrirNoBash 'API :3000' 'pnpm --filter @terae/api dev' } else { Falta 'API em :3000: pnpm --filter @terae/api dev' }

if (ProcessoNode 'src[/\\]worker\.ts') { Ok 'worker rodando (o código do portal sai por e-mail)' }
elseif ($Subir) { AbrirNoBash 'worker' 'pnpm --filter @terae/api worker' }
else { Falta 'worker: pnpm --filter @terae/api worker (sem ele o código de acesso não chega ao Mailpit)' }

if (Escutando 5173) { Ok 'SPA da clínica em http://localhost:5173' }
elseif ($Subir) { AbrirNoBash 'web :5173' 'VITE_MODO=api pnpm --filter @terae/web dev' }
else { Falta 'SPA da clínica em :5173: VITE_MODO=api pnpm --filter @terae/web dev' }

if (Escutando 5175) { Ok 'portal web em http://portal.localhost:5175' }
elseif ($Subir) { AbrirNoBash 'portal :5175' 'pnpm --filter @terae/portal dev' }
else { Falta 'portal em :5175: pnpm --filter @terae/portal dev' }

foreach ($p in @(@{ Porta = 5201; Perfil = 'terapeuta' }, @{ Porta = 5202; Perfil = 'coordenação' })) {
  if (Escutando $p.Porta) { Ok "atalho de dev ($($p.Perfil)) em http://localhost:$($p.Porta)" }
  else { Write-Host "  opc.  atalho de dev ($($p.Perfil)) em :$($p.Porta) desligado (LEIA-ME, 'Atalho sem senha')" -ForegroundColor DarkGray }
}

if (Escutando 8025) { Ok 'Mailpit em http://127.0.0.1:8025' } else { Falta 'Mailpit em :8025' }

# 4. O caminho do emulador: 10.0.2.2 é o loopback do host; a API precisa aceitar o Host do portal.
if ($api) {
  try {
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Method Post -Uri http://127.0.0.1:3000/api/portal/sessoes `
      -Headers @{ Host = 'portal.localhost'; 'X-Terae-Cliente' = 'conferencia' } -ContentType 'application/json' `
      -Body '{"email":"ninguem@exemplo.invalid","senha":"conferencia-sem-conta-1"}' | Out-Null
    Falta 'POST /api/portal/sessoes aceitou credencial inexistente (esperado 401)'
  } catch {
    $codigo = [int]$_.Exception.Response.StatusCode
    if ($codigo -eq 401) { Ok 'rota do portal responde pelo Host portal.localhost (401 para conta inexistente)' }
    else { Falta "rota do portal devolveu $codigo (404 = Host errado; 403 = falta X-Terae-Cliente)" }
  }
}

Write-Host ''
if ($falta.Count -eq 0) {
  Write-Host 'Tudo de pé. No app: flutter run --dart-define=TERAE_FONTE=local --dart-define=TERAE_LOCAL_URL=http://10.0.2.2:3000' -ForegroundColor Green
} else {
  Write-Host "Falta: $($falta.Count) item(ns). Veja ferramentas\terae-local\LEIA-ME.md." -ForegroundColor Yellow
  exit 1
}
