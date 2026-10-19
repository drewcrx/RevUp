import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { dataRoot } from './local.mjs';

const exec = promisify(execFile);
const project = fileURLToPath(new URL('../', import.meta.url));
const properties = await readFile(path.join(project, 'android', 'local.properties'), 'utf8');
const sdk = properties.match(/^sdk.dir=(.+)$/m)[1].trim().replaceAll('\\\\', '\\');
const adb = path.join(sdk, 'platform-tools', 'adb.exe');
const device = process.argv[3];
if (!device || !/^[A-Za-z0-9_.:-]+$/.test(device)) throw new Error('Indica la acción y el identificador de adb devices');
const command = process.argv[2] || 'inspect';
const folder = path.join(project, '.local', 'android');
await mkdir(folder, { recursive: true });
const call = async (...args) => {
  try {
    return (await exec(adb, ['-s', device, ...args], { windowsHide: true, timeout: 20000, maxBuffer: 8 * 1024 * 1024 })).stdout;
  } catch {
    // Un error de execFile incluiría sus argumentos, que pueden contener la clave.
    throw new Error('ADB no completó la operación. Revisa la conexión y autorización del teléfono.');
  }
};
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function dump() {
  await call('shell', 'uiautomator', 'dump', '/sdcard/revup-local-check.xml');
  return call('shell', 'cat', '/sdcard/revup-local-check.xml');
}
function nodes(xml) {
  return [...xml.matchAll(/<node\s+([^>]+)>/g)].map(match => Object.fromEntries(
    [...match[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(attribute => [attribute[1], attribute[2]])));
}
async function tap(node) {
  const bounds = node?.bounds?.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
  if (!bounds) throw new Error('No se encontró el control esperado');
  await call('shell', 'input', 'tap', String(Math.floor((+bounds[1] + +bounds[3]) / 2)),
    String(Math.floor((+bounds[2] + +bounds[4]) / 2)));
}
if (command === 'login') {
  let xml = await dump();
  if (!xml.includes('com.example.menudrawer.local')) throw new Error('RevUp Local debe estar en primer plano');
  const fields = nodes(xml).filter(node => node.class === 'android.widget.EditText');
  if (fields.length !== 2) throw new Error('No se encontró el formulario de login');
  const settings = JSON.parse(await readFile(path.join(dataRoot, 'credentials.json'), 'utf8'));
  await tap(fields[0]);
  await call('shell', 'input', 'keyevent', 'KEYCODE_MOVE_END', ...Array(Math.max(fields[0].text.length + 2, 50)).fill('KEYCODE_DEL'));
  await call('shell', 'input', 'text', 'admin.local');
  await call('shell', 'input', 'keyevent', '4');
  xml = await dump();
  // EMUI puede insertar un espacio al sintetizar la tecla punto mediante adb,
  // aun con sugerencias desactivadas. Corregir solo ese valor conocido del test.
  const usernameField = nodes(xml).find(node => node.class === 'android.widget.EditText' && node.password === 'false');
  if (usernameField?.text === 'admin. local') {
    await tap(usernameField);
    await call('shell', 'input', 'keyevent', 'KEYCODE_MOVE_END', ...Array(5).fill('KEYCODE_DPAD_LEFT'), 'KEYCODE_DEL');
    await call('shell', 'input', 'keyevent', '4');
    xml = await dump();
  }
  if (!nodes(xml).some(node => node.class === 'android.widget.EditText' && node.text === 'admin.local')) {
    throw new Error('El teclado modificó el usuario antes de enviarlo');
  }
  const passwordField = nodes(xml).find(node => node.class === 'android.widget.EditText' && node.password === 'true');
  if (!passwordField) throw new Error('No se encontró el campo seguro de contraseña');
  await tap(passwordField);
  await call('shell', 'input', 'keyevent', 'KEYCODE_MOVE_END', ...Array(60).fill('KEYCODE_DEL'));
  await call('shell', 'input', 'text', settings.adminPassword);
  await call('shell', 'input', 'keyevent', '4');
  await sleep(500);
  xml = await dump();
  await tap(nodes(xml).find(node => /INICIAR SESI/.test(node.text || node['content-desc'] || '')));
  await sleep(4000);
  xml = await dump();
  if (/INICIAR SESI/.test(xml) || !/Administrador local|INICIO|Inicio|Bienvenid|OTs|Resumen/.test(xml)) {
    throw new Error('No se pudo confirmar el inicio de sesión en la interfaz');
  }
  await writeFile(path.join(folder, 'login-ok.xml'), xml);
  console.log('Inicio de sesión real confirmado en Android. No se imprimieron credenciales.');
} else if (command === 'logout') {
  let xml = await dump();
  if (!xml.includes('DASHBOARD')) throw new Error('Abre primero el dashboard de RevUp Local');
  const menu = nodes(xml).find(node => /Open navigation menu|Abrir.*navegaci/.test(node['content-desc'] || '')) ||
    nodes(xml).find(node => {
      const coordinates = node.bounds?.match(/\d+/g)?.map(Number);
      return node.clickable === 'true' && coordinates && coordinates[0] < 100 &&
        coordinates[2] < 220 && coordinates[1] > 50 && coordinates[1] < 300;
    });
  await tap(menu);
  xml = await dump();
  await tap(nodes(xml).find(node => (node.text || node['content-desc']) === 'Cerrar sesión'));
  await sleep(1500);
  xml = await dump();
  if (!xml.includes('INICIAR SESIÓN')) throw new Error('No se confirmó el cierre de sesión');
  console.log('Cierre de sesión confirmado en Android.');
} else if (command === 'navigation') {
  for (const [label, title] of [['Vehículos', 'VEHÍCULOS'], ['Órdenes', 'ÓRDENES'], ['Reportes', 'REPORTES']]) {
    let xml = await dump();
    await tap(nodes(xml).find(node => (node.text || node['content-desc']) === label));
    await sleep(1500);
    xml = await dump();
    if (!xml.includes(title) || /No se pudo conectar|HTTP [45]\d\d/.test(xml)) {
      throw new Error('No se confirmó la pantalla ' + label);
    }
    if (label === 'Vehículos') {
      await tap(nodes(xml).find(node => (node.text || node['content-desc']) === 'Agregar'));
      await sleep(1500);
      xml = await dump();
      if (!xml.includes('AGREGAR VEHÍCULO') || !xml.includes('Marca')) throw new Error('El formulario no cargó sus catálogos');
      await call('shell', 'input', 'keyevent', '4'); await sleep(500);
    }
    await call('shell', 'input', 'keyevent', '4'); await sleep(500);
    console.log('Navegación y carga real: ' + label);
  }
} else if (command === 'camera') {
  let xml = await dump();
  if (!xml.includes('DASHBOARD')) throw new Error('Abre primero el dashboard');
  await tap(nodes(xml).find(node => (node.text || node['content-desc']) === 'Escanear'));
  await sleep(1500);
  xml = await dump();
  const allow = nodes(xml).find(node => /permission_allow_button$/.test(node['resource-id'] || '') ||
    /^(PERMITIR|Permitir|ALLOW|Allow)$/.test(node.text || ''));
  if (allow) {
    if (!xml.includes('RevUp Local') && !xml.includes('com.example.menudrawer.local')) {
      throw new Error('El permiso no se identifica como una solicitud de RevUp Local');
    }
    await tap(allow); await sleep(1500); xml = await dump();
  }
  if (!xml.includes('ESCANEAR QR')) throw new Error('No se confirmó la pantalla del escáner');
  const camera = await call('shell', 'dumpsys', 'media.camera');
  const active = camera.match(/Active Camera Clients:([\s\S]*?)(?:\n\n|\n==)/i)?.[1] || '';
  const confirmed = active.includes('com.example.menudrawer.local');
  await writeFile(path.join(folder, 'camera-status.json'), JSON.stringify({
    scannerScreen: true, activeClientConfirmed: confirmed,
    capturedImage: false, physicalQrRead: false,
  }, null, 2));
  console.log('Pantalla del escáner abierta; cliente de cámara activo confirmado: ' + confirmed);
  await call('shell', 'input', 'keyevent', '4');
} else if (command === 'restart') {
  await call('shell', 'am', 'force-stop', 'com.example.menudrawer.local');
  await call('shell', 'am', 'start', '-n', 'com.example.menudrawer.local/com.example.menudrawer.MainActivity');
  await sleep(2500);
  const xml = await dump();
  if (!xml.includes('Administrador local') || !xml.includes('DASHBOARD') || xml.includes('INICIAR SESIÓN')) {
    throw new Error('No se confirmó la sesión persistida tras reabrir');
  }
  console.log('Sesión persistida y dashboard restaurado al reabrir Android.');
} else if (command === 'inspect') {
  const xml = await dump();
  if (!xml.includes('com.example.menudrawer.local')) throw new Error('RevUp Local no está en primer plano');
  await writeFile(path.join(folder, 'screen.xml'), xml);
  const shot = await exec(adb, ['-s', device, 'exec-out', 'screencap', '-p'],
    { encoding: 'buffer', windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
  await writeFile(path.join(folder, 'screen.png'), shot.stdout);
  console.log('Interfaz y captura de RevUp Local guardadas en .local/android.');
} else {
  throw new Error('Acción válida: inspect, login, logout, navigation, camera o restart');
}
