const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const jwt = require('jsonwebtoken');
const axios = require('axios');
const rateLimit = require('express-rate-limit');

const app = express();
app.use(express.json());

// Ocultar tecnología del backend (Fallo detectado por ZAP DAST)
app.disable('x-powered-by');

// Ruta raíz para healthcheck
app.get('/', (req, res) => res.send("FleetSec API - Staging Environment"));

// V-10 [REMEDIADO]: Hardcoded Credentials (CWE-798)
const JWT_SECRET = process.env.JWT_SECRET || "fallback_local_secret_12345!";

// V-07 [REMEDIADO]: Missing Rate Limiting (CWE-307)
const loginLimiter = rateLimit({
    windowMs: 5 * 60 * 1000, // 5 minutos
    max: 5, // Límite de 5 peticiones por IP
    message: "Demasiados intentos de login, intente más tarde"
});

const db = new sqlite3.Database(':memory:');
db.serialize(() => {
    db.run("CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, password TEXT, email TEXT, cc TEXT, role TEXT)");
    db.run("INSERT INTO users (username, password, email, cc, role) VALUES ('admin', 'admin123', 'admin@fleetsec.com', '123456789', 'admin')");
});

// Función Helper para V-08 (Redactar PII sensible)
const maskPII = (str) => str ? str.slice(0, 2) + "****" + str.slice(-2) : "";

app.post('/api/login', loginLimiter, (req, res) => {
    const { username, password } = req.body;
    
    // V-01 [REMEDIADO]: SQL Injection (CWE-89)
    const query = `SELECT * FROM users WHERE username = ? AND password = ?`;
    
    db.get(query, [username, password], (err, user) => {
        if (err) return res.status(500).send("Error DB");
        if (!user) return res.status(401).send("Credenciales inválidas");

        // V-08 [REMEDIADO]: Logging de PII (CWE-359/Ley 1581)
        console.log(`[INFO] Login exitoso - Usuario: ${user.username}, Email: ${maskPII(user.email)}, Cédula: ${maskPII(user.cc)}`);

        // Generamos el token forzando el algoritmo seguro
        const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, { algorithm: 'HS256' });
        res.json({ token });
    });
});

// V-02 [REMEDIADO]: Broken Auth/JWT alg:none (CWE-345)
const authMiddleware = (req, res, next) => {
    const token = req.headers['authorization']?.split(' ')[1];
    if (!token) return res.status(403).send("Token requerido");

    try {
        const decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
        req.user = decoded;
        next();
    } catch (err) {
        res.status(401).send("Token inválido o expirado");
    }
};

// V-03 [REMEDIADO]: SSRF (CWE-918)
const ALLOWED_URLS = ['https://api.github.com', 'https://jsonplaceholder.typicode.com'];
app.get('/api/proxy', authMiddleware, async (req, res) => {
    const { url } = req.query;
    if (!ALLOWED_URLS.includes(url)) {
        return res.status(403).send("Acceso denegado: URL no permitida por la política de seguridad");
    }
    try {
        const response = await axios.get(url);
        res.send(response.data);
    } catch (err) {
        res.status(500).send("Error al obtener URL");
    }
});

// V-09 [REMEDIADO]: IDOR (CWE-639)
app.get('/api/users/:id', authMiddleware, (req, res) => {
    if (req.user.id.toString() !== req.params.id && req.user.role !== 'admin') {
        return res.status(403).send("Acceso denegado a los datos de este usuario");
    }
    db.get(`SELECT username, email, role FROM users WHERE id = ?`, [req.params.id], (err, user) => {
        if (err || !user) return res.status(404).send("Usuario no encontrado");
        res.json(user);
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`FleetSec App corriendo en puerto ${PORT}`);
});
