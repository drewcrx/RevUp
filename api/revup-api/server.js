import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import path from "path";

import router from "./routes/vehiculos.js";
import usuariosRouter from "./routes/usuarios.js";
import ordenesRoutes from "./routes/ordenes.js";
import reportesRoutes from "./routes/reportes.js";
import publicoRoutes from "./routes/publico.js";
import catalogosRoutes from "./routes/catalogos.js";
import { ensureSchema } from "./db/connection.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  req.body = req.body || {};
  next();
});

app.get("/health", (_req, res) => res.json({ ok: true }));

// Fotos de OT (público — el mismo link se comparte en el QR del cliente)
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(process.cwd(), "uploads");
app.use("/uploads", express.static(UPLOAD_DIR));

app.use("/reportes", reportesRoutes);
app.use("/ordenes", ordenesRoutes);
app.use("/vehiculos", router);
app.use("/usuarios", usuariosRouter);
app.use("/v", publicoRoutes);
app.use("/catalogos", catalogosRoutes);

const PORT = Number(process.env.PORT || 3000);

ensureSchema()
  .catch((e) => console.error("Error preparando esquema de BD:", e.message))
  .finally(() => {
    app.listen(PORT, "0.0.0.0", () =>
      console.log(`Servidor corriendo en http://0.0.0.0:${PORT}`)
    );
  });
