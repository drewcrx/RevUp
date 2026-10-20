import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readdir, readFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { PGlite } from '@electric-sql/pglite';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import pg from 'pg';

// Nunca se usa la BD del .env. El runner puede aportar una BD real aislada.
process.env.JWT_SECRET = 'revup-test-secret-only';
process.env.UPLOAD_DIR = await mkdtemp(path.join(os.tmpdir(), 'revup-tests-'));
const { pool, ensureSchema } = await import('../db/connection.js');
const { startServer } = await import('../server.js');
const realDb = process.env.REVUP_TEST_DATABASE_URL
  ? new pg.Pool({ connectionString: process.env.REVUP_TEST_DATABASE_URL, max: 4 }) : null;
const db = realDb || new PGlite();
let server;
let base;
let mechanic;
let other;
let admin;
let validPasswordHash;

const query = async (sql, params) => {
  if (realDb) return realDb.query(sql, params);
  const result = !params && sql.includes(';')
    ? (await db.exec(sql)).at(-1)
    : await db.query(sql, params);
  return { rows: result.rows, rowCount: Math.max(result.affectedRows ?? 0, result.rows.length) };
};
pool.query = query;
// Equivale a un pool con una conexión: cada transacción retiene el cliente.
let available = Promise.resolve();
pool.connect = async () => {
  if (realDb) return realDb.connect();
  const previous = available;
  let release;
  available = new Promise(resolve => { release = resolve; });
  await previous;
  return { query, release };
};

function token(user, expiresIn = '1h') {
  return jwt.sign(user, process.env.JWT_SECRET, { expiresIn });
}

async function request(url, { user = mechanic, method = 'GET', body, rawBody } = {}) {
  const response = await fetch(`${base}${url}`, {
    method,
    headers: {
      ...(user ? { Authorization: `Bearer ${token(user)}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: rawBody ?? (body ? JSON.stringify(body) : undefined),
  });
  const contentType = response.headers.get('content-type') || '';
  const data = contentType.includes('application/json') ? await response.json() : await response.text();
  return { status: response.status, data };
}

async function createOt() {
  const created = await request('/ordenes', {
    method: 'POST', body: { placa: 'TEST-001', symptoms: 'Ruido' },
  });
  assert.equal(created.status, 201, JSON.stringify(created.data));
  return created.data.id;
}

before(async () => {
  server = await startServer({ port: 0 });
  base = `http://127.0.0.1:${server.address().port}`;
  validPasswordHash = await bcrypt.hash('Password123', 4);
  for (const [name, role] of [['mecanico', 'mechanic'], ['otro', 'mechanic'], ['admin', 'superuser']]) {
    const inserted = await query(`INSERT INTO usuarios
      (nombre, correo, usuario, password_hash, verificado, role)
      VALUES ($1, $2, $1, $3, true, $4) RETURNING id, role`,
    [name, `${name}@test.invalid`, validPasswordHash, role]);
    if (name === 'mecanico') mechanic = inserted.rows[0];
    if (name === 'otro') other = inserted.rows[0];
    if (name === 'admin') admin = inserted.rows[0];
  }
  const created = await request('/vehiculos', {
    method: 'POST', body: { marca: 'Toyota', modelo: 'Yaris', placa: 'TEST-001', kilometraje: 500 },
  });
  assert.equal(created.status, 200, JSON.stringify(created.data));
});

after(async () => {
  if (server) await new Promise(resolve => server.close(resolve));
  if (realDb) await realDb.end();
  else await db.close();
  await pool.end();
});

test('una base vacía arranca y el esquema puede ejecutarse de nuevo sin perder datos', async () => {
  await ensureSchema();
  const health = await request('/health', { user: null });
  assert.equal(health.status, 200);
  assert.equal((await query('SELECT COUNT(*)::int AS n FROM vehiculos')).rows[0].n, 1);
  const catalogs = await request('/catalogos/marcas');
  assert.equal(catalogs.status, 200);
  assert.ok(catalogs.data.length > 0);
  const login = await request('/usuarios/login', {
    user: null, method: 'POST', body: { usuario: 'mecanico', password: 'Password123' },
  });
  assert.equal(login.status, 200);
  assert.equal(jwt.verify(login.data.token, process.env.JWT_SECRET).id, mechanic.id);
});

test('crear una OT ajena o inexistente no modifica kilometraje ni crea órdenes', async () => {
  for (const placa of ['TEST-001', 'NO-EXISTE']) {
    const response = await request('/ordenes', {
      user: other, method: 'POST', body: { placa, symptoms: 'Ruido', kilometraje: 9999 },
    });
    assert.equal(response.status, 404);
  }
  assert.equal((await query("SELECT kilometraje FROM vehiculos WHERE placa='TEST-001'")).rows[0].kilometraje, 500);
  assert.equal((await query('SELECT COUNT(*)::int AS n FROM ordenes_trabajo')).rows[0].n, 0);
});

test('el arranque migra propietarios heredados conservando el vehículo y no los duplica', async () => {
  await query(`INSERT INTO vehiculos
    (marca, modelo, placa, mechanic_id, propietario_nombre, propietario_telefono)
    VALUES ('Toyota', 'Yaris', 'LEGACY-001', $1, 'Propietaria heredada', '0999')`, [mechanic.id]);
  await ensureSchema();
  const first = await query(`SELECT v.id, v.propietario_id, p.nombre, p.telefono
    FROM vehiculos v JOIN propietarios p ON p.id=v.propietario_id WHERE v.placa='LEGACY-001'`);
  assert.equal(first.rows[0].nombre, 'Propietaria heredada');
  assert.equal(first.rows[0].telefono, '0999');
  await ensureSchema();
  const second = await query("SELECT id, propietario_id FROM vehiculos WHERE placa='LEGACY-001'");
  assert.equal(second.rows[0].id, first.rows[0].id);
  assert.equal(second.rows[0].propietario_id, first.rows[0].propietario_id);
  assert.equal((await query("SELECT COUNT(*)::int AS n FROM propietarios WHERE nombre='Propietaria heredada'")).rows[0].n, 1);
});

test('mecánico propio y superuser pueden crear OTs, conservando snapshot de kilometraje', async () => {
  const own = await request('/ordenes', { method: 'POST', body: {
    placa: ' test-001 ', symptoms: 'Ruido', kilometraje: 700,
  } });
  assert.equal(own.status, 201);
  assert.equal(own.data.kilometraje_ot, 700);
  const elevated = await request('/ordenes', { user: admin, method: 'POST', body: {
    placa: 'TEST-001', symptoms: 'Revisión', kilometraje: 600,
  } });
  assert.equal(elevated.status, 201);
  assert.equal(elevated.data.mechanic_id, admin.id);
  assert.equal(elevated.data.kilometraje_ot, 600);
  assert.equal((await query("SELECT kilometraje FROM vehiculos WHERE placa='TEST-001'")).rows[0].kilometraje, 700);
});

test('cargos, saldo, pago y entrega mantienen sus totales y bloquean cambios posteriores', async () => {
  const id = await createOt();
  const post = (suffix, body, user) => request(`/ordenes/${id}/${suffix}`, { method: 'POST', body, user });
  assert.equal((await post('servicios', { descripcion: 'Mano de obra', precio: 50 })).status, 201);
  assert.equal((await post('repuestos', { nombre: 'Filtro', cantidad: 2, costoUnitario: 5, precioUnitario: 10 })).status, 201);
  assert.equal((await post('cerrar')).status, 400);
  assert.equal((await post('pagos', { monto: 70 })).status, 201);
  const delivered = await post('cerrar');
  assert.equal(delivered.status, 200);
  assert.equal(Number(delivered.data.total), 70);
  assert.equal(delivered.data.estado, 'ENTREGADO');
  assert.equal(delivered.data.pago_estado, 'PAGADO');
  for (const user of [mechanic, admin]) {
    assert.equal((await post('servicios', { descripcion: 'Extra', precio: 5 }, user)).status, 409);
    assert.equal((await post('repuestos', { nombre: 'Extra', costoUnitario: 0, precioUnitario: 5 }, user)).status, 409);
    assert.equal((await post('pagos', { monto: 5 }, user)).status, 409);
    assert.equal((await post('cerrar', undefined, user)).status, 409);
  }
  const detail = await request(`/ordenes/${id}`);
  assert.equal(detail.status, 200);
  assert.equal(detail.data.servicios.length, 1);
  assert.equal(detail.data.repuestos.length, 1);
  assert.equal(detail.data.pagos.length, 1);
  assert.equal(new Date(detail.data.ot.closed_at).getTime(), new Date(delivered.data.closed_at).getTime());
});

test('una orden sin cargos puede entregarse sin cobrar', async () => {
  const id = await createOt();
  assert.equal((await request(`/ordenes/${id}/cerrar`, { method: 'POST' })).status, 200);
});

test('un mecánico no puede alterar ni consultar la OT de otro', async () => {
  const id = await createOt();
  assert.equal((await request(`/ordenes/${id}`, { user: other })).status, 404);
  for (const [suffix, body] of [
    ['servicios', { descripcion: 'Extra', precio: 5 }],
    ['repuestos', { nombre: 'Extra', costoUnitario: 0, precioUnitario: 5 }],
    ['pagos', { monto: 5 }], ['cerrar', undefined],
  ]) {
    assert.equal((await request(`/ordenes/${id}/${suffix}`, { user: other, method: 'POST', body })).status, 404);
  }
});

test('un fallo SQL revierte el cargo y libera la transacción', async () => {
  const id = await createOt();
  const original = pool.connect;
  pool.connect = async () => {
    const client = await original();
    return { ...client, query: (sql, params) => sql.includes('UPDATE ordenes_trabajo\n     SET total_servicios')
      ? Promise.reject(new Error('Fallo de prueba durante el recálculo')) : client.query(sql, params) };
  };
  try {
    const result = await request(`/ordenes/${id}/servicios`, {
      method: 'POST', body: { descripcion: 'Prueba', precio: 5 },
    });
    assert.equal(result.status, 500);
  } finally { pool.connect = original; }
  assert.equal((await query('SELECT COUNT(*)::int AS n FROM orden_servicios WHERE orden_id=$1', [id])).rows[0].n, 0);
  assert.equal((await request(`/ordenes/${id}/cerrar`, { method: 'POST' })).status, 200);
});

test('los tres endpoints aceptan una foto multipart y guardan sus bytes', async () => {
  const id = await createOt();
  const dano = await request(`/ordenes/${id}/danos`, { method: 'POST', body: { vista: 'frontal', zona: 'capo' } });
  const act = await request(`/ordenes/${id}/actualizaciones`, { method: 'POST', body: { nota: 'Avance' } });
  assert.equal(dano.status, 201);
  assert.equal(act.status, 201);
  const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7S8AAAAASUVORK5CYII=', 'base64');
  for (const url of [`/ordenes/${id}/fotos`, `/ordenes/danos/${dano.data.id}/fotos`, `/ordenes/actualizaciones/${act.data.id}/fotos`]) {
    const form = new FormData();
    form.append('tipo', 'ingreso');
    form.append('fotos', new Blob([bytes], { type: 'image/png' }), 'foto.png');
    const uploaded = await request(url, { method: 'POST', rawBody: form });
    assert.equal(uploaded.status, 201, JSON.stringify(uploaded.data));
    const onDisk = await readFile(path.join(process.env.UPLOAD_DIR, uploaded.data[0].ruta));
    assert.deepEqual(onDisk, bytes);
  }
  assert.ok((await readdir(process.env.UPLOAD_DIR)).length >= 3);
});

test('JWT ausente o expirado se rechaza y una contraseña actual incorrecta conserva la sesión', async () => {
  assert.equal((await request('/vehiculos', { user: null })).status, 401);
  const expired = await fetch(`${base}/vehiculos`, { headers: { Authorization: `Bearer ${token(mechanic, -1)}` } });
  assert.equal(expired.status, 401);
  await expired.text();
  assert.equal((await request('/usuarios/password', {
    method: 'PUT', body: { currentPassword: 'incorrecta', newPassword: 'NuevaClave123' },
  })).status, 400);
});

test('un error preparando el esquema impide escuchar y health detecta una caída de BD', async () => {
  let listened = false;
  await assert.rejects(startServer({
    prepareSchema: async () => { throw new Error('BD caída'); },
    application: { listen: () => { listened = true; } },
  }), /BD caída/);
  assert.equal(listened, false);
  const original = pool.query;
  pool.query = async () => { throw new Error('BD caída'); };
  try {
    assert.equal((await request('/health', { user: null })).status, 503);
  } finally { pool.query = original; }
});

test('CRUD real de propietario y vehículo, lectura QR y eliminación del registro de prueba', async () => {
  const owner = await request('/propietarios', { method: 'POST', body: { nombre: 'Propietario prueba CRUD', telefono: '0990000000' } });
  assert.equal(owner.status, 201);
  const vehicle = await request('/vehiculos', { method: 'POST', body: {
    marca: 'Toyota', modelo: 'Yaris', placa: 'CRUD-001', propietario_id: owner.data.id, kilometraje: 10,
  } });
  assert.equal(vehicle.status, 200);
  assert.equal((await request('/propietarios/' + owner.data.id, { method: 'PUT', body: { nombre: 'Propietario actualizado' } })).status, 200);
  assert.equal((await request('/vehiculos/CRUD-001', { method: 'PUT', body: { color: 'Azul', kilometraje: 20 } })).status, 200);
  const read = await request('/vehiculos/CRUD-001');
  assert.equal(read.status, 200);
  assert.equal(read.data.color, 'Azul');
  assert.equal(Number(read.data.kilometraje), 20);
  assert.equal(read.data.propietario_nombre, 'Propietario actualizado');
  const qr = vehicle.data.qr_token;
  assert.equal((await request('/vehiculos/qr/' + qr)).status, 200);
  assert.equal((await request('/vehiculos/qr/' + qr + '/historial')).status, 200);
  const publicPage = await request('/v/' + qr, { user: null });
  assert.equal(publicPage.status, 200);
  assert.match(publicPage.data, /CRUD-001/);
  assert.equal((await request('/vehiculos/CRUD-001', { method: 'DELETE' })).status, 200);
  assert.equal((await request('/vehiculos/CRUD-001')).status, 404);
});

test('entrega y cargo simultáneos nunca dejan una OT entregada con deuda', async () => {
  const id = await createOt();
  const [closed, charged] = await Promise.all([
    request(`/ordenes/${id}/cerrar`, { method: 'POST' }),
    request(`/ordenes/${id}/servicios`, { method: 'POST', body: { descripcion: 'Cargo concurrente', precio: 5 } }),
  ]);
  assert.ok((closed.status === 200 && charged.status === 409) ||
    (closed.status === 400 && charged.status === 201), JSON.stringify({ closed, charged }));
  const detail = await request(`/ordenes/${id}`);
  if (detail.data.ot.estado === 'ENTREGADO') {
    assert.equal(Number(detail.data.ot.total), 0);
    assert.equal(detail.data.servicios.length, 0);
  } else {
    assert.equal(Number(detail.data.ot.total), 5);
    assert.equal(detail.data.ot.pago_estado, 'PENDIENTE');
  }
});

test('importes con coma se conservan y se rechazan importes ambiguos y meses imposibles', async () => {
  const id=await createOt();
  assert.equal((await request(`/ordenes/${id}/servicios`,{method:'POST',body:{descripcion:'Decimal',precio:'12,50'}})).status,201);
  assert.equal(Number((await request(`/ordenes/${id}`)).data.ot.total),12.5);
  for(const precio of ['NaN','Infinity','12,345','1,234.56',null,-1]) {
    assert.equal((await request(`/ordenes/${id}/servicios`,{method:'POST',body:{descripcion:'Invalido',precio}})).status,400);
  }
  assert.equal((await request('/reportes/mi-resumen?month=2026-13')).status,400);
  assert.equal((await request('/reportes/mi-resumen?month=2026-00')).status,400);
});

test('los pagos repetidos se reproducen sin duplicar y el saldo nunca admite sobrecobro',async()=>{
  const id=await createOt(),base=`/ordenes/${id}`;
  await request(base+'/servicios',{method:'POST',body:{descripcion:'Trabajo',precio:100}});
  const pay=(key,monto=25)=>request(base+'/pagos',{method:'POST',body:{monto,metodo:'EFECTIVO',operacionId:key}});
  const key='payment-idempotent-000001';
  const first=await pay(key),again=await pay(key);
  assert.equal(first.status,201);assert.equal(again.data.id,first.data.id);
  assert.equal((await pay(key,26)).status,409);
  const parallel=await Promise.all([pay('payment-distinct-000002',50),pay('payment-distinct-000003',50)]);
  assert.deepEqual(parallel.map(r=>r.status).sort(),[201,409]);
  const detail=await request(base);
  assert.equal(detail.data.pagos.length,2);
  assert.equal(detail.data.pagos.reduce((sum,p)=>sum+Number(p.monto),0),75);
  await pay('payment-distinct-000004',25);
  assert.equal((await request(base+'/cerrar',{method:'POST'})).status,200);
  assert.equal((await pay(key)).data.id,first.data.id);
});

test('archivar conserva pagos e historial, impide nuevas visitas y permite restaurar',async()=>{
  const vehicle=await request('/vehiculos',{method:'POST',body:{marca:'Toyota',modelo:'Yaris',placa:'ARCH-001',kilometraje:10}});
  assert.equal(vehicle.status,200);
  const created=await request('/ordenes',{method:'POST',body:{placa:'ARCH-001',symptoms:'Revision',kilometraje:20}});
  const id=created.data.id;
  await request(`/ordenes/${id}/servicios`,{method:'POST',body:{descripcion:'Revision',precio:5}});
  await request(`/ordenes/${id}/pagos`,{method:'POST',body:{monto:5}});
  const removed=await request('/vehiculos/ARCH-001',{method:'DELETE'});
  assert.equal(removed.data.archivado,true);
  assert.equal((await request(`/ordenes/${id}`)).data.pagos.length,1);
  assert.ok(!(await request('/vehiculos')).data.some(v=>v.placa==='ARCH-001'));
  assert.ok((await request('/vehiculos?archivados=solo')).data.some(v=>v.placa==='ARCH-001'));
  assert.equal((await request('/ordenes',{method:'POST',body:{placa:'ARCH-001',symptoms:'Otra visita'}})).status,404);
  assert.equal((await request('/vehiculos/ARCH-001/archivo',{user:other,method:'PUT',body:{archivado:false}})).status,404);
  assert.equal((await request('/vehiculos/ARCH-001/archivo',{method:'PUT',body:{archivado:false}})).status,200);
  assert.ok((await request('/vehiculos')).data.some(v=>v.placa==='ARCH-001'));
});

test('etapas independientes, listas de revision y documentos cerrados conservan trazabilidad',async()=>{
  const id=await createOt(),base=`/ordenes/${id}`,tools=`/taller/ordenes/${id}`;
  await request(base+'/servicios',{method:'POST',body:{descripcion:'Sin costo',precio:0}});
  assert.equal((await request(base)).data.ot.fase,'RECIBIDO');
  assert.equal((await request(tools+'/etapa',{method:'PUT',body:{fase:'LISTO'}})).data.fase,'LISTO');
  const checklist={combustible:50,accesorios:'Llave',observaciones:'Revisado',revision_danos:'SIN_DANOS',revisado:true};
  assert.equal((await request(tools+'/checklist/ingreso',{method:'PUT',body:checklist})).status,200);
  assert.equal((await request(tools+'/checklist/ingreso',{user:other,method:'PUT',body:checklist})).status,404);
  await request(base+'/diagnostico',{method:'PUT',body:{diagnostico:'Original'}});
  assert.equal((await request(base+'/cerrar',{method:'POST'})).status,200);
  assert.equal((await request(base+'/diagnostico',{method:'PUT',body:{diagnostico:'Cambio'}})).status,409);
  assert.equal((await request(base+'/danos',{method:'POST',body:{vista:'frontal',zona:'Capó',tipo:'ingreso'}})).status,409);
  assert.equal((await request(tools+'/checklist/ingreso',{method:'PUT',body:checklist})).status,409);
  assert.equal((await request(base+'/danos',{method:'POST',body:{vista:'frontal',zona:'Capó',tipo:'entrega'}})).status,201);
  assert.equal((await request(tools+'/anotaciones',{method:'POST',body:{texto:'Correccion fechada'}})).status,200);
  const detail=await request(base);
  assert.equal(detail.data.ot.diagnostico,'Original');
  assert.ok(detail.data.anotaciones.some(n=>n.texto==='Correccion fechada' && n.autor==='mecanico'));
  assert.equal((await request(tools+'/checklist/entrega',{method:'PUT',body:checklist})).status,409);
});

test('inventario descuenta piezas atomicamente y registra movimientos sin existencias negativas',async()=>{
  const item=await request('/taller/inventario',{method:'POST',body:{nombre:'Filtro auditado',sku:'STOCK-001',existencias:5,minimo:2,costo:3,precio:7}});
  assert.equal(item.status,200);
  const stock=item.data;
  assert.ok(!(await request('/taller/inventario',{user:other})).data.some(i=>i.id===stock.id));
  const id1=await createOt(),id2=await createOt();
  const charge=id=>request(`/ordenes/${id}/repuestos`,{method:'POST',body:{nombre:'Filtro auditado',cantidad:4,costoUnitario:0,precioUnitario:7,inventarioId:stock.id}});
  const results=await Promise.all([charge(id1),charge(id2)]);
  assert.deepEqual(results.map(r=>r.status).sort(),[201,409]);
  assert.equal((await request('/taller/inventario')).data.find(i=>i.id===stock.id).existencias,1);
  const successful=results[0].status===201?id1:id2;
  assert.equal(Number((await request(`/ordenes/${successful}`)).data.repuestos[0].costo_unitario),3);
  const movement={cantidad:2,motivo:'Reposicion',operacionId:'stock-adjustment-000001'};
  const first=await request(`/taller/inventario/${stock.id}/movimientos`,{method:'POST',body:movement});
  const second=await request(`/taller/inventario/${stock.id}/movimientos`,{method:'POST',body:movement});
  assert.equal(first.data.id,second.data.id);
  assert.equal((await request('/taller/inventario')).data.find(i=>i.id===stock.id).existencias,3);
  assert.equal((await request(`/taller/inventario/${stock.id}/movimientos`,{user:other,method:'POST',body:{...movement,operacionId:'stock-adjustment-000002'}})).status,404);
  const edit={nombre:'Filtro actualizado',sku:'STOCK-001',minimo:1,costo:4,precio:8};
  assert.equal((await request(`/taller/inventario/${stock.id}`,{user:other,method:'PUT',body:edit})).status,404);
  const updated=await request(`/taller/inventario/${stock.id}`,{method:'PUT',body:edit});
  assert.equal(updated.status,200);assert.equal(updated.data.existencias,3);
  assert.equal(Number((await request(`/ordenes/${successful}`)).data.repuestos[0].costo_unitario),3);
});

test('recordatorios validan fecha y kilometraje y respetan el propietario del registro',async()=>{
  const created=await request('/taller/recordatorios',{method:'POST',body:{placa:'TEST-001',titulo:'Proximo aceite',fecha:'2020-01-01',kilometraje:100}});
  assert.equal(created.status,200);
  const list=await request('/taller/recordatorios');
  assert.equal(list.data.find(r=>r.id===created.data.id).vencido,true);
  assert.ok(!(await request('/taller/recordatorios',{user:other})).data.some(r=>r.id===created.data.id));
  assert.equal((await request('/taller/recordatorios',{method:'POST',body:{placa:'TEST-001',titulo:'Fecha invalida',fecha:'2026-02-31'}})).status,400);
  assert.equal((await request('/taller/recordatorios',{method:'POST',body:{placa:'TEST-001',titulo:'Sin umbral'}})).status,400);
  assert.equal((await request(`/taller/recordatorios/${created.data.id}`,{user:other,method:'PUT',body:{completado:true}})).status,404);
  assert.equal((await request(`/taller/recordatorios/${created.data.id}`,{method:'PUT',body:{completado:true}})).data.completado,true);
  assert.equal((await request('/taller/recordatorios')).data.find(r=>r.id===created.data.id).vencido,false);
});
