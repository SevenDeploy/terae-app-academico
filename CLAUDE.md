# terae_app — produto ACADÊMICO (Dispositivos Móveis, UNEMAT 2026). Não é o app do Terae produção.

O Terae produção é um SaaS web; o canal do paciente no produto é um PWA na Play Store. Este app Flutter é outra forma de
ver o app do paciente, para a disciplina. Nunca ligar à API nem a dados do produto, nunca publicar em loja, nunca usar
`br.com.terae.*` como identificador.

## Fonte da verdade
Docx da Atividade 3 v3.0 (`../Faculdade/Dispositivos Móveis/Terae - Atividade 3 - Implementacao Inicial e Modelo de Dados.docx`):
§12 história e critérios de aceite, §13–14 e §19 RFM/RNFM, §20–21 telas e rotas, §22–23 modelo e regras de
integridade, §24 pastas. Decisões do líder (D1–D11) no README.

## Convenções
- Nomes em português sem acento (arquivos `snake_case`, classes `PascalCase`); uma tela por arquivo `*_tela.dart`,
  estado num `*_controlador.dart` (ChangeNotifier via provider).
- Comentário de documentação cita o requisito (`RFM03`, `RNFM05`, `§7.4`).
- Nenhuma exclusão física: inativação, situação ou data de revogação/uso.
- Caminho de rota só por `lib/nucleo/rotas/rotas.dart`; guarda de perfil só em `lib/roteador.dart`.
- "Agora" só pelo `Relogio` injetado (`lib/nucleo/tempo/`); horário exibido no fuso da clínica (−04:00).
- `funcionalidades/` usa `dados/` e `nucleo/`; `nucleo/` e `dados/` nunca importam `funcionalidades/`; `dados/` não
  importa widgets; tela nenhuma lê a fonte de dados direto, só por repositório.
- Teste acompanha o código: regras em `test/dados/`, navegação e telas em `test/funcionalidades/`.
- Commits: Conventional Commits em português, cabeçalho ≤ 100 caracteres.

## Verificação (Flutter em `C:\src\flutter\bin`)
```
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```
