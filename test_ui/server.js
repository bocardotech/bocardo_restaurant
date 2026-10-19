/**
 * Bocardo Restaurant - Standalone Test UI Server
 * Runs a zero-dependency static server on http://localhost:3000
 * Dynamically serves configuration from local .env (never hardcoded in client HTML)
 */
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const PORT = process.env.PORT || 3000;
const HTML_FILE = path.join(__dirname, 'index.html');
const ENV_FILE = path.join(__dirname, '..', '.env');

function getEnvConfig() {
  const config = {
    supabaseUrl: process.env.SUPABASE_URL || '',
    supabaseAnonKey: process.env.SUPABASE_PUBLISHABLE_KEY || '',
  };

  if (fs.existsSync(ENV_FILE)) {
    try {
      const lines = fs.readFileSync(ENV_FILE, 'utf-8').split('\n');
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) continue;
        const [key, ...rest] = trimmed.split('=');
        const val = rest.join('=').trim();
        if (key === 'SUPABASE_URL' && !config.supabaseUrl) config.supabaseUrl = val;
        if (key === 'SUPABASE_PUBLISHABLE_KEY' && !config.supabaseAnonKey) config.supabaseAnonKey = val;
      }
    } catch (_) {}
  }

  return config;
}

const server = http.createServer((req, res) => {
  if (req.url === '/' || req.url === '/index.html') {
    fs.readFile(HTML_FILE, (err, content) => {
      if (err) {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Error loading test bench UI: ' + err.message);
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(content);
    });
  } else if (req.url === '/api/config') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(getEnvConfig()));
  } else if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', server_time: new Date().toISOString() }));
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`=======================================================`);
  console.log(`  BOCARDO SUPABASE AUTH TEST BENCH RUNNING             `);
  console.log(`  Local URL: http://localhost:${PORT}                   `);
  console.log(`=======================================================`);
});
