import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import router from "./routes/vehiculos.js";
import usuariosRouter from "./routes/usuarios.js";
import ordenesRoutes from "./routes/ordenes.js";
import reportesRoutes from "./routes/reportes.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  req.body = req.body || {};
  next();
});

app.get("/health", (_req, res) => res.json({ ok: true }));

app.use("/reportes", reportesRoutes);
app.use("/ordenes", ordenesRoutes);
app.use("/vehiculos", router);
app.use("/usuarios", usuariosRouter);

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, "0.0.0.0", () =>
  console.log(`Servidor corriendo en http://0.0.0.0:${PORT}`)
);
