#!/usr/bin/env node
// Semente do Firebase ACADÊMICO terae-app-academico (Atividade 4, D12).
// Nunca aponte para o Terae produção.
//
// Lê assets/dados/demonstracao.json (o mesmo da memória), resolve as datas
// relativas a hoje no fuso da clínica (−04:00, D9), cria no Authentication as
// contas das personas e grava no Firestore as coleções, as cópias reduzidas
// do cuidador (RNFM05) e os convites públicos com CPF e nascimento só como
// hash (o mesmo `hashDoConvite` do app).
//
// Uso (na pasta terae_app):
//   cd ferramentas && npm install && cd ..
//   node ferramentas/semear-firebase.mjs              # grava por cima
//   node ferramentas/semear-firebase.mjs --reiniciar  # apaga e grava de novo
//
// Variáveis (ambiente ou arquivo .env na pasta terae_app, fora do git):
//   TERAE_APP_CONTA_SERVICO  caminho da chave da conta de serviço (JSON),
//                            guardada FORA do OneDrive e do repositório
//   TERAE_APP_SENHA_DEMO     senha das contas de demonstração (≥ 8)

import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(join(raiz, 'ferramentas', 'package.json'));
const admin = require('firebase-admin');

// --------------------------------------------------------------- ambiente
function lerEnv() {
  const arquivo = join(raiz, '.env');
  if (!existsSync(arquivo)) return;
  for (const linha of readFileSync(arquivo, 'utf8').split(/\r?\n/)) {
    const m = linha.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
}
lerEnv();

const caminhoDaChave = process.env.TERAE_APP_CONTA_SERVICO;
const senhaDemo = process.env.TERAE_APP_SENHA_DEMO;
if (!caminhoDaChave || !existsSync(caminhoDaChave)) {
  console.error('Defina TERAE_APP_CONTA_SERVICO com o caminho da chave da conta de serviço.');
  process.exit(1);
}
if (!senhaDemo || senhaDemo.length < 8) {
  console.error('Defina TERAE_APP_SENHA_DEMO (pelo menos 8 caracteres).');
  process.exit(1);
}
const chave = JSON.parse(readFileSync(caminhoDaChave, 'utf8'));
if (chave.project_id !== 'terae-app-academico') {
  console.error(`Projeto inesperado: ${chave.project_id}. Esta semente é só do terae-app-academico.`);
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(chave) });
const db = admin.firestore();
const auth = admin.auth();

// ------------------------------------------------------ datas relativas (D9)
const DESLOCAMENTO_MS = 4 * 60 * 60 * 1000; // clínica em −04:00
const agora = new Date();
const hojeNaClinica = new Date(agora.getTime() - DESLOCAMENTO_MS);
const hoje = {
  ano: hojeNaClinica.getUTCFullYear(),
  mes: hojeNaClinica.getUTCMonth(),
  dia: hojeNaClinica.getUTCDate(),
};

function dataRelativa({ emDias, hora, ...extras }) {
  if (Object.keys(extras).length) throw new Error(`Data relativa com chave desconhecida: ${JSON.stringify(extras)}`);
  const d = new Date(Date.UTC(hoje.ano, hoje.mes, hoje.dia + emDias));
  if (hora === undefined) return d.toISOString().slice(0, 10);
  const [h, m] = hora.split(':').map(Number);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), h, m) + DESLOCAMENTO_MS).toISOString();
}

function resolver(valor) {
  if (Array.isArray(valor)) return valor.map(resolver);
  if (valor && typeof valor === 'object') {
    if ('emDias' in valor) return dataRelativa(valor);
    return Object.fromEntries(Object.entries(valor).map(([k, v]) => [k, resolver(v)]));
  }
  return valor;
}

const hashDoConvite = (codigo, valor) =>
  createHash('sha256').update(`${codigo}:${valor}`, 'utf8').digest('hex');

// -------------------------------------------------------------- os dados
const dados = resolver(JSON.parse(readFileSync(join(raiz, 'assets', 'dados', 'demonstracao.json'), 'utf8')));
const porId = (lista) => Object.fromEntries(lista.map((x) => [x.id, x]));
const pacientes = porId(dados.pacientes);
const receitas = porId(dados.receitas);
const registros = porId(dados.registros);
const vinculosPorConvite = Object.fromEntries(dados.vinculos.map((v) => [v.conviteId, v]));

// E-mails das personas que entram (contas) e das que criam o acesso no app.
const emailsDaDemonstracao = [
  ...dados.contas.map((c) => c.email),
  'joao.pedro.assis@exemplo.test',
  'paulo.martins@exemplo.test',
];

/** Apaga as coleções (com as subcoleções de cada paciente) e as contas. */
async function reiniciar() {
  for (const nome of ['contas', 'convites', 'vinculos', 'consentimentos', 'profissionais', 'pacientes']) {
    await db.recursiveDelete(db.collection(nome));
  }
  for (const email of emailsDaDemonstracao) {
    try {
      const u = await auth.getUserByEmail(email);
      await auth.deleteUser(u.uid);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
    }
  }
  console.log('Firestore e contas de demonstração apagados.');
}

async function semear() {
  // Authentication: uid = id da conta (ContaUsuario.idProvedor).
  for (const c of dados.contas) {
    const usuario = { uid: c.id, email: c.email, password: senhaDemo, displayName: c.nomeExibicao };
    try {
      await auth.createUser(usuario);
    } catch (e) {
      if (e.code !== 'auth/uid-already-exists' && e.code !== 'auth/email-already-exists') throw e;
      await auth.updateUser(c.id, { password: senhaDemo, displayName: c.nomeExibicao });
    }
  }

  const lote = new Lotes();
  for (const p of dados.profissionais) lote.set(db.collection('profissionais').doc(p.id), p);
  for (const c of dados.contas) lote.set(db.collection('contas').doc(c.id), { ...c, idProvedor: c.id });

  const ativosPorPaciente = {};
  for (const v of dados.vinculos) {
    if (v.situacao === 'ativo') (ativosPorPaciente[v.pacienteId] ??= []).push(v.contaCuidadorId);
  }
  for (const p of dados.pacientes) {
    const { cpf, dataNascimento, ...publico } = p;
    const ref = db.collection('pacientes').doc(p.id);
    lote.set(ref, { ...publico, cuidadoresAtivos: ativosPorPaciente[p.id] ?? [] });
    lote.set(ref.collection('privado').doc('identificacao'), { cpf, dataNascimento });
  }
  for (const c of dados.consentimentos) lote.set(db.collection('consentimentos').doc(c.id), c);
  for (const v of dados.vinculos) lote.set(db.collection('vinculos').doc(v.id), v);

  for (const c of dados.convites) {
    const p = pacientes[c.pacienteId];
    const publico = {
      id: c.id,
      codigo: c.codigo,
      pacienteId: c.pacienteId,
      tipo: c.tipo,
      cpfHash: hashDoConvite(c.codigo, c.cpfConvidado),
      expiraEm: c.expiraEm,
      usadoEm: c.usadoEm,
      revogado: false,
      nomePaciente: p.nome,
      pacienteAtivo: p.ativo,
    };
    if (c.tipo === 'paciente') {
      publico.nascimentoHash = hashDoConvite(c.codigo, p.dataNascimento);
    } else {
      const v = vinculosPorConvite[c.id];
      publico.vinculoId = v.id;
      publico.revogado = v.situacao === 'revogado';
      lote.set(db.collection('pacientes').doc(c.pacienteId).collection('convites').doc(c.id), c);
    }
    lote.set(db.collection('convites').doc(c.codigo), publico);
  }

  const doPaciente = (pid, nome, id) => db.collection('pacientes').doc(pid).collection(nome).doc(id);
  for (const a of dados.agendamentos) {
    lote.set(doPaciente(a.pacienteId, 'agendamentos', a.id), a);
    lote.set(doPaciente(a.pacienteId, 'agendaCuidador', a.id), { ...a, motivoRetorno: null });
  }
  for (const r of dados.receitas) {
    lote.set(doPaciente(r.pacienteId, 'receitas', r.id), r);
    lote.set(doPaciente(r.pacienteId, 'receitaCuidador', r.id), { ...r, orientacao: null, profissionalId: null });
  }
  for (const i of dados.itensMedicacao) {
    const pid = receitas[i.receitaId].pacienteId;
    lote.set(doPaciente(pid, 'itensMedicacao', i.id), i);
    lote.set(doPaciente(pid, 'itensCuidador', i.id), i);
  }
  for (const m of dados.marcos) lote.set(doPaciente(m.pacienteId, 'marcos', m.id), m);
  // Evolução de TO (F3): as metas da terapia ocupacional (só o titular lê). Só os campos que a
  // família vê (D25): nunca escore, nível GAS nem peso, mesmo que entrem no JSON.
  for (const m of dados.metas ?? []) {
    const { id, pacienteId, profissionalId, ocupacao, descricao, combinadaCom, prazo, situacao } = m;
    lote.set(doPaciente(pacienteId, 'metas', id),
      { id, pacienteId, profissionalId, ocupacao, descricao, combinadaCom, prazo, situacao });
  }
  // Evolução de TO (F2): respostas de presença já dadas (uma por agendamento).
  for (const c of dados.confirmacoes ?? []) {
    lote.set(doPaciente(c.pacienteId, 'confirmacoes', c.agendamentoId), {
      ...c, situacaoEnvio: 'enviado',
    });
  }
  // Evolução de TO (F1): atividades de casa (da clínica) e o histórico dos registros.
  for (const a of dados.atividadesCasa ?? []) {
    lote.set(doPaciente(a.pacienteId, 'atividadesCasa', a.id), a);
  }
  for (const r of dados.registrosCasa ?? []) {
    lote.set(doPaciente(r.pacienteId, 'registrosCasa', r.id), {
      ...r, situacaoEnvio: 'enviado', atualizadoEm: null, excluidoEm: null,
    });
  }
  for (const r of dados.registros) {
    lote.set(doPaciente(r.pacienteId, 'registros', r.id), {
      ...r, situacaoEnvio: 'enviado', atualizadoEm: null, excluidoEm: null,
    });
  }
  for (const a of dados.alertas) {
    const pid = registros[a.registroId].pacienteId;
    lote.set(doPaciente(pid, 'alertas', a.id), a);
    lote.set(doPaciente(pid, 'avisosCuidador', a.id), { id: a.id, emitidoEm: a.emitidoEm, cienteEm: a.cienteEm ?? null });
  }
  await lote.gravar();
  console.log(`Semente gravada em ${chave.project_id}: ${dados.contas.length} contas, ${dados.pacientes.length} pacientes, ${dados.registros.length} registros.`);
}

/** Lotes de até 400 escritas (o Firestore aceita 500 por lote). */
class Lotes {
  constructor() { this.escritas = []; }
  set(ref, dado) { this.escritas.push([ref, dado]); }
  async gravar() {
    for (let i = 0; i < this.escritas.length; i += 400) {
      const lote = db.batch();
      for (const [ref, dado] of this.escritas.slice(i, i + 400)) lote.set(ref, dado);
      await lote.commit();
    }
  }
}

if (process.argv.includes('--reiniciar')) await reiniciar();
await semear();
