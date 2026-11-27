# Teste das `firestore.rules` no emulador

Roda as regras do `terae_app` no **emulador local** do Firestore, com o projeto `demo-terae-app-academico`. Projeto
`demo-*` nunca fala com o Firebase real: nada aqui toca o `terae-app-academico`. Publicar as regras e rodar a semente
continuam pedindo o ok do dono.

Pré-requisitos: Node, Firebase CLI (`firebase`) e Java 21+. Sem Java no PATH, use o do Android Studio.

```bash
cd ferramentas/regras-firestore
npm install
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" PATH="$JAVA_HOME/bin:$PATH"
npm run testar
```

O `npm run testar` sobe o emulador (porta 8080), roda `node --test regras.test.mjs` e desliga o emulador no fim.

O que cobre: criar a versão 1 só com a adesão, corrigir (versão seguinte com as anteriores intactas), retirar com
motivo ("outro" exige o detalhe), o reenvio da fila (só o `enviadoEm`). Revisado, retirado e o que avisou a equipe
não mudam. Cobre também o formato antigo (vira versão 1; "grave"/"critica" não muda mais) e o cuidador, outra conta e
o sem login fora do diário. Por fim, o alerta só nasce de grave/crítico no mesmo lote, e `confirmacoes`, `metas` e
`registrosCasa` ficam como antes.
