# Evidências da paridade com o portal — app no Terae local (27/11/2026)

Emulador `Terae_Pixel` (1080×2400), app `--dart-define=TERAE_FONTE=local` falando com a API do Terae web **local**
(`http://10.0.2.2:3000`, banco `terae_app_local`). Personas fictícias da homologação: **Laura** (paciente adulta,
titular) e **Rosa** (avó, cuidadora da Alice). Nenhuma captura mostra senha; os códigos de e-mail saíram do Mailpit
local e foram digitados sem aparecer em captura.

| Arquivo | O que prova |
|---|---|
| `01-capa` | Capa marinho do portal ("O acompanhamento continua em casa."), selo acadêmico, CVV 188 / SAMU 192; barra de status clara |
| `02-entrar-vazio` | "Entrar no portal" com o texto do portal (`Entrar.tsx`) |
| `03-codigo-do-email` | Etapa 2 de 2 do portal: código de seis caixas, e-mail mascarado, reenvio em 60 s, "Confiar neste aparelho por 30 dias" desmarcado |
| `04-inicio-laura` | Início do portal ("Boa noite, Laura."), próxima sessão, cartão do diário, "Precisa de ajuda agora?", barra de 5 abas |
| `05-diario-vazio` | Aba Diário vazia: "Você ainda não fez nenhum registro." |
| `06-novo-registro` | Formulário igual ao do portal: três cartões de adesão, "Aconteceu alguma coisa…", "O quanto isso atrapalhou…" |
| `07-registro-enviado` | "Registro enviado." — o registro gravou na API local (`registro_diario`, versão 1) |
| `08-correcao-enviada` | "Correção enviada." — a correção cria a versão 2 e a 1 fica guardada |
| `09-diario-versao-2` | Lista com selos "Aguardando a terapeuta" e "Corrigido · versão 2", com Corrigir, Retirar e "Ver a versão 1" |
| `10-ver-versao-1` | A versão 1 aberta, com a adesão e o texto antigos |
| `11-retirar-com-motivo` | Folha "Retirar este registro?" com os motivos do portal; nada é apagado |
| `12-registro-retirado` | "Retirado por você", texto tachado, motivo; a versão 1 continua visível |
| `13-em-casa-vazio` | Em casa de quem não tem orientação publicada |
| `14-agenda` | Agenda, com "Falar com a clínica" |
| `15-conta` | Minha conta: seus dados, quem você acompanha, lembretes, Sair |
| `16`–`18` | Modo cuidador (Rosa): faixa "Modo cuidador · acesso limitado", Início, Agenda e Conta, sem aba Diário |
| `19-diario-rele-ao-voltar` | Depois de enviar e voltar ao Início, a aba Diário já mostra o registro novo (correção deste dia) |

Conferido no banco, só por leitura: `registro_diario` com a versão 1 substituída e a 2 retirada; o "Sair" revogou as
duas sessões do portal (`sessao_autenticada.revogada_em`: a de senha e a do segundo fator).
