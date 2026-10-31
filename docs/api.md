# API Server

[← Back to README](../README.md)

A Node.js (Express) API that runs on the Paris web server and talks to the RDS database. The source is [`APIs/index.js`](../APIs/index.js).

## Contents

- [Setup](#setup)
- [Endpoints](#endpoints)
- [File uploads](#file-uploads)

## Setup

SSH into the Paris web server:

```bash
ssh -i MyParisWebServerKP.pem ec2-user@<WEB_PUBLIC_IP>
```

Install Node.js and the dependencies:

```bash
# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

# Create project
mkdir /home/ec2-user/hauapi && cd /home/ec2-user/hauapi
npm init -y
npm install express mysql2 cors body-parser multer dotenv

# Folder for uploaded monster images
mkdir -p uploads/monsters
```

Copy `APIs/index.js` from this repository into `/home/ec2-user/hauapi/` (for example with `scp`).

Create `.env` next to it:

```env
DB_HOST=your-rds-endpoint.rds.amazonaws.com
DB_PORT=3306
DB_USER=haumonsters_admin
DB_PASS=your_password
DB_NAME=haumonstersDB
API_PORT=8000
```

Start it with PM2 so it survives reboots:

```bash
sudo npm install -g pm2
pm2 start index.js --name hauapi
pm2 startup
pm2 save
```

> Tip: after the first successful install, run `npm ls --depth=0` and commit a `package.json` and `package-lock.json` to `APIs/` so everyone installs the same versions.

## Endpoints

### Auth

| Method | Endpoint | Description | Body |
|--------|----------|-------------|------|
| POST | `/register` | Register new player | `player_name`, `username`, `password` |
| POST | `/login` | Login (returns player info) | `username`, `password` |

The app sends the password already MD5-hashed, and the API stores and compares that value as-is.

### Players

| Method | Endpoint | Description | Body |
|--------|----------|-------------|------|
| GET | `/players` | Get all players | |
| GET | `/players/:id` | Get player by ID | |
| PUT | `/players/:id` | Update player info | `player_name`, `username`, optional `password` |
| DELETE | `/players/:id` | Delete player | |

### Monsters

| Method | Endpoint | Description | Body |
|--------|----------|-------------|------|
| GET | `/monsters` | Get all monsters | |
| POST | `/monsters` | Add new monster | `monster_name`, `monster_type`, `spawn_latitude`, `spawn_longitude`, `spawn_radius_meters` (default 100), `picture_url` |
| PUT | `/monsters/:id` | Edit monster | same as POST |
| DELETE | `/monsters/:id` | Delete monster | |

### Catching

| Method | Endpoint | Description | Body |
|--------|----------|-------------|------|
| POST | `/scan` | Scan for nearby monsters | `latitude`, `longitude` |
| POST | `/catch` | Catch a monster | `player_id`, `monster_id`, `latitude`, `longitude` |
| GET | `/catches/:player_id` | Get player's catches | |
| DELETE | `/catches/:catch_id` | Release a caught monster | |

`/scan` returns every monster whose spawn radius contains the given coordinates (Haversine distance).

### Leaderboard

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/leaderboard` | Top 10 players by catches |

### Upload

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/upload` | Upload monster image (`multipart/form-data`, field `image`) |

### Health

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health check (used for VPN detection) |

## File uploads

- Images are limited to 5 MB and must be JPEG, PNG, WebP or GIF.
- They are stored in `/home/ec2-user/hauapi/uploads/monsters/` on the web server.
- They are served statically at `http://<tailscale-host>:8000/uploads/monsters/<filename>`, and `/upload` returns that URL as `{ "url": "..." }`.
