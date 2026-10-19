import './config/env.js';
import { pathToFileURL } from 'node:url';
import app from './app.js';
import { ensureSchema, pool } from './db/connection.js';

export async function startServer({
  prepareSchema = ensureSchema,
  application = app,
  port = Number(process.env.PORT || 3000),
} = {}) {
  await prepareSchema();
  return new Promise((resolve, reject) => {
    const server = application.listen(port, '0.0.0.0', () => resolve(server));
    server.once('error', reject);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  let activeServer;
  let stopping = false;
  async function shutdown() {
    if (stopping) return;
    stopping = true;
    const deadline = setTimeout(() => process.exit(1), 15000);
    deadline.unref();
    if (activeServer) await new Promise(resolve => activeServer.close(resolve));
    await pool.end();
    process.exit(0);
  }
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
  process.on('message', message => {
    if (message?.type === 'shutdown') void shutdown();
  });
  startServer()
    .then((server) => {
      activeServer = server;
      console.log(`Servidor escuchando en puerto ${server.address().port}`);
      if (process.send) process.send({ type: 'ready' });
    })
    .catch(async (error) => {
      console.error('No se pudo iniciar el servidor:', error.message);
      await pool.end();
      process.exitCode = 1;
    });
}
