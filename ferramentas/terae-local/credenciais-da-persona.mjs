// Ajudante do `entrar-no-emulador.ps1`: entrega só o que o roteiro precisa de uma persona do Terae local, sem nunca
// escrever senha ou código em arquivo.
//
//   node credenciais-da-persona.mjs email  <persona>
//   node credenciais-da-persona.mjs senha  <persona>                  (a senha, para o adb digitar; nunca mostre)
//   node credenciais-da-persona.mjs ultimo-id <persona>               (o id da mensagem mais nova no Mailpit)
//   node credenciais-da-persona.mjs codigo <persona> [depois-de-id]   (os 6 dígitos da mensagem mais nova; com
//                                                                     `depois-de-id`, só se for outra mensagem)
//
// `<persona>`: mariana, rosa ou laura. As senhas ficam em `..\terae\.credenciais\contas-de-dev.json` (fora dos dois
// repositórios); o Mailpit é o do Terae local (127.0.0.1:8025). Nada aqui toca a produção.
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const EMAILS = {
  mariana: 'responsavel-alice@homologacao.terae.invalid',
  rosa: 'cuidador-alice@homologacao.terae.invalid',
  laura: 'paciente-adulta@homologacao.terae.invalid',
}
const MAILPIT = process.env.TERAE_LOCAL_MAILPIT ?? 'http://127.0.0.1:8025'
const ARQUIVO =
  process.env.TERAE_LOCAL_CONTAS ??
  join(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', 'terae', '.credenciais', 'contas-de-dev.json')

const [, , comando, persona, depoisDe] = process.argv
const email = EMAILS[persona ?? '']
if (!comando || !email) {
  console.error('uso: credenciais-da-persona.mjs email|senha|ultimo-id|codigo <mariana|rosa|laura> [depois-de-id]')
  process.exit(64)
}

async function ultimaMensagem() {
  const busca = await (await fetch(`${MAILPIT}/api/v1/search?query=to:${email}&limit=1`)).json()
  return busca.messages?.[0]
}

if (comando === 'email') {
  process.stdout.write(email)
} else if (comando === 'senha') {
  const j = JSON.parse(readFileSync(ARQUIVO, 'utf8'))
  const lista = Array.isArray(j) ? j : (j.contas ?? Object.values(j))
  const conta = lista.find((c) => c && c.email === email)
  if (!conta?.senha) {
    console.error('conta não achada no contas-de-dev.json (rode o semear-contas-de-demonstracao)')
    process.exit(2)
  }
  process.stdout.write(conta.senha)
} else if (comando === 'ultimo-id') {
  process.stdout.write((await ultimaMensagem())?.ID ?? '')
} else if (comando === 'codigo') {
  const m = await ultimaMensagem()
  if (!m || m.ID === depoisDe) process.exit(3) // ainda não chegou o e-mail novo
  const corpo = await (await fetch(`${MAILPIT}/api/v1/message/${m.ID}`)).json()
  const achado = (corpo.Text ?? '').match(/\b(\d{6})\b/)
  if (!achado) process.exit(4)
  process.stdout.write(achado[1])
} else {
  console.error(`comando desconhecido: ${comando}`)
  process.exit(64)
}
