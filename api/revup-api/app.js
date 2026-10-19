import express from "express";
import cors from "cors";
import path from "path";

import router from "./routes/vehiculos.js";
import usuariosRouter from "./routes/usuarios.js";
import ordenesRoutes from "./routes/ordenes.js";
import reportesRoutes from "./routes/reportes.js";
import publicoRoutes from "./routes/publico.js";
import catalogosRoutes from "./routes/catalogos.js";
import propietariosRoutes from "./routes/propietarios.js";
import { pool } from "./db/connection.js";

const app = express();
app.use(cors());
app.use(express.json({ limit: "2mb" }));
app.use((req, res, next) => {
  req.body = req.body || {};
  next();
});

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true });
  } catch {
    res.status(503).json({ ok: false, error: "Base de datos no disponible" });
  }
});

// Fotos de OT (público — el mismo link se comparte en el QR del cliente)
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(process.cwd(), "uploads");
app.use("/uploads", express.static(UPLOAD_DIR));

app.use("/reportes", reportesRoutes);
app.use("/ordenes", ordenesRoutes);
app.use("/vehiculos", router);
app.use("/usuarios", usuariosRouter);
app.use("/v", publicoRoutes);
app.use("/catalogos", catalogosRoutes);
app.use("/propietarios", propietariosRoutes);

export default app;
