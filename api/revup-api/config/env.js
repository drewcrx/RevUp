import dotenv from 'dotenv';
import { fileURLToPath } from 'node:url';

// La ruta explícita permite separar la presentación local del .env anterior.
dotenv.config({
  path: process.env.REVUP_ENV_FILE || fileURLToPath(new URL('../.env', import.meta.url)),
  quiet: true,
});
