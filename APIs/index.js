require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const crypto = require('crypto');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
app.use(cors());
app.use(bodyParser.json());

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
});

const md5 = (str) => crypto.createHash('md5').update(str).digest('hex');

// ── HEALTH ──────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// ── AUTH ─────────────────────────────────────────────────
app.post('/register', async (req, res) => {
  const { player_name, username, password } = req.body;

  if (!player_name || !username || !password)
    return res.status(400).json({ error: 'Missing fields' });

  try {
    const [rows] = await pool.execute(
      `SELECT player_name, username
       FROM playerstbl
       WHERE username = ? OR player_name = ?`,
      [username, player_name]
    );

    if (rows.length > 0) {
      const existing = rows[0];

      if (existing.username === username)
        return res.status(409).json({ error: 'Username already exists' });

      if (existing.player_name === player_name)
        return res.status(409).json({ error: 'Player name already exists' });
    }

    const [result] = await pool.execute(
      'INSERT INTO playerstbl (player_name, username, password) VALUES (?,?,?)',
      [player_name, username, password]
    );

    res.json({
      player_id: result.insertId,
      player_name,
      username
    });

  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const [rows] = await pool.execute(
    'SELECT player_id, player_name, username FROM playerstbl WHERE username=? AND password=?',
    [username, password]
  );
  if (rows.length === 0) return res.status(401).json({ error: 'Invalid credentials' });
  res.json(rows[0]);
});

// ── PLAYERS CRUD ─────────────────────────────────────────
app.get('/players', async (req, res) => {
  const [rows] = await pool.execute('SELECT player_id, player_name, username, created_at FROM playerstbl');
  res.json(rows);
});

app.get('/players/:id', async (req, res) => {
  const [rows] = await pool.execute(
    'SELECT player_id, player_name, username, created_at FROM playerstbl WHERE player_id=?',
    [req.params.id]
  );
  if (rows.length === 0) return res.status(404).json({ error: 'Not found' });
  res.json(rows[0]);
});

app.put('/players/:id', async (req, res) => {
  const { player_name, username, password } = req.body;
  const updates = [];
  const vals = [];

  try {
    
    if (username) {
      const [u] = await pool.execute(
        'SELECT player_id FROM playerstbl WHERE username=? AND player_id != ?',
        [username, req.params.id]
      );
      if (u.length > 0) {
        return res.status(409).json({ error: 'Username already exists' });
      }
      updates.push('username=?');
      vals.push(username);
    }

    if (player_name) {
      const [p] = await pool.execute(
        'SELECT player_id FROM playerstbl WHERE player_name=? AND player_id != ?',
        [player_name, req.params.id]
      );
      if (p.length > 0) {
        return res.status(409).json({ error: 'Player name already exists' });
      }
      updates.push('player_name=?');
      vals.push(player_name);
    }

    if (password) {
      updates.push('password=?');
      vals.push(password);
    }

    if (!updates.length) {
      return res.status(400).json({ error: 'Nothing to update' });
    }

    vals.push(req.params.id);

    await pool.execute(
      `UPDATE playerstbl SET ${updates.join(',')} WHERE player_id=?`,
      vals
    );

    res.json({ success: true });

  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.delete('/players/:id', async (req, res) => {
  await pool.execute('DELETE FROM playerstbl WHERE player_id=?', [req.params.id]);
  res.json({ success: true });
});

// ── MONSTERS CRUD ─────────────────────────────────────────
app.get('/monsters', async (req, res) => {
  const [rows] = await pool.execute('SELECT * FROM monsterstbl');
  res.json(rows);
});

app.post('/monsters', async (req, res) => {
  const { monster_name, monster_type, spawn_latitude, spawn_longitude, spawn_radius_meters, picture_url } = req.body;
  const [result] = await pool.execute(
    'INSERT INTO monsterstbl (monster_name,monster_type,spawn_latitude,spawn_longitude,spawn_radius_meters,picture_url) VALUES (?,?,?,?,?,?)',
    [monster_name, monster_type, spawn_latitude, spawn_longitude, spawn_radius_meters || 100, picture_url || null]
  );
  res.json({ monster_id: result.insertId });
});

app.put('/monsters/:id', async (req, res) => {
  const { monster_name, monster_type, spawn_latitude, spawn_longitude, spawn_radius_meters, picture_url } = req.body;
  await pool.execute(
    'UPDATE monsterstbl SET monster_name=?,monster_type=?,spawn_latitude=?,spawn_longitude=?,spawn_radius_meters=?,picture_url=? WHERE monster_id=?',
    [monster_name, monster_type, spawn_latitude, spawn_longitude, spawn_radius_meters, picture_url, req.params.id]
  );
  res.json({ success: true });
});

app.delete('/monsters/:id', async (req, res) => {
  await pool.execute('DELETE FROM monsterstbl WHERE monster_id=?', [req.params.id]);
  res.json({ success: true });
});

// ── CATCH MONSTER ─────────────────────────────────────────
// Haversine formula to check proximity
function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180)*Math.cos(lat2*Math.PI/180)*Math.sin(dLon/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

app.post('/scan', async (req, res) => {
  const { latitude, longitude } = req.body;
  const [monsters] = await pool.execute('SELECT * FROM monsterstbl');
  const nearby = monsters.filter(m => {
    const dist = haversine(latitude, longitude, parseFloat(m.spawn_latitude), parseFloat(m.spawn_longitude));
    return dist <= parseFloat(m.spawn_radius_meters);
  });
  res.json(nearby);
});

app.post('/catch', async (req, res) => {
  const { player_id, monster_id, latitude, longitude } = req.body;
  let location_id = 1;
  const [result] = await pool.execute(
    'INSERT INTO monster_catchestbl (player_id,monster_id,location_id,latitude,longitude) VALUES (?,?,?,?,?)',
    [player_id, monster_id, location_id, latitude, longitude]
  );
  res.json({ catch_id: result.insertId, success: true });
});

app.get('/catches/:player_id', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT mc.catch_id, mc.player_id, mc.monster_id,
              mc.latitude, mc.longitude, mc.catch_datetime,
              m.monster_name, m.monster_type, m.picture_url
       FROM monster_catchestbl mc
       JOIN monsterstbl m ON mc.monster_id = m.monster_id
       WHERE mc.player_id=?
       ORDER BY mc.catch_datetime DESC`,
      [req.params.player_id]
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Delete a catch
app.delete('/catches/:catch_id', async (req, res) => {
  try {
    await pool.execute(
      'DELETE FROM monster_catchestbl WHERE catch_id=?',
      [req.params.catch_id]
    );
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── LEADERBOARD ───────────────────────────────────────────
app.get('/leaderboard', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT p.player_id, p.player_name, p.username, 
              COUNT(mc.catch_id) as total_catches
       FROM playerstbl p
       LEFT JOIN monster_catchestbl mc ON p.player_id = mc.player_id
       GROUP BY p.player_id, p.player_name, p.username
       ORDER BY total_catches DESC 
       LIMIT 10`
    );
    res.json(rows);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ── START ─────────────────────────────────────────────────
app.listen(process.env.API_PORT, '0.0.0.0', () => {
  console.log(`HAU Monsters API running on port ${process.env.API_PORT}`);
});

const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Multer storage config
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, 'uploads/monsters'));
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e6);
    cb(null, `monster-${unique}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/jpg', 'application/octet-stream'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  },
});

// Upload endpoint
app.post('/upload', upload.single('image'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  // Build the public URL using Tailscale MagicDNS
  const url = `${req.protocol}://${req.get('host')}/uploads/monsters/${req.file.filename}`;
  res.json({ url });
});