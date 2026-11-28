// Ajudante de uma sessão só para entrar no PORTAL WEB local (http://portal.localhost:5175) sem digitar senha nem
// código à mão: serve, em loopback, a senha da persona e o código mais novo do Mailpit, e só à página do portal
// (CORS fechado nessa origem). Desliga sozinho em 5 minutos. Nada disso sai da máquina.
//
//   node ferramentas/terae-local/ajudante-login-do-portal.mjs mariana     (deixe rodando; veja o roteiro em docs/roteiro-de-amanha.md)
//
// Personas: mariana, rosa, laura (as mesmas de credenciais-da-persona.mjs). Cada login no portal gasta UM código.
import http from 'node:http'
import { spawnSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const persona = process.argv[2]
const ajudante = join(dirname(fileURLToPath(import.meta.url)), 'credenciais-da-persona.mjs')
const ORIGEM = 'http://portal.localhost:5175'
const PORTA = 47831

function chamar(...args) {
  const r = spawnSync(process.execPath, [ajudante, ...args, persona], { encoding: 'utf8' })
  return r.status === 0 ? r.stdout : null
}
if (!['mariana', 'rosa', 'laura'].includes(persona ?? '')) {
  console.error('uso: ajudante-login-do-portal.mjs <mariana|rosa|laura>')
  process.exit(64)
}

const servidor = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', ORIGEM)
  res.setHeader('Cache-Control', 'no-store')
  if (req.headers.origin !== ORIGEM) {
    res.statusCode = 403
    return res.end('{}')
  }
  if (req.url === '/cred') {
    const email = chamar('email')
    const senha = chamar('senha')
    return res.end(JSON.stringify({ email, senha }))
  }
  if (req.url === '/codigo') {
    return res.end(JSON.stringify({ codigo: chamar('codigo') ?? '' }))
  }
  res.statusCode = 404
  res.end('{}')
})
servidor.listen(PORTA, '127.0.0.1', () => console.log(`ajudante de ${persona} em 127.0.0.1:${PORTA} (5 min)`))
setTimeout(() => servidor.close(() => process.exit(0)), 5 * 60 * 1000)
