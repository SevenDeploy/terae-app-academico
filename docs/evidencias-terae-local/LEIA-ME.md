# Evidências — app na fonte Terae local (27/11/2026)

Emulador `Terae_Pixel`, `flutter run --dart-define=TERAE_FONTE=local`, API do Terae web local em
`http://10.0.2.2:3000`, persona Mariana (responsável legal da Alice). Nenhuma captura da tela de senha.

| Arquivo | O que mostra |
|---|---|
| `01-capa-modo-local.png` | Capa sem "Primeiro acesso" e sem o painel de demonstração |
| `02-etapa-do-codigo.png` | Etapa 2 do portal: e-mail mascarado, 6 caixas, confiar desmarcado, reenvio em 0:58 |
| `03-codigo-nas-6-caixas.png` | O código lido do Mailpit nas seis caixas |
| `04-inicio-mariana-alice.png` | Início: próxima sessão (01/12, 14:00) e o programa de hoje, sem Jornada nem diário |
| `05-em-casa.png` | As três orientações publicadas pela TO no web |
| `06-agenda-antes.png` | Agenda com as sessões, antes de responder |
| `07-agenda-presenca-confirmada.png` | "Sim, vamos" — no banco, `confirmado_em` com `canal_confirmacao = portal` |
| `08-diario-indisponivel.png` | Aba Diário indisponível até a P3, sem botão |
| `09-conta-sem-cuidadores.png` | Conta sem "Cuidadores que você autorizou" |
| `10-atividade-registrada.png` | Atividade registrada "Em parte", sem Desfazer nem faixa |
| `11-atividade-corrigida-com-reflexao.png` | Correção com reflexão, gravada em `registro_programa_domiciliar` |

A captura 05 é de antes do ajuste que esconde "Esta semana: x de y" no modo local (o portal só devolve o
registro de hoje); o ajuste está coberto por `test/funcionalidades/paciente/fonte_terae_local_test.dart`.
