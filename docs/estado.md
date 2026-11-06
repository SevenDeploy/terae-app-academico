# Estado do terae_app — 06/11/2026 (Atividade 4)

Projeto acadêmico (Dispositivos Móveis, UNEMAT 2026). Não é o app do Terae produção: o produto é um SaaS web, e o
canal do paciente no produto é um PWA na Play Store.

## Atividade 4 — Persistência local e integração com o Firebase (06/11/2026)

Plano: `C:\Users\willi\.claude\plans\crie-um-plano-para-piped-hare.md`. Prazo de entrega: até ~13/11/2026.

### Decisões

Do dono (06/11/2026):

| # | Decisão |
|---|---|
| D12 | Serviço remoto: Firebase (Authentication + Cloud Firestore), plano Spark, projeto acadêmico próprio `terae-app-academico` |
| D13 | Item principal do CRUD: RegistroDiario |
| D14 | Usuários com e-mail e senha (Firebase Authentication); o aparelho nunca grava a senha (RNFM04) |
| D15 | Prazo de 1 semana: sem SQLCipher e sem tela "Minha conta" (cifragem do SQLite fica como limitação declarada) |
| — | Projeto movido para `C:\Users\willi\Projetos\Terae\terae_app` (fora do OneDrive) e a pasta do curso renomeada para `Dispositivos Moveis` |

Do líder, por delegação do dono (06/11/2026):

| # | Decisão |
|---|---|
| D16 | SQLite é a fonte local da verdade: o diário é lido do SQLite e a fila de envio são as linhas `naFila`; as cópias de leitura tentam o servidor por 2 s e caem na cópia local; persistência offline do Firestore desligada |
| D17 | Corrigir e excluir o registro só no mesmo dia civil da clínica; exclusão lógica (`excluidoEm`); alerta já emitido nunca some. Substitui "depois de enviado, o registro não é editado" (A3 §23) |
| D18 | Sem Cloud Functions no Spark, o alerta é avaliado no aparelho e vai no mesmo lote do registro (id derivado do registro: no máximo um); as `firestore.rules` só aceitam alerta de registro grave/crítico |
| D19 | Web e testes continuam na memória (sqflite não roda na web); a memória ganhou e-mail/senha e o CRUD |
| D20 | "Sair" encerra o Firebase e apaga o SQLite e as preferências da conta |

### Pronto (local, sem commit)

- `lib/dados/local/` (SQLite: `banco_local`, `registro_diario_dao`, `cache_dao`; SharedPreferences:
  `preferencias_locais`), `lib/dados/remoto/` (Firestore, hash do convite, falhas → recusas),
  `lib/dados/sincronizacao/` (monitor de conexão, sincronizador, situação para o aviso), `lib/dados/persistente/`
  (os seis contratos sobre Firebase + SQLite e a composição).
- Telas: TM01 com e-mail e senha; TM09/TM10 com o passo 4 "Crie seu acesso"; TM13 Meus registros (lista, busca,
  filtro, puxar para atualizar); TM14 Registro (visualização, excluir); TM15 Corrigir registro; aviso de conexão na
  TM02, TM03, TM08, TM13 e TM14.
- `firestore.rules`, `firebase.json`, `ferramentas/semear-firebase.mjs` (+ `package.json`), `.env.exemplo`;
  permissões `INTERNET` e `ACCESS_NETWORK_STATE` no manifesto principal.
- Portão verde: `dart format` sem mudança, `flutter analyze` sem issue, **541 testes** (16 telas nos testes de
  acessibilidade e capturas, incluindo TM13–TM15).

### Firebase de verdade (06/11/2026)

- Projeto `terae-app-academico` (conta `sevendeploy7@gmail.com`, plano Spark), com e-mail/senha ativado pelo dono,
  app Android `br.edu.unemat.terae_app` registrado pelo `flutterfire configure` e `firestore.rules` publicadas.
- **Região do Firestore: `nam5` (EUA)**, e não `southamerica-east1` como planejado: a primeira publicação das regras
  criou o banco com a região padrão, que não muda depois. Mantida porque os dados são fictícios; registrado no docx.
- Chave da conta de serviço em `C:\Users\willi\Projetos\Terae\.credenciais\` (fora do OneDrive e do git); `.env`
  (fora do git) com o caminho dela e a senha de demonstração, gerada e nunca escrita em chat nem em código.
- Semente rodada; `node ferramentas/conferir-firebase.mjs [pacienteId]` mostra os registros, alertas e contas.

### Roteiro no emulador (06/11/2026), com o Firebase real

Passou: entrar (Ana); registrar online; modo avião → "Registro guardado", aviso "Sem conexão — 1 registro
aguardando envio" e selo na TM13; conexão de volta → a fila saiu sozinha; corrigir para crítico → TM05 "Seu
profissional foi avisado" e alerta + aviso do cuidador no Firestore; excluir (lógico, `excluidoEm`); "Sair";
cadastro do João pelo código `K7M4QX` nos quatro passos (conta, código usado, paciente ligado e consentimento no
Firestore, pelas regras); Regina vê o aviso novo na TM12 sem ver o diário. Capturas em `docs/evidencias-a4/`.

Achou e corrigiu (com teste de regressão):
1. o histórico do servidor só chegava ao SQLite na sincronização seguinte à entrada — agora a entrada sincroniza;
2. TM13/TM14 não se atualizavam depois que a fila saía — agora recarregam ao fim da sincronização;
3. bloqueio por muitas tentativas aparecia como "sem internet" — agora `muitasTentativas`.

Observação do roteiro: o primeiro login logo depois de instalar pode passar dos 10 s do Authentication e mostrar
"Sem internet agora"; a segunda tentativa entra.

### Pendências da Atividade 4

1. Commit do trabalho (ainda não feito) e, se o dono quiser, o docx "Resumo".
2. Passar à equipe a senha de demonstração (está no `.env` do dono) — ou cada um usa o primeiro acesso.
3. Ajustar a data da versão 4.0 no `gerar_docx.py` (`DATA_DA_VERSAO`) se a entrega não for em 13/11.

## Pronto na Atividade 3 (main `d1b91e0` + documentação)

- As 13 telas da Atividade 3 (TM00–TM12, mais a seleção de perfil da TM01), o roteador com a guarda de perfil, as 12
  entidades e os 11 enums, e os repositórios em memória com a demonstração das personas.
- Portão verde: `dart format` sem mudança, `flutter analyze` sem issue e **477 testes** em 36 arquivos (`test/dados`,
  `test/funcionalidades`, `test/nucleo`, `test/acessibilidade`, `test/capturas`, `test/arquitetura_test.dart`).
- Acessibilidade: as 13 telas passam nos guias de alvo de toque (Android e iOS), rótulo, contraste e fonte a 200%
  em 360×800.
- 14 capturas determinísticas em `docs/capturas/` (720×1600, geradas no Windows).
- APK de depuração e build web gerados. O caminho crítico da §12 (Entrar → Ana → diário crítico em 5 toques → TM05
  com 188/192 e "profissional avisado" → voltar leva ao Início) foi conferido no emulador Android 16.
- Como acessar: seção "Como acessar localmente" do `README.md`.

## Decisões da Atividade 3 (líder, por delegação do dono, 02/10/2026)

Do plano:

| # | Decisão |
|---|---|
| D1 | Repositório próprio em `Terae/terae_app`, fora do monorepo do produto; caminho ASCII (o Gradle falha com "Móveis"); em 06/11 confirmado: dentro do OneDrive também não compila |
| D1b | Identificador `br.edu.unemat.terae_app`; selo "Projeto acadêmico — UNEMAT 2026"; sem publicação em loja |
| D2 | Flutter 3.47, Android 8+ (minSdk 26) e **iOS 15+**: o Flutter 3.47 não suporta iOS < 15, então o RNFM06 precisa de ajuste |
| D3 | Dependências do §24 mais o `url_launcher`, para ligar para 188/192 com um toque; Lexend embarcada; UUID v4 próprio |
| D4 | Ícones Material, no lugar dos lucide do protótipo |
| D5 | Login Google/Apple simulado ("Escolha uma conta"); Apple só no iOS — **superada pela D14 na Atividade 4** |
| D6 | Nada persiste no aparelho nesta etapa (RNFM04 cumprido por ausência) — **superada pela D16 na Atividade 4** |
| D7 | Fuso da clínica fixo em −04:00, com `Relogio` injetável |
| D8 | Enums com a grafia do docx (`moderada`, `critica`) |
| D9 | Datas da demonstração relativas a hoje |
| D10 | Seletor com estado semântico, texto ≥ 14 sp, e a TM04 não volta sozinha com leitor de tela |
| D11 | Painel de demonstração (sem conexão, reiniciar dados) só em modo depuração |

Da revisão:

- Criança (menos de 12 anos completos, no fuso da clínica) só é ativada pelo responsável legal (ECA art. 2º; LGPD
  art. 14 §1º). Adolescente e adulto podem ser titulares.
- Religar a conexão reenvia a fila, e o alerta do registro crítico que estava na fila nasce nesse momento.
- O id do rascunho do diário fica o mesmo até o envio ser confirmado, e "Tentar de novo" reenvia o mesmo registro.
  A TM04 diz "Enviando…" até a resposta, e a TM05 mostra a falha mantendo 188/192.
- A cópia do cuidador é montada por lista branca de campos: a receita vai sem orientação e sem profissional.
- Convite expirado não conta no limite de 2 cuidadores, e o CPF dele pode ser convidado de novo.
- Opções de sintoma (Tristeza, Ansiedade, Cansaço, Dor, Sono ruim, Falta de ar, Outro, Nenhum em especial) vêm dos
  exemplos do protótipo; nenhum texto é obrigatório (RNFM02).

## Pendências da Atividade 3

1. **Re-revisão das 6 correções** (`670f734..b4e7a53`) em contexto limpo. Foi interrompida pelo limite semanal antes
   de reportar. Uma das correções resolveu achado bloqueante (criança como titular). Os testes que reproduziam cada
   achado passam.
2. **Documentação da Onda 4**, que também foi interrompida:
   - `docs/rastreabilidade.md`: RFM/RNFM → tela → arquivo → teste;
   - `docs/ajustes-atividade3.md`: rascunho para a v4.0 do docx (RNFM06 → iOS 15; TM05 só para crítica; limite com
     pendentes não expirados; corte de 12 anos; D10; `AvisoDeAlerta` na visão do cuidador; recorte acadêmico × PWA);
   - `.github/workflows/flutter.yml`, só local, com `@Tags(['capturas'])` no teste de capturas, porque as imagens
     divergem fora do Windows.
3. **GitHub**: o dono escolheu "só local por enquanto". Criar `SevenDeploy/terae-app` e convidar a equipe só com novo
   ok dele.
4. **Diferenças visuais em relação ao protótipo**, aceitas por ora:
   - a TM02 não tem o cartão "Seu próximo remédio";
   - "Tomei uma parte" quebra em 3 linhas a 360 dp;
   - a demonstração não tem consulta cancelada futura, então esse aviso da TM12 não aparece.
5. Prazo e formato de entrega da Atividade 3 dependem do enunciado, que não está no disco.
