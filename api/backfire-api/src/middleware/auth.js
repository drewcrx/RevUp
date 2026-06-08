import jwt from "jsonwebtoken";

export function requireAuth(req, res, next) {
  try {
    const h = req.headers.authorization || "";
    const [type, token] = h.split(" ");

    if (type !== "Bearer" || !token) {
      return res.status(401).json({ error: "No autorizado" });
    }

    const payload = jwt.verify(token, process.env.JWT_SECRET);

    req.user = {
      id: payload.id,
      role: payload.role,
    };

    return next();
  } catch {
    return res.status(401).json({ error: "Token inválido o expirado" });
  }
}

export function requireSuper(req, res, next) {
  if (req.user?.role === "superuser") return next();
  return res.status(403).json({ error: "Acceso denegado (solo superuser)" });
}
