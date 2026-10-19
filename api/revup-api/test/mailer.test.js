import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sendMail } from '../utils/mailer.js';

test('sin SMTP no simula un envío ni imprime enlaces privados', async () => {
  const previousHost = process.env.MAIL_HOST;
  delete process.env.MAIL_HOST;
  const previousLog = console.log;
  const logged = [];
  console.log = (...args) => logged.push(args);
  try {
    await assert.rejects(sendMail({ to: 'test@example.invalid', subject: 'Prueba',
      text: 'enlace-privado-no-debe-aparecer-en-logs' }), /SMTP no configurado/);
    assert.deepEqual(logged, []);
  } finally {
    console.log = previousLog;
    if (previousHost === undefined) delete process.env.MAIL_HOST;
    else process.env.MAIL_HOST = previousHost;
  }
});
