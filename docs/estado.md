# Estado do terae_app — 03/10/2026

Projeto acadêmico (Dispositivos Móveis, UNEMAT 2026). Não é o app do Terae produção: o produto é um SaaS web, e o
canal do paciente no produto é um PWA na Play Store.

## Pronto (main `d1b91e0` + documentação)

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

## Decisões do líder (por delegação do dono, 02/10/2026)

Do plano:

| # | Decisão |
|---|---|
| D1 | Repositório próprio em `Terae/terae_app`, fora do monorepo do produto; caminho ASCII (o Gradle falha com "Móveis") |
| D1b | Identificador `br.edu.unemat.terae_app`; selo "Projeto acadêmico — UNEMAT 2026"; sem publicação em loja |
| D2 | Flutter 3.47, Android 8+ (minSdk 26) e **iOS 15+**: o Flutter 3.47 não suporta iOS < 15, então o RNFM06 precisa de ajuste |
| D3 | Dependências do §24 mais o `url_launcher`, para ligar para 188/192 com um toque; Lexend embarcada; UUID v4 próprio |
| D4 | Ícones Material, no lugar dos lucide do protótipo |
| D5 | Login Google/Apple simulado ("Escolha uma conta"); Apple só no iOS |
| D6 | Nada persiste no aparelho nesta etapa (RNFM04 cumprido por ausência) |
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

## Pendências

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
