// Teste das firestore.rules no emulador LOCAL do Firestore (projeto demo-*:
// nunca toca o terae-app-academico). Roda com `npm run testar` (ver LEIA-ME).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

const PID = 'p-alice';
const TITULAR = 'conta-mariana';
const CUIDADOR = 'conta-rosa';
const OUTRA = 'conta-intrusa';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-terae-app-academico',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'pacientes', PID), {
      id: PID,
      contaId: TITULAR,
      cuidadoresAtivos: [CUIDADOR],
    });
    await setDoc(doc(db, `pacientes/${PID}/agendamentos/ag1`), {
      id: 'ag1',
      situacao: 'agendado',
      dataHora: '2026-12-01T18:00:00.000Z',
    });
    await setDoc(doc(db, `pacientes/${PID}/atividadesCasa/at1`), { id: 'at1' });
    await setDoc(doc(db, `pacientes/${PID}/metas/m1`), { id: 'm1' });
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();
const caminho = (rid) => `pacientes/${PID}/registros/${rid}`;

function registro(rid, extra = {}) {
  return {
    id: rid,
    pacienteId: PID,
    registradoEm: '2026-11-27T12:00:00.000Z',
    adesao: 'parcial',
    sintomas: 'Dormiu mal.',
    intensidadeSintoma: 'leve',
    observacoes: null,
    situacaoEnvio: 'enviado',
    versao: 1,
    enviadoEm: '2026-11-27T12:00:01.000Z',
    atualizadoEm: null,
    alertouAEquipe: false,
    revisadoEm: null,
    retiradoEm: null,
    motivoDaRetirada: null,
    versoesAnteriores: [],
    ...extra,
  };
}

async function semRegras(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

describe('diário (registros)', () => {
  test('titular cria a versão 1', async () => {
    await assertSucceeds(setDoc(doc(db(TITULAR), caminho('r1')), registro('r1')));
  });

  test('só a adesão é obrigatória (intensidade, sintomas e observações nulos)', async () => {
    await assertSucceeds(
      setDoc(
        doc(db(TITULAR), caminho('r1')),
        registro('r1', { intensidadeSintoma: null, sintomas: null }),
      ),
    );
  });

  test('não cria com versão 2, adesão inválida, revisadoEm ou pacienteId de outro', async () => {
    const d = db(TITULAR);
    await assertFails(setDoc(doc(d, caminho('r1')), registro('r1', { versao: 2 })));
    await assertFails(setDoc(doc(d, caminho('r2')), registro('r2', { adesao: 'talvez' })));
    await assertFails(
      setDoc(doc(d, caminho('r3')), registro('r3', { revisadoEm: '2026-11-27T13:00:00Z' })),
    );
    await assertFails(setDoc(doc(d, caminho('r4')), registro('r4', { pacienteId: 'p-outro' })));
    await assertFails(
      setDoc(doc(d, caminho('r5')), registro('r5', { intensidadeSintoma: 'critica' })),
    );
  });

  test('corrigir: a versão seguinte guarda a anterior', async () => {
    await semRegras((d) => setDoc(doc(d, caminho('r1')), registro('r1')));
    const v1 = {
      versao: 1,
      enviadaEm: '2026-11-27T12:00:01.000Z',
      adesao: 'parcial',
      sintomas: 'Dormiu mal.',
      intensidadeSintoma: 'leve',
      observacoes: null,
    };
    await assertSucceeds(
      setDoc(
        doc(db(TITULAR), caminho('r1')),
        registro('r1', { versao: 2, adesao: 'total', versoesAnteriores: [v1] }),
      ),
    );
  });

  test('segunda correção mantém as anteriores; reescrever a 1 falha', async () => {
    const v1 = { versao: 1, adesao: 'parcial' };
    await semRegras((d) =>
      setDoc(doc(d, caminho('r1')), registro('r1', { versao: 2, versoesAnteriores: [v1] })),
    );
    const d = db(TITULAR);
    const v2 = { versao: 2, adesao: 'parcial' };
    await assertFails(
      setDoc(
        doc(d, caminho('r1')),
        registro('r1', { versao: 3, versoesAnteriores: [{ versao: 1, adesao: 'total' }, v2] }),
      ),
    );
    await assertSucceeds(
      setDoc(doc(d, caminho('r1')), registro('r1', { versao: 3, versoesAnteriores: [v1, v2] })),
    );
  });

  test('corrigir não pode reescrever a versão anterior nem pular versão', async () => {
    await semRegras((d) => setDoc(doc(d, caminho('r1')), registro('r1')));
    const d = db(TITULAR);
    await assertFails(
      setDoc(doc(d, caminho('r1')), registro('r1', { versao: 3, versoesAnteriores: [{}, {}] })),
    );
    await assertFails(
      setDoc(
        doc(d, caminho('r1')),
        registro('r1', { versao: 2, versoesAnteriores: [{}], enviadoEm: '2026-11-28T00:00:00Z' }),
      ),
    );
  });

  test('retirar com motivo; "outro" exige o detalhe', async () => {
    await semRegras((d) => setDoc(doc(d, caminho('r1')), registro('r1')));
    await semRegras((d) => setDoc(doc(d, caminho('r2')), registro('r2')));
    const d = db(TITULAR);
    await assertSucceeds(
      updateDoc(doc(d, caminho('r1')), {
        retiradoEm: '2026-11-27T13:00:00.000Z',
        motivoDaRetirada: { categoria: 'dia_errado', detalhe: null },
      }),
    );
    await assertFails(
      updateDoc(doc(d, caminho('r2')), {
        retiradoEm: '2026-11-27T13:00:00.000Z',
        motivoDaRetirada: { categoria: 'outro', detalhe: null },
      }),
    );
    await assertSucceeds(
      updateDoc(doc(d, caminho('r2')), {
        retiradoEm: '2026-11-27T13:00:00.000Z',
        motivoDaRetirada: { categoria: 'outro', detalhe: 'Era de outro dia.' },
      }),
    );
  });

  test('reenvio da fila: só o enviadoEm muda, vale até no que avisou a equipe', async () => {
    await semRegras((d) =>
      setDoc(doc(d, caminho('r1')), registro('r1', { alertouAEquipe: true, intensidadeSintoma: 'critico' })),
    );
    await assertSucceeds(
      updateDoc(doc(db(TITULAR), caminho('r1')), { enviadoEm: '2026-11-27T12:05:00.000Z' }),
    );
  });

  for (const [nome, extra] of [
    ['revisado', { revisadoEm: '2026-11-27T14:00:00.000Z' }],
    [
      'retirado',
      {
        retiradoEm: '2026-11-27T13:00:00.000Z',
        motivoDaRetirada: { categoria: 'dia_errado', detalhe: null },
      },
    ],
    ['que avisou a equipe', { alertouAEquipe: true, intensidadeSintoma: 'critico' }],
  ]) {
    test(`${nome} não se corrige nem se retira`, async () => {
      await semRegras((d) => setDoc(doc(d, caminho('r1')), registro('r1', extra)));
      const d = db(TITULAR);
      await assertFails(
        setDoc(
          doc(d, caminho('r1')),
          registro('r1', { ...extra, versao: 2, adesao: 'total', versoesAnteriores: [{}] }),
        ),
      );
      await assertFails(
        updateDoc(doc(d, caminho('r1')), {
          retiradoEm: '2026-11-27T15:00:00.000Z',
          motivoDaRetirada: { categoria: 'enviado_sem_querer', detalhe: null },
        }),
      );
    });
  }

  test('formato antigo (sem versao): vira o formato novo, versão 1', async () => {
    await semRegras((d) =>
      setDoc(doc(d, caminho('r1')), {
        id: 'r1',
        pacienteId: PID,
        registradoEm: '2026-11-27T12:00:00.000Z',
        adesao: 'parcial',
        intensidade: 'leve',
        sintomaPredominante: 'Cansaço',
        situacaoEnvio: 'enviado',
      }),
    );
    await assertSucceeds(setDoc(doc(db(TITULAR), caminho('r1')), registro('r1')));
  });

  for (const antiga of ['grave', 'critica']) {
    test(`formato antigo "${antiga}" (pode ter alertado) não muda mais`, async () => {
      await semRegras((d) =>
        setDoc(doc(d, caminho('r1')), {
          id: 'r1',
          pacienteId: PID,
          registradoEm: '2026-11-27T12:00:00.000Z',
          adesao: 'parcial',
          intensidade: antiga,
          sintomaPredominante: 'Crise',
          situacaoEnvio: 'enviado',
        }),
      );
      await assertFails(setDoc(doc(db(TITULAR), caminho('r1')), registro('r1')));
      await assertFails(
        setDoc(
          doc(db(TITULAR), caminho('r1')),
          registro('r1', {
            retiradoEm: '2026-11-27T13:00:00.000Z',
            motivoDaRetirada: { categoria: 'dia_errado', detalhe: null },
          }),
        ),
      );
    });
  }

  test('cuidador não lê nem escreve o diário', async () => {
    await semRegras((d) => setDoc(doc(d, caminho('r1')), registro('r1')));
    await assertFails(getDoc(doc(db(CUIDADOR), caminho('r1'))));
    await assertFails(setDoc(doc(db(CUIDADOR), caminho('r2')), registro('r2')));
  });

  test('outra conta e sem login não leem nem escrevem', async () => {
    await semRegras((d) => setDoc(doc(d, caminho('r1')), registro('r1')));
    await assertFails(getDoc(doc(db(OUTRA), caminho('r1'))));
    await assertFails(setDoc(doc(db(OUTRA), caminho('r2')), registro('r2')));
    const anonimo = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(anonimo, caminho('r1'))));
  });

  test('titular lê o próprio diário; nada se apaga', async () => {
    await semRegras((d) => setDoc(doc(d, caminho('r1')), registro('r1')));
    await assertSucceeds(getDoc(doc(db(TITULAR), caminho('r1'))));
    const { deleteDoc } = await import('firebase/firestore');
    await assertFails(deleteDoc(doc(db(TITULAR), caminho('r1'))));
  });
});

describe('alertas (D18)', () => {
  test('nasce no mesmo lote de registro grave ou crítico', async () => {
    const d = db(TITULAR);
    const lote = writeBatch(d);
    lote.set(
      doc(d, caminho('r1')),
      registro('r1', { intensidadeSintoma: 'critico', alertouAEquipe: true }),
    );
    lote.set(doc(d, `pacientes/${PID}/alertas/a1`), { id: 'a1', registroId: 'r1' });
    await assertSucceeds(lote.commit());
  });

  test('não nasce de registro leve', async () => {
    const d = db(TITULAR);
    const lote = writeBatch(d);
    lote.set(doc(d, caminho('r1')), registro('r1'));
    lote.set(doc(d, `pacientes/${PID}/alertas/a1`), { id: 'a1', registroId: 'r1' });
    await assertFails(lote.commit());
  });
});

describe('coleções da TO mantidas', () => {
  test('confirmações: titular responde antes da sessão; cuidador lê; outro não', async () => {
    const resposta = {
      id: 'ag1',
      agendamentoId: 'ag1',
      pacienteId: PID,
      resposta: 'vamos',
      respondidaEm: '2026-11-27T12:00:00.000Z',
      situacaoEnvio: 'enviado',
    };
    await assertSucceeds(setDoc(doc(db(TITULAR), `pacientes/${PID}/confirmacoes/ag1`), resposta));
    await assertSucceeds(getDoc(doc(db(CUIDADOR), `pacientes/${PID}/confirmacoes/ag1`)));
    await assertFails(getDoc(doc(db(OUTRA), `pacientes/${PID}/confirmacoes/ag1`)));
    await assertFails(
      setDoc(doc(db(TITULAR), `pacientes/${PID}/confirmacoes/ag1`), {
        ...resposta,
        respondidaEm: '2026-12-02T00:00:00.000Z',
      }),
    );
  });

  test('metas: titular lê, cuidador não (D29)', async () => {
    await assertSucceeds(getDoc(doc(db(TITULAR), `pacientes/${PID}/metas/m1`)));
    await assertFails(getDoc(doc(db(CUIDADOR), `pacientes/${PID}/metas/m1`)));
  });

  test('registrosCasa: titular grava de atividade do paciente; cuidador não lê', async () => {
    const r = {
      id: 'rc1',
      pacienteId: PID,
      atividadeId: 'at1',
      dia: '2026-11-27',
      adesao: 'feito',
      quem: 'responsavel',
      reflexao: null,
      situacaoEnvio: 'enviado',
    };
    await assertSucceeds(setDoc(doc(db(TITULAR), `pacientes/${PID}/registrosCasa/rc1`), r));
    await assertFails(getDoc(doc(db(CUIDADOR), `pacientes/${PID}/registrosCasa/rc1`)));
    await assertFails(
      setDoc(doc(db(TITULAR), `pacientes/${PID}/registrosCasa/rc2`), {
        ...r,
        id: 'rc2',
        atividadeId: 'inexistente',
      }),
    );
  });
});
