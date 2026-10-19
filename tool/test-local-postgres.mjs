import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { readFile, writeFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { dataRoot, control } from './local.mjs';

const api = fileURLToPath(new URL('../api/revup-api/', import.meta.url));
const requireApi = createRequire(path.join(api, 'package.json'));
const { Client } = requireApi('pg');
const status = await control('status');
if (!status.ready) throw new Error('Inicia primero el entorno local.');
const settings = JSON.parse(await readFile(path.join(dataRoot, 'credentials.json'), 'utf8'));
const database = 'revup_validation_' + Date.now();
const client = new Client({ host: '127.0.0.1', port: settings.dbPort, user: 'revup_local',
  password: settings.dbPassword, database: 'postgres' });
await client.connect();
try { await client.query(`CREATE DATABASE ${database}`); }
finally { await client.end(); }
const url = new URL('postgresql://127.0.0.1');
url.port = String(settings.dbPort); url.username = 'revup_local'; url.password = settings.dbPassword; url.pathname = '/' + database;
console.log('Pruebas HTTP con PostgreSQL real, base aislada: ' + database);
const processTest = spawn(process.execPath, ['--test', 'test/app.test.js'], {
  cwd: api, env: { ...process.env, REVUP_TEST_DATABASE_URL: url.href }, stdio: 'inherit', windowsHide: true,
});
const code = await new Promise((resolve, reject) => { processTest.once('exit', resolve); processTest.once('error', reject); });
await writeFile(path.join(dataRoot, 'last-validation.json'), JSON.stringify({
  database, date: new Date().toISOString(), exitCode: code, engine: 'PostgreSQL 16 (native)',
  note: 'Base separada de la presentación; conservada sin eliminar datos.',
}, null, 2));
process.exitCode = code ?? 1;
