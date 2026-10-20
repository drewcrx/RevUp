import express from 'express';
import crypto from 'node:crypto';
import { pool } from '../db/connection.js';
import { requireAuth } from '../src/middleware/auth.js';
import { money } from '../utils/money.js';

const router=express.Router();
router.use(requireAuth);
const fail=(status,message)=>Object.assign(new Error(message),{status});
const integer=v=>v!==null && v!=='' && Number.isSafeInteger(Number(v)) && Number(v)>=0 && Number(v)<=2147483647;
async function transaction(req,res,work) {
  const client=await pool.connect();
  try { await client.query('BEGIN'); const result=await work(client); await client.query('COMMIT'); res.json(result); }
  catch(e) {await client.query('ROLLBACK'); res.status(e.status || 500).json({error:e.status?e.message:'No se pudo completar la operacion'});}
  finally {client.release();}
}
async function order(client,id,user) {
  const q=await client.query(`SELECT * FROM ordenes_trabajo WHERE id=$1
    AND ($2::text='superuser' OR mechanic_id=$3) FOR UPDATE`,[Number(id),user.role,user.id]);
  if(!q.rowCount) throw fail(404,'Orden no encontrada');
  return q.rows[0];
}
async function note(client,ot,user,text,clase='EVENTO') {
  return (await client.query(`INSERT INTO orden_anotaciones (orden_id,autor_id,texto,clase)
    VALUES ($1,$2,$3,$4) RETURNING *`,[ot.id,user.id,text,clase])).rows[0];
}

router.put('/ordenes/:id/etapa',(req,res)=>transaction(req,res,async client=>{
  const ot=await order(client,req.params.id,req.user);
  if(ot.estado==='ENTREGADO') throw fail(409,'La orden ya fue entregada');
  const fase=req.body.fase;
  if(!['RECIBIDO','EN_PROCESO','LISTO'].includes(fase)) throw fail(400,'Etapa invalida');
  const q=await client.query('UPDATE ordenes_trabajo SET fase=$1,estado=$2 WHERE id=$3 RETURNING *',
    [fase,fase==='RECIBIDO'?'RECIBIDO':'PENDIENTE',ot.id]);
  if(ot.fase!==fase) await note(client,ot,req.user,`Etapa: ${fase}`);
  return q.rows[0];
}));

router.put('/ordenes/:id/checklist/:tipo',(req,res)=>transaction(req,res,async client=>{
  const ot=await order(client,req.params.id,req.user);
  const tipo=req.params.tipo;
  if(!['ingreso','entrega'].includes(tipo)) throw fail(400,'Etapa de inspeccion invalida');
  if(ot.estado==='ENTREGADO' && tipo==='ingreso') throw fail(409,'La recepcion quedo cerrada al entregar. Agrega una anotacion.');
  const b=req.body;
  const combustible=b.combustible == null?null:Number(b.combustible);
  if(combustible!==null && (!integer(combustible) || combustible>100)) throw fail(400,'Combustible invalido');
  const revision=b.revision_danos || 'PENDIENTE';
  if(!['PENDIENTE','SIN_DANOS','CON_DANOS'].includes(revision)) throw fail(400,'Revision invalida');
  if(typeof b.revisado!=='boolean') throw fail(400,'Indica si la inspeccion fue revisada');
  if(b.revisado && revision==='PENDIENTE') throw fail(400,'Completa la revision de danos');
  if(revision==='SIN_DANOS') {
    const danos=await client.query('SELECT id FROM orden_danos WHERE orden_id=$1 AND tipo=$2 LIMIT 1',[ot.id,tipo]);
    if(danos.rowCount) throw fail(409,'Hay danos registrados en esta etapa. Selecciona Con danos.');
  }
  if(revision==='CON_DANOS') {
    const danos=await client.query('SELECT id FROM orden_danos WHERE orden_id=$1 AND tipo=$2 LIMIT 1',[ot.id,tipo]);
    if(!danos.rowCount) throw fail(409,'Registra primero los danos encontrados');
  }
  const q=await client.query(`INSERT INTO orden_checklists
    (orden_id,tipo,combustible,accesorios,observaciones,revision_danos,revisado,autor_id)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(orden_id,tipo) DO UPDATE SET
    combustible=EXCLUDED.combustible,accesorios=EXCLUDED.accesorios,observaciones=EXCLUDED.observaciones,
    revision_danos=EXCLUDED.revision_danos,revisado=EXCLUDED.revisado,autor_id=EXCLUDED.autor_id,updated_at=NOW() RETURNING *`,
    [ot.id,tipo,combustible,String(b.accesorios||'').trim().slice(0,1000),String(b.observaciones||'').trim().slice(0,2000),revision,b.revisado,req.user.id]);
  await note(client,ot,req.user,`Lista de ${tipo}: ${b.revisado?'revisada':'pendiente'}`);
  return q.rows[0];
}));

router.post('/ordenes/:id/anotaciones',(req,res)=>transaction(req,res,async client=>{
  const ot=await order(client,req.params.id,req.user);
  const texto=String(req.body.texto||'').trim();
  if(!texto || texto.length>2000) throw fail(400,'Escribe una anotacion de hasta 2000 caracteres');
  return note(client,ot,req.user,texto,'NOTA');
}));

router.get('/inventario',async(req,res)=>{
  const q=await pool.query(`SELECT * FROM inventario WHERE activo=true AND
    ($1::text='superuser' OR mechanic_id=$2) ORDER BY nombre`,[req.user.role,req.user.id]);
  res.json(q.rows);
});
router.post('/inventario',(req,res)=>transaction(req,res,async client=>{
  const b=req.body, costo=money(b.costo), precio=money(b.precio);
  if(!String(b.nombre||'').trim() || !String(b.sku||'').trim() || costo===null || precio===null
    || !integer(b.existencias) || !integer(b.minimo)) throw fail(400,'Completa nombre, codigo, existencias, minimo e importes validos');
  const existing=await client.query('SELECT id FROM inventario WHERE mechanic_id=$1 AND sku=$2',[req.user.id,String(b.sku).trim().toUpperCase()]);
  if(existing.rowCount) throw fail(409,'Ya existe ese codigo de repuesto');
  const q=await client.query(`INSERT INTO inventario (mechanic_id,nombre,sku,existencias,minimo,costo,precio)
    VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,[req.user.id,String(b.nombre).trim().slice(0,160),String(b.sku).trim().toUpperCase().slice(0,80),Number(b.existencias),Number(b.minimo),costo,precio]);
  if(Number(b.existencias)>0) await client.query(`INSERT INTO inventario_movimientos
    (inventario_id,autor_id,cantidad,motivo,operacion_id) VALUES ($1,$2,$3,$4,$5)`,[q.rows[0].id,req.user.id,Number(b.existencias),'Existencias iniciales',crypto.randomUUID()]);
  return q.rows[0];
}));
router.put('/inventario/:id',(req,res)=>transaction(req,res,async client=>{
  const b=req.body,costo=money(b.costo),precio=money(b.precio);
  const nombre=String(b.nombre||'').trim(),sku=String(b.sku||'').trim().toUpperCase();
  if(!nombre || nombre.length>160 || !sku || sku.length>80 || costo===null || precio===null || !integer(b.minimo)) throw fail(400,'Nombre, codigo, minimo o importes invalidos');
  const q=await client.query(`SELECT * FROM inventario WHERE id=$1 AND activo=true
    AND ($2::text='superuser' OR mechanic_id=$3) FOR UPDATE`,[Number(req.params.id),req.user.role,req.user.id]);
  if(!q.rowCount) throw fail(404,'Repuesto no encontrado');
  const duplicate=await client.query('SELECT id FROM inventario WHERE mechanic_id=$1 AND sku=$2 AND id<>$3',[q.rows[0].mechanic_id,sku,q.rows[0].id]);
  if(duplicate.rowCount) throw fail(409,'Ya existe ese codigo');
  return (await client.query('UPDATE inventario SET nombre=$1,sku=$2,minimo=$3,costo=$4,precio=$5 WHERE id=$6 RETURNING *',
    [nombre,sku,Number(b.minimo),costo,precio,q.rows[0].id])).rows[0];
}));
router.post('/inventario/:id/movimientos',(req,res)=>transaction(req,res,async client=>{
  const b=req.body;
  if(!Number.isSafeInteger(Number(b.cantidad)) || Number(b.cantidad)===0 || !String(b.motivo||'').trim()
    || typeof b.operacionId!=='string' || !/^[a-zA-Z0-9_-]{16,100}$/.test(b.operacionId)) throw fail(400,'Indica cantidad, motivo y operacion validos');
  const q=await client.query(`SELECT * FROM inventario WHERE id=$1 AND activo=true
    AND ($2::text='superuser' OR mechanic_id=$3) FOR UPDATE`,[Number(req.params.id),req.user.role,req.user.id]);
  if(!q.rowCount) throw fail(404,'Repuesto no encontrado');
  const previous=await client.query('SELECT * FROM inventario_movimientos WHERE operacion_id=$1',[b.operacionId]);
  if(previous.rowCount) {
    const p=previous.rows[0];
    if(p.inventario_id!==q.rows[0].id || p.autor_id!==req.user.id || p.cantidad!==Number(b.cantidad) || p.motivo!==String(b.motivo).trim()) throw fail(409,'Operacion usada con otros datos');
    return p;
  }
  if(q.rows[0].existencias+Number(b.cantidad)<0) throw fail(409,'El movimiento dejaria existencias negativas');
  await client.query('UPDATE inventario SET existencias=existencias+$1 WHERE id=$2',[Number(b.cantidad),q.rows[0].id]);
  return (await client.query(`INSERT INTO inventario_movimientos
    (inventario_id,autor_id,cantidad,motivo,operacion_id) VALUES ($1,$2,$3,$4,$5) RETURNING *`,[q.rows[0].id,req.user.id,Number(b.cantidad),String(b.motivo).trim().slice(0,500),b.operacionId])).rows[0];
}));
router.get('/inventario/:id/movimientos',async(req,res)=>{
  const q=await pool.query(`SELECT m.*,u.nombre AS autor FROM inventario_movimientos m
    JOIN inventario i ON i.id=m.inventario_id JOIN usuarios u ON u.id=m.autor_id
    WHERE i.id=$1 AND ($2::text='superuser' OR i.mechanic_id=$3)
    ORDER BY m.created_at DESC,m.id DESC LIMIT 200`,[Number(req.params.id),req.user.role,req.user.id]);
  res.json(q.rows);
});

router.get('/recordatorios',async(req,res)=>{
  const q=await pool.query(`SELECT r.*,v.placa,v.kilometraje AS km_actual,p.nombre AS propietario_nombre,
    (NOT r.completado AND ((r.fecha IS NOT NULL AND r.fecha<=(NOW() AT TIME ZONE 'America/Guayaquil')::date) OR
    (r.kilometraje IS NOT NULL AND v.kilometraje>=r.kilometraje))) AS vencido
    FROM recordatorios r JOIN vehiculos v ON v.id=r.vehiculo_id LEFT JOIN propietarios p ON p.id=v.propietario_id
    WHERE ($1::text='superuser' OR r.mechanic_id=$2)
    ORDER BY r.completado,r.fecha NULLS LAST,r.id DESC`,[req.user.role,req.user.id]);
  res.json(q.rows);
});
router.post('/recordatorios',(req,res)=>transaction(req,res,async client=>{
  const b=req.body;
  if(!String(b.titulo||'').trim() || (!b.fecha && !b.kilometraje)) throw fail(400,'Indica servicio y fecha o kilometraje');
  if(b.fecha && (!/^\d{4}-(0[1-9]|1[0-2])-\d{2}$/.test(b.fecha) || !Number.isFinite(Date.parse(b.fecha)) || new Date(b.fecha).toISOString().slice(0,10)!==b.fecha)) throw fail(400,'Fecha invalida');
  if(b.kilometraje && (!integer(b.kilometraje) || Number(b.kilometraje)<=0)) throw fail(400,'Kilometraje invalido');
  const v=await client.query(`SELECT id FROM vehiculos WHERE placa=$1 AND archivado=false
    AND ($2::text='superuser' OR mechanic_id=$3)`,[String(b.placa||'').trim().toUpperCase(),req.user.role,req.user.id]);
  if(!v.rowCount) throw fail(404,'Vehiculo no encontrado o archivado');
  return (await client.query(`INSERT INTO recordatorios (vehiculo_id,mechanic_id,titulo,fecha,kilometraje)
    VALUES ($1,$2,$3,$4,$5) RETURNING *`,[v.rows[0].id,req.user.id,String(b.titulo).trim().slice(0,200),b.fecha||null,b.kilometraje?Number(b.kilometraje):null])).rows[0];
}));
router.put('/recordatorios/:id',async(req,res)=>{
  if(typeof req.body.completado!=='boolean') return res.status(400).json({error:'Estado invalido'});
  const q=await pool.query(`UPDATE recordatorios SET completado=$1 WHERE id=$2
    AND ($3::text='superuser' OR mechanic_id=$4) RETURNING *`,[req.body.completado,Number(req.params.id),req.user.role,req.user.id]);
  if(!q.rowCount) return res.status(404).json({error:'Recordatorio no encontrado'});
  res.json(q.rows[0]);
});
export default router;
