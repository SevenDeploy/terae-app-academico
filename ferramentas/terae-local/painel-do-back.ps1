# Painel do back para a demonstração: mostra, ao vivo e SÓ LENDO, o que o app gravou no Terae web local
# (banco terae_app_local). Serve para provar a integração do lado do servidor enquanto o app é usado no emulador.
#
# Uso (na pasta terae_app):  .\ferramentas\terae-local\painel-do-back.ps1          (atualiza a cada 3 s; Ctrl+C sai)
#                            .\ferramentas\terae-local\painel-do-back.ps1 -UmaVez   (uma leitura só)
#
# Nunca mostra senha, código de acesso nem hash: dos códigos, só a hora em que foram pedidos e usados.
# Horários no fuso da clínica (America/Cuiaba). Personas fictícias da homologação.
param([switch]$UmaVez, [int]$Segundos = 3)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$sql = @'
\pset footer off
\echo '== DIÁRIO (registro_diario) — o que a Laura e a família enviaram pelo app'
select to_char(r.criado_em at time zone 'America/Cuiaba','DD/MM HH24:MI:SS') as "recebido",
       split_part(p.nome,' ',1) as "paciente", r.adesao, coalesce(r.intensidade_sintoma,'—') as "atrapalhou",
       r.versao as "v", case when r.retirado_em is not null then 'retirado' when r.substituido_em is not null then 'substituído'
       when r.revisado_em is not null then 'revisado' else 'aguardando' end as "situação",
       case when r.id_alerta_clinico is not null then 'AVISOU A EQUIPE' else '' end as "alerta",
       case when r.guardado_em < r.criado_em - interval '10 seconds' then 'escrito sem internet às '||to_char(r.guardado_em at time zone 'America/Cuiaba','HH24:MI:SS') else '' end as "fila"
  from registro_diario r join paciente p on p.id = r.id_paciente
 where r.id_usuario_familia is not null
 order by r.criado_em desc limit 6;
\echo ''
\echo '== PROGRAMA EM CASA (registro_programa_domiciliar) — o que a família marcou em cada orientação'
select to_char(r.atualizado_em at time zone 'America/Cuiaba','DD/MM HH24:MI:SS') as "gravado", r.dia, r.adesao,
       split_part(u.nome,' ',1) as "quem registrou"
  from registro_programa_domiciliar r join usuario u on u.id = r.id_usuario_familia
 order by r.atualizado_em desc limit 4;
\echo ''
\echo '== PRESENÇA (agendamento) — confirmações vindas do portal'
select to_char(a.inicio at time zone 'America/Cuiaba','DD/MM HH24:MI') as "sessão", split_part(p.nome,' ',1) as "paciente",
       a.status, coalesce(a.canal_confirmacao,'—') as "canal",
       coalesce(to_char(a.confirmado_em at time zone 'America/Cuiaba','DD/MM HH24:MI:SS'),'—') as "confirmado"
  from agendamento a join paciente p on p.id = a.id_paciente
 where a.inicio > now() - interval '1 day'
 order by a.inicio limit 4;
\echo ''
\echo '== ENTRADAS NO PORTAL (sessao_autenticada e codigo_de_acesso) — sem senha nem código'
select to_char(s.criado_em at time zone 'America/Cuiaba','DD/MM HH24:MI:SS') as "aberta", split_part(u.nome,' ',1) as "quem",
       s.nivel_mfa as "etapa", coalesce(to_char(s.revogada_em at time zone 'America/Cuiaba','HH24:MI:SS'),'ativa') as "revogada (Sair)"
  from sessao_autenticada s join usuario u on u.id = s.id_usuario
 where s.superficie = 'portal'
 order by s.criado_em desc limit 4;
select split_part(u.nome,' ',1) as "quem", count(*) as "códigos em 24 h (teto 10)",
       to_char(max(c.criado_em) at time zone 'America/Cuiaba','HH24:MI:SS') as "último pedido"
  from codigo_de_acesso c join usuario u on u.id = c.id_usuario
 where c.criado_em > now() - interval '24 hours'
 group by u.nome order by max(c.criado_em) desc limit 4;
'@

do {
  $saida = $sql | docker exec -i infra-postgres-1 psql -X -q -U postgres -d terae_app_local 2>&1
  if (-not $UmaVez) { Clear-Host }
  Write-Host ("Terae web local — painel do back (só leitura) · " + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Cyan
  $saida | ForEach-Object { if ("$_" -like '==*') { Write-Host $_ -ForegroundColor Yellow } else { Write-Host $_ } }
  if ($UmaVez) { break }
  Start-Sleep -Seconds $Segundos
} while ($true)
