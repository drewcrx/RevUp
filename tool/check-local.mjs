import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { dataRoot, control } from './local.mjs';

const requireApi = createRequire(fileURLToPath(new URL('../api/revup-api/package.json', import.meta.url)));
const { Client } = requireApi('pg');
const status = await control('status');
assert.equal(status.ready, true, 'El entorno local no está listo');
const settings = JSON.parse(await readFile(path.join(dataRoot, 'credentials.json'), 'utf8'));
const health = await fetch(status.apiUrl + '/health');
assert.equal(health.status, 200);
assert.equal((await health.json()).ok, true);
const login = await fetch(status.apiUrl + '/usuarios/login', {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ usuario: 'admin.local', password: settings.adminPassword }),
});
assert.equal(login.status, 200, 'El login real de la cuenta local falló');
const session = await login.json();
const jwt = requireApi('jsonwebtoken');
assert.equal(jwt.verify(session.token, settings.jwtSecret).role, 'superuser');
console.log('Login real y JWT local: correctos (credenciales y token no se imprimen)');
const month = new Date().toISOString().slice(0, 7);
for (const endpoint of ['/vehiculos', '/ordenes', '/propietarios', '/catalogos/marcas',
  '/catalogos/items/color', '/catalogos/repuestos', `/reportes/resumen?month=${month}`,
  `/reportes/mecanicos?month=${month}`, `/reportes/mi-resumen?month=${month}`]) {
  const result = await fetch(status.apiUrl + endpoint, { headers: { Authorization: 'Bearer ' + session.token } });
  const body = await result.text();
  assert.equal(result.status, 200, `Fallo en ${endpoint}: ${body}`);
  JSON.parse(body);
  console.log('HTTP 200 ' + endpoint);
}

if (process.argv.includes('--snapshot') || process.argv.includes('--compare')) {
  const validation = JSON.parse(await readFile(path.join(dataRoot, 'last-validation.json'), 'utf8'));
  assert.match(validation.database, /^revup_validation_\d+$/);
  const client = new Client({ host: '127.0.0.1', port: settings.dbPort, user: 'revup_local',
    password: settings.dbPassword, database: validation.database });
  await client.connect();
  let snapshot;
  try {
    snapshot = { database: validation.database, counts: (await client.query(`SELECT
      (SELECT COUNT(*)::int FROM usuarios) AS usuarios,
      (SELECT COUNT(*)::int FROM vehiculos) AS vehiculos,
      (SELECT COUNT(*)::int FROM ordenes_trabajo) AS ordenes,
      (SELECT COUNT(*)::int FROM orden_pagos) AS pagos`)).rows[0] };
  } finally { await client.end(); }
  const snapshotFile = path.join(dataRoot, 'persistence-check.json');
  if (process.argv.includes('--snapshot')) {
    await writeFile(snapshotFile, JSON.stringify(snapshot, null, 2));
    console.log('Guardada referencia de persistencia de la base de validación.');
  } else {
    assert.deepEqual(snapshot, JSON.parse(await readFile(snapshotFile, 'utf8')));
    console.log('Persistencia tras reiniciar PostgreSQL y la API: correcta.');
  }
}
