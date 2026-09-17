// flutter-sim-template-version: 1
/**
 * flutter-sim auth gate.
 *
 * serve-sim ships with no built-in authentication, so exposing port 3200 through a public
 * tunnel would hand simulator control to anyone who guessed the URL. This is a
 * dependency-free reverse proxy that requires `?k=<token>` once, trades it for
 * an HttpOnly cookie, and forwards everything (including the MJPEG stream and
 * the control WebSocket) to serve-sim on localhost.
 */
const http = require('node:http');
const net = require('node:net');

const TOKEN = process.env.FLUTTER_SIM_GATE_TOKEN || '';
const TARGET_PORT = Number(process.env.FLUTTER_SIM_TARGET_PORT || 3200);
const TARGET_HOST = '127.0.0.1';
const PORT = Number(process.env.FLUTTER_SIM_GATE_PORT || 3199);
const COOKIE = 'flutter_sim_k';

if (!TOKEN) {
  console.error('FLUTTER_SIM_GATE_TOKEN is required — refusing to proxy an unauthenticated simulator');
  process.exit(1);
}

function timingSafeEqual(a, b) {
  if (typeof a !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function cookieToken(req) {
  const raw = req.headers.cookie || '';
  for (const part of raw.split(';')) {
    const [name, ...rest] = part.trim().split('=');
    if (name === COOKIE) return rest.join('=');
  }
  return null;
}

function authorize(req) {
  if (timingSafeEqual(cookieToken(req), TOKEN)) return 'cookie';
  const url = new URL(req.url, 'http://localhost');
  if (timingSafeEqual(url.searchParams.get('k'), TOKEN)) return 'query';
  return false;
}

const DENIED = `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>flutter-sim</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 15vh auto; max-width: 32rem; padding: 0 1.5rem; color: #1f2328; background: #f6f8fa; line-height: 1.6; }
  .card { background: #ffffff; border: 1px solid #d0d7de; border-radius: 8px; padding: 2rem; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
  h1 { font-size: 1.25rem; margin-top: 0; color: #cf222e; }
  code { background: #f6f8fa; padding: 0.2em 0.4em; border-radius: 4px; font-size: 0.9em; border: 1px solid #d0d7de; }
</style></head>
<body><div class="card">
  <h1>Access Denied</h1>
  <p>This interactive Flutter iOS simulator session requires an access key.</p>
  <p>Open the full link with <code>?k=&lt;token&gt;</code> provided by the <code>flutter-sim</code> CLI.</p>
</div></body></html>`;

const server = http.createServer((req, res) => {
  if (req.url === '/__flutter-sim/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }

  const auth = authorize(req);
  if (!auth) {
    res.writeHead(403, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(DENIED);
    return;
  }

  const headers = { ...req.headers };
  headers['host'] = req.headers['host'] || '127.0.0.1';
  headers['x-forwarded-host'] = req.headers['host'] || '';
  headers['x-forwarded-proto'] = 'https';

  const isQueryAuth = auth === 'query';
  let targetPath = req.url;
  if (isQueryAuth) {
    const url = new URL(req.url, 'http://localhost');
    url.searchParams.delete('k');
    targetPath = url.pathname + (url.search ? url.search : '');
  }

  const proxyReq = http.request(
    {
      hostname: TARGET_HOST,
      port: TARGET_PORT,
      path: targetPath,
      method: req.method,
      headers,
    },
    (proxyRes) => {
      const resHeaders = { ...proxyRes.headers };
      if (isQueryAuth) {
        const setCookie = `flutter_sim_k=${encodeURIComponent(TOKEN)}; Path=/; HttpOnly; SameSite=Lax; Secure`;
        resHeaders['set-cookie'] = resHeaders['set-cookie']
          ? [].concat(resHeaders['set-cookie'], setCookie)
          : [setCookie];
      }
      res.writeHead(proxyRes.statusCode, resHeaders);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on('error', (err) => {
    res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end(`Target gateway error: ${err.message}`);
  });

  req.pipe(proxyReq);
});

// WebSocket proxying for touch input and gestures
server.on('upgrade', (req, socket, head) => {
  if (!authorize(req)) {
    socket.write('HTTP/1.1 403 Forbidden\r\n\r\n');
    socket.destroy();
    return;
  }

  const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
    const reqHeaders = Object.entries(req.headers)
      .map(([k, v]) => `${k}: ${v}`)
      .join('\r\n');
    targetSocket.write(`${req.method} ${req.url} HTTP/${req.httpVersion}\r\n${reqHeaders}\r\n\r\n`);
    if (head && head.length) targetSocket.write(head);
    targetSocket.pipe(socket);
    socket.pipe(targetSocket);
  });

  targetSocket.on('error', () => {
    socket.destroy();
  });
  socket.on('error', () => {
    targetSocket.destroy();
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`flutter-sim auth gate listening on 127.0.0.1:${PORT} -> 127.0.0.1:${TARGET_PORT}`);
});
