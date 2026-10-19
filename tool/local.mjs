import { createHash, randomBytes } from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { readFile, writeFile, mkdir, access, unlink, readdir } from 'node:fs/promises';
import { fork, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { openSync, closeSync } from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';

const run = promisify(execFile);
const project = fileURLToPath(new URL('../', import.meta.url));
const api = path.join(project, 'api', 'revup-api');
const requireApi = createRequire(path.join(api, 'package.json'));
const { Client } = requireApi('pg');
const { parse } = requireApi('dotenv');
const workspaceId = createHash('sha256').update(project.toLowerCase()).digest('hex').slice(0, 12);
export const dataRoot = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), '.local', 'share'), 'RevUpLocal', workspaceId);
const localDir = path.join(project, '.local');
const dbDir = path.join(dataRoot, 'postgres');
const pipeName = process.platform === 'win32'
  ? `\\\\.\\pipe\\revup-local-${workspaceId}` : path.join(dataRoot, 'control.sock');
const credentialsFile = path.join(dataRoot, 'credentials.json');
const serverEnvFile = path.join(dataRoot, 'backend.env');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const exists = filename => access(filename).then(() => true, () => false);

export function isPrivateIpv4(host) {
  if (net.isIP(host) !== 4) return false;
  const [a, b] = host.split('.').map(Number);
  return a === 10 || (a === 192 && b === 168) || (a === 172 && b >= 16 && b <= 31);
}

export function chooseHost(explicit, interfaces = os.networkInterfaces()) {
  if (explicit) {
    if (!isPrivateIpv4(explicit)) throw new Error('Usa una IP privada de la PC, no localhost ni una IP pública.');
    const assigned = Object.values(interfaces).flat().some(item => item?.address === explicit);
    if (!assigned) throw new Error('La IP indicada no está asignada a esta PC.');
    return explicit;
  }
  const candidates = Object.entries(interfaces).flatMap(([name, addresses]) =>
    /loopback|vethernet|virtualbox|vmware|tailscale|docker|wsl/i.test(name) ? [] :
      addresses.filter(item => !item.internal && isPrivateIpv4(item.address)).map(item => item.address));
  const unique = [...new Set(candidates)];
  if (unique.length !== 1) throw new Error('No se pudo elegir una IP única. Usa -ServerIp con la IP de Ethernet/Wi-Fi.');
  return unique[0];
}

export function localEnvironment(settings, smtp = {}) {
  return {
    ...Object.fromEntries(Object.entries(smtp).filter(([key]) => key.startsWith('MAIL_'))),
    APP_ENV: 'local', NODE_ENV: 'development', PORT: String(settings.apiPort),
    APP_URL: `http://${settings.host}:${settings.apiPort}`,
    PGHOST: '127.0.0.1', PGPORT: String(settings.dbPort), PGUSER: 'revup_local',
    PGPASSWORD: settings.dbPassword, PGDATABASE: 'revup_local',
    JWT_SECRET: settings.jwtSecret, JWT_EXPIRES: '7d',
    UPLOAD_DIR: path.join(dataRoot, 'uploads'),
    REVUP_ENV_FILE: serverEnvFile,
  };
}

async function binaries() {
  if (process.platform !== 'win32' || process.arch !== 'x64') {
    throw new Error('Este lanzador está preparado para Windows x64. Para otros equipos usa PostgreSQL instalado o Docker.');
  }
  return import(pathToFileURL(requireApi.resolve('@embedded-postgres/windows-x64')).href);
}

async function configure(explicitHost) {
  const host = chooseHost(explicitHost);
  await mkdir(dataRoot, { recursive: true });
  await mkdir(localDir, { recursive: true });
  let settings;
  if (await exists(credentialsFile)) {
    try { settings = JSON.parse(await readFile(credentialsFile, 'utf8')); }
    catch { throw new Error('No se pudo leer la configuración privada local. No se sobrescribió ni se mostraron sus valores.'); }
  } else {
    settings = { version: 1, apiPort: 3000, dbPort: 55432,
      dbPassword: randomBytes(32).toString('hex'), jwtSecret: randomBytes(48).toString('hex'),
      adminPassword: `Local!${randomBytes(18).toString('hex')}` };
  }
  if (settings.version !== 1 || !settings.dbPassword || !settings.jwtSecret || !settings.adminPassword) {
    throw new Error('La configuración local está incompleta. No se sobrescribió ni se alteraron los datos.');
  }
  settings.host = host;
  const active = await control('status').catch(() => ({ ready: false }));
  if (active.ready && active.apiUrl !== `http://${host}:${settings.apiPort}`) {
    throw new Error('Detén el entorno antes de cambiar la IP y recompilar la APK.');
  }
  await writeFile(credentialsFile, JSON.stringify(settings, null, 2), { mode: 0o600 });
  let smtp = {};
  if (await exists(path.join(api, '.env'))) smtp = parse(await readFile(path.join(api, '.env')));
  const env = localEnvironment(settings, smtp);
  await writeFile(serverEnvFile, Object.entries(env).map(([key, value]) => `${key}=${JSON.stringify(value)}`).join('\n') + '\n', { mode: 0o600 });
  const url = env.APP_URL;
  await writeFile(path.join(localDir, 'flutter.local.json'), JSON.stringify({ APP_ENV: 'local', API_BASE_URL: url }, null, 2));
  await writeFile(path.join(localDir, 'runtime.json'), JSON.stringify({ dataRoot, apiUrl: url, apiPort: settings.apiPort, dbPort: settings.dbPort }, null, 2));
  return { settings, env };
}

async function ensurePostgres(settings) {
  const bin = await binaries();
  const versionFile = path.join(dbDir, 'PG_VERSION');
  if (!(await exists(versionFile))) {
    if (await exists(dbDir) && (await readdir(dbDir)).length) {
      throw new Error('La carpeta de PostgreSQL no está vacía y no tiene PG_VERSION. Se conservó sin cambios.');
    }
    const passwordFile = path.join(dataRoot, 'initdb-password.tmp');
    await writeFile(passwordFile, settings.dbPassword, { mode: 0o600 });
    try {
      console.log('Inicializando PostgreSQL real (solo la primera vez)...');
      await run(bin.initdb, ['-D', dbDir, '-U', 'revup_local', '--encoding=UTF8', '--no-locale',
        '--auth=scram-sha-256', `--pwfile=${passwordFile}`], { windowsHide: true, timeout: 60000 });
    } finally { await unlink(passwordFile).catch(() => {}); }
  } else if ((await readFile(versionFile, 'utf8')).trim() !== '16') {
    throw new Error('La base pertenece a otra versión de PostgreSQL. No se intentó modificarla.');
  }
  let running = false;
  try { await run(bin.pg_ctl, ['-D', dbDir, 'status'], { windowsHide: true }); running = true; }
  catch { /* El clúster todavía está detenido. */ }
  if (!running) {
    console.log('Iniciando PostgreSQL en 127.0.0.1:' + settings.dbPort);
    await run(bin.pg_ctl, ['-D', dbDir, '-l', path.join(dataRoot, 'postgres.log'), '-w', '-t', '40',
      '-o', `-h 127.0.0.1 -p ${settings.dbPort} -c timezone=America/Guayaquil`, 'start'],
    { windowsHide: true, timeout: 50000 });
  }
  const client = new Client({ host: '127.0.0.1', port: settings.dbPort, user: 'revup_local',
    password: settings.dbPassword, database: 'postgres', connectionTimeoutMillis: 5000 });
  try {
    await client.connect();
    const current = await client.query('SHOW data_directory');
    if (path.resolve(current.rows[0].data_directory).toLowerCase() !== path.resolve(dbDir).toLowerCase()) {
      throw new Error('El puerto pertenece a otra base. Se detuvo la preparación sin modificarla.');
    }
    const found = await client.query("SELECT 1 FROM pg_database WHERE datname='revup_local'");
    if (!found.rowCount) await client.query('CREATE DATABASE revup_local');
  } finally { await client.end(); }
}

async function prepareDatabase(settings, env) {
  Object.assign(process.env, env);
  const { pool, ensureSchema } = await import('../api/revup-api/db/connection.js');
  try {
    await ensureSchema();
    const found = await pool.query("SELECT id FROM usuarios WHERE usuario='admin.local'");
    if (!found.rowCount) {
      const bcrypt = requireApi('bcrypt');
      const hash = await bcrypt.hash(settings.adminPassword, 12);
      await pool.query(`INSERT INTO usuarios (nombre, correo, usuario, password_hash, role, verificado, verificado_en)
        VALUES ($1,$2,'admin.local',$3,'superuser',true,NOW())`,
      ['Administrador local', env.MAIL_USER || 'admin@revup.local', hash]);
    }
    await writeFile(path.join(dataRoot, 'access.txt'),
      `Acceso a la base LOCAL de esta PC\nUsuario: admin.local\nContraseña: ${settings.adminPassword}\n\n` +
      'Cuenta inicial creada por el administrador. No contiene datos del VPS.\nNo compartas este archivo ni lo subas a Git.\n', { mode: 0o600 });
  } finally { await pool.end(); }
}

async function stopPostgres() {
  if (!(await exists(path.join(dbDir, 'PG_VERSION')))) return;
  const bin = await binaries();
  try { await run(bin.pg_ctl, ['-D', dbDir, 'status'], { windowsHide: true }); }
  catch { return; }
  await run(bin.pg_ctl, ['-D', dbDir, '-m', 'fast', '-w', '-t', '30', 'stop'], { windowsHide: true, timeout: 40000 });
}

export function control(action) {
  return new Promise((resolve, reject) => {
    const socket = net.connect(pipeName);
    let data = '';
    socket.setTimeout(5000, () => socket.destroy(new Error('El control local no respondió')));
    socket.on('connect', () => socket.write(action + '\n'));
    socket.on('data', chunk => { data += chunk; });
    socket.on('end', () => { try { resolve(JSON.parse(data)); } catch (e) { reject(e); } });
    socket.on('error', reject);
  });
}

async function supervise(explicitHost) {
  let child;
  let stopping = false;
  let ready = false;
  let config;
  let finished;
  const done = new Promise(resolve => { finished = resolve; });
  const ipc = net.createServer({ allowHalfOpen: true }, socket => {
    let input = '';
    let answered = false;
    socket.on('error', () => {});
    socket.on('data', chunk => {
      input += chunk;
      if (answered || !input.includes('\n')) return;
      answered = true;
      const action = input.trim();
      socket.end(JSON.stringify({ running: true, ready, stopping, dataRoot,
        apiUrl: config?.env.APP_URL, pid: process.pid }));
      if (action === 'stop') void shutdown();
    });
  });
  const shutdown = async () => {
    if (stopping) return;
    stopping = true;
    ready = false;
    console.log('Deteniendo API y PostgreSQL; los datos se conservan...');
    if (child && child.exitCode === null && child.signalCode === null) {
      const exited = new Promise(resolve => child.once('exit', resolve));
      if (child.connected) child.send({ type: 'shutdown' });
      await Promise.race([exited, sleep(17000)]);
      if (child.exitCode === null && child.signalCode === null) child.kill();
    }
    await stopPostgres();
    ipc.close();
    finished();
  };
  await new Promise((resolve, reject) => { ipc.once('error', reject); ipc.listen(pipeName, resolve); });
  process.once('SIGINT', () => void shutdown());
  process.once('SIGTERM', () => void shutdown());
  try {
    config = await configure(explicitHost);
    await ensurePostgres(config.settings);
    await prepareDatabase(config.settings, config.env);
    const stdout = openSync(path.join(dataRoot, 'api.log'), 'a', 0o600);
    const stderr = openSync(path.join(dataRoot, 'api-error.log'), 'a', 0o600);
    child = fork(path.join(api, 'server.js'), [], { cwd: api, env: { ...process.env, ...config.env },
      stdio: ['ignore', stdout, stderr, 'ipc'], windowsHide: true });
    closeSync(stdout); closeSync(stderr);
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('La API no inició a tiempo. Revisa api-error.log.')), 40000);
      child.once('error', error => { clearTimeout(timer); reject(error); });
      child.once('exit', code => { clearTimeout(timer); reject(new Error(`La API terminó (${code}). Revisa api-error.log.`)); });
      child.on('message', message => { if (message?.type === 'ready') { clearTimeout(timer); resolve(); } });
    });
    ready = true;
    console.log(`API lista: ${config.env.APP_URL}/health`);
    console.log(`Datos y acceso privado: ${dataRoot}`);
    child.once('exit', () => { if (!stopping) void shutdown(); });
    await done;
  } catch (error) {
    await shutdown();
    throw error;
  }
}

async function main() {
  const action = process.argv[2] || 'status';
  const hostIndex = process.argv.indexOf('--host');
  const explicitHost = hostIndex >= 0 ? process.argv[hostIndex + 1] : undefined;
  if (action === 'status' || action === 'stop') {
    try { console.log(JSON.stringify(await control(action))); }
    catch (error) {
      if (!['ENOENT', 'ECONNREFUSED'].includes(error.code)) throw error;
      if (action === 'stop') await stopPostgres();
      console.log(JSON.stringify({ running: false, dataRoot }));
    }
    return;
  }
  if (action === 'start') return supervise(explicitHost);
  if (!['configure', 'setup'].includes(action)) throw new Error('Acción desconocida');
  const { settings, env } = await configure(explicitHost);
  if (action === 'setup') {
    const active = await control('status').catch(() => ({ running: false }));
    if (active.running) throw new Error('Detén el entorno antes de ejecutar Setup.');
    try { await ensurePostgres(settings); await prepareDatabase(settings, env); }
    finally { await stopPostgres(); }
  }
  console.log(JSON.stringify({ apiUrl: env.APP_URL, dataRoot, settingsFile: path.join(localDir, 'flutter.local.json') }));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
