// Servidor estático mínimo para o build web do app acadêmico (build/web), sem dependências.
// Uso: node ferramentas/servir-web.mjs  (porta pela variável PORTA, padrão 8090)
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = resolve(fileURLToPath(new URL('../build/web', import.meta.url)));
const porta = Number(process.env.PORTA ?? 8090);
const tipos = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.bin': 'application/octet-stream',
};

async function arquivoDe(caminhoUrl) {
  const relativo = normalize(decodeURIComponent(caminhoUrl.split('?')[0])).replace(/^[/\\]+/, '');
  const alvo = resolve(join(raiz, relativo));
  if (alvo !== raiz && !alvo.startsWith(raiz + sep)) return null;
  try {
    const info = await stat(alvo);
    return info.isFile() ? alvo : join(alvo, 'index.html');
  } catch {
    return join(raiz, 'index.html');
  }
}

createServer(async (pedido, resposta) => {
  const alvo = await arquivoDe(pedido.url ?? '/');
  if (!alvo) {
    resposta.writeHead(403).end();
    return;
  }
  try {
    const corpo = await readFile(alvo);
    resposta.writeHead(200, { 'Content-Type': tipos[extname(alvo)] ?? 'application/octet-stream' });
    resposta.end(corpo);
  } catch {
    resposta.writeHead(404).end('Rode antes: flutter build web');
  }
}).listen(porta, () => {
  console.log(`terae_app (web) em http://localhost:${porta}  — Ctrl+C para parar`);
});
