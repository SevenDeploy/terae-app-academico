#!/usr/bin/env node
// Confere o Firebase ACADÊMICO terae-app-academico (Atividade 4): mostra os
// registros mais recentes de um paciente, os alertas e as contas criadas no
// app. Só leitura. Usa as mesmas variáveis da semente (.env, fora do git).
//
// Uso: node ferramentas/conferir-firebase.mjs [pacienteId]

import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(join(raiz, 'ferramentas', 'package.json'));
const admin = require('firebase-admin');

const arquivo = join(raiz, '.env');
if (existsSync(arquivo)) {
  for (const linha of readFileSync(arquivo, 'utf8').split(/\r?\n/)) {
    const m = linha.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
  }
}
const chave = JSON.parse(readFileSync(process.env.TERAE_APP_CONTA_SERVICO, 'utf8'));
if (chave.project_id !== 'terae-app-academico') throw new Error('Projeto inesperado');
admin.initializeApp({ credential: admin.credential.cert(chave) });
const db = admin.firestore();

const pid = process.argv[2] ?? 'a0000000-0000-4000-8000-000000000001';
const paciente = db.collection('pacientes').doc(pid);
const registros = await paciente.collection('registros').orderBy('registradoEm', 'desc').limit(4).get();
console.log(`Registros mais recentes de ${pid}:`);
for (const d of registros.docs) {
  const r = d.data();
  console.log(`  ${r.registradoEm}  ${r.intensidade.padEnd(9)} ${r.sintomaPredominante.padEnd(12)} ${r.situacaoEnvio}` +
    `${r.atualizadoEm ? '  corrigido ' + r.atualizadoEm : ''}${r.excluidoEm ? '  EXCLUÍDO ' + r.excluidoEm : ''}`);
}
const alertas = await paciente.collection('alertas').get();
console.log(`Alertas: ${alertas.size}; avisos do cuidador: ${(await paciente.collection('avisosCuidador').get()).size}`);
const contas = await db.collection('contas').get();
console.log(`Contas: ${contas.docs.map((d) => d.data().email).join(', ')}`);
