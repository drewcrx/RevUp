import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chooseHost, isPrivateIpv4, localEnvironment } from '../../../tool/local.mjs';

test('selecciona la IP de la PC sin usar loopback ni adaptadores virtuales', () => {
  const interfaces = { Ethernet: [{ address: '192.168.1.11', internal: false }],
    'vEthernet (WSL)': [{ address: '172.20.0.1', internal: false }],
    Loopback: [{ address: '127.0.0.1', internal: true }] };
  assert.equal(chooseHost(undefined, interfaces), '192.168.1.11');
  assert.throws(() => chooseHost('10.0.2.2', interfaces), /no está asignada/);
  assert.throws(() => chooseHost('127.0.0.1', interfaces), /IP privada/);
  assert.equal(isPrivateIpv4('8.8.8.8'), false);
  assert.equal(isPrivateIpv4('192.168.1.999'), false);
});

test('el entorno local conserva SMTP y aísla la base y las URLs del VPS', () => {
  const env = localEnvironment({ host: '192.168.1.11', apiPort: 3000, dbPort: 55432,
    dbPassword: 'local-only', jwtSecret: 'local-jwt' },
  { MAIL_HOST: 'smtp.example.com', PGHOST: 'vps.example.com', APP_URL: 'https://old.example.com' });
  assert.equal(env.PGHOST, '127.0.0.1');
  assert.equal(env.PGPORT, '55432');
  assert.equal(env.APP_URL, 'http://192.168.1.11:3000');
  assert.equal(env.MAIL_HOST, 'smtp.example.com');
  assert.equal(env.APP_ENV, 'local');
});
