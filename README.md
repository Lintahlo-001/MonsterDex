# 🎮 MonsterDex — Cloud-Based Monster Catching App

> A real-world monster catching mobile application built with Flutter, powered by AWS cloud infrastructure.  

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [AWS Infrastructure](#aws-infrastructure)
  - [VPC Setup](#vpc-setup)
  - [VPC Peering](#vpc-peering)
  - [EC2 Instances](#ec2-instances)
  - [RDS Database](#rds-database)
  - [Lambda Function](#lambda-function)
  - [Security Groups](#security-groups)
- [Tailscale VPN](#tailscale-vpn)
- [Database Schema](#database-schema)
- [API Server](#api-server)
  - [Endpoints](#endpoints)
  - [Setup](#api-setup)
- [Flutter App](#flutter-app)
  - [Prerequisites](#prerequisites)
  - [Project Structure](#project-structure)
  - [Configuration](#configuration)
  - [Running the App](#running-the-app)
- [Features](#features)
- [Dependencies](#dependencies)

---

## Overview

MonsterDex is a location-based monster catching game similar to Pokémon GO. Players connect via Tailscale VPN, scan their surroundings using GPS, and catch monsters that spawn at registered real-world coordinates. The app is backed by AWS infrastructure with a web server in Paris and a managed RDS MySQL database in N. Virginia, connected via VPC Peering.

---

## Architecture

```
Mobile App (Flutter)
       │
       │ Tailscale VPN (MagicDNS)
       ▼
┌─────────────────────────┐
│  EC2 Web Server         │  eu-west-3 (Paris)
│  Node.js API :8000      │
│  + Tailscale installed  │
└────────────┬────────────┘
             │ VPC Peering
             ▼
┌─────────────────────────┐
│  EC2 Database Server    │  us-east-1 (N. Virginia)
└────────────┬────────────┘
             │ 
             ▼
┌─────────────────────────┐
│  Amazon RDS MySQL       │  us-east-1
│  MonsterDexDB          │
└─────────────────────────┘
             │
┌─────────────────────────┐
│  AWS Lambda             │  us-east-1
│  EC2 Toggle / Status    │
└─────────────────────────┘
```

---

## AWS Infrastructure

### VPC Setup

| VPC | Region | CIDR | Purpose |
|-----|--------|------|---------|
| `MyParisVPC` | eu-west-3 (Paris) | `10.0.0.0/16` | Web Server |
| `MyNVirginiaVPC` | us-east-1 (N. Virginia) | `10.1.0.0/16` | RDS Database |

Each VPC has:
- A public subnet (`10.x.1.0/24`)
- An Internet Gateway
- A Route Table with `0.0.0.0/0 → IGW`

### VPC Peering

A cross-region VPC peering connection links Paris (Web) → N. Virginia (DB).

**Route Table updates required:**

| Route Table | Destination | Target |
|-------------|-------------|--------|
| Paris (Web) | `10.1.0.0/16` | Peering Connection |
| N. Virginia (DB) | `10.0.0.0/16` | Peering Connection |

### EC2 Instances

| Instance | Region | Purpose | AMI |
|----------|--------|---------|-----|
| `MyParisWebServer` | eu-west-3 (Paris) | Node.js API + Tailscale | Amazon Linux 2023 |
| `MyNVirginiaDBServer` | us-east-1 (N. Virginia) | MySQL + connection to RDS | Amazon Linux 2023 |    

> The database is managed by both an **EC2 Instance** and **Amazon RDS**.

### RDS Database

| Setting | Value |
|---------|-------|
| Engine | MySQL 8.0 |
| Region | us-east-1 (N. Virginia) |
| DB Name | `monsterdexdb` |
| Instance | `db.t3.micro` (Free Tier) |
| VPC | `MyNVirginiaVPC` |
| Publicly Accessible | No |

**RDS Security Group** — allow inbound:

| Type | Port | Source |
|------|------|--------|
| MySQL/Aurora | 3306 | `10.1.0.0/16` (Paris VPC CIDR) |

### Lambda Function

Name: `haumonsters-ec2-toggle`  
Runtime: Python 3.12  
Role: Requires `AmazonEC2FullAccess`

Used to start/stop/check EC2 instances from the mobile app.

**Function URL:** Enable with Auth type `NONE` for app access.

```python
import boto3
import json

CORS_HEADERS = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

def lambda_handler(event, context):
    if event.get('requestContext', {}).get('http', {}).get('method') == 'OPTIONS':
        return {'statusCode': 200, 'headers': CORS_HEADERS, 'body': ''}

    body = event
    if 'body' in event:
        raw = event['body']
        if isinstance(raw, str):
            try:
                body = json.loads(raw)
            except Exception:
                body = {}
        elif isinstance(raw, dict):
            body = raw

    action      = body.get('action')
    instance_id = body.get('instance_id')
    region      = body.get('region', 'us-east-1')

    print(f"Parsed → action={action}, instance_id={instance_id}, region={region}")

    if not action or not instance_id:
        return {
            'statusCode': 400,
            'headers': CORS_HEADERS,
            'body': json.dumps({'error': 'Missing action or instance_id'})
        }

    try:
        ec2 = boto3.client('ec2', region_name=region)

        if action == 'status':
            resp  = ec2.describe_instances(InstanceIds=[instance_id])
            state = resp['Reservations'][0]['Instances'][0]['State']['Name']
            return {
                'statusCode': 200,
                'headers': CORS_HEADERS,
                'body': json.dumps({'state': state})
            }

        elif action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            return {
                'statusCode': 200,
                'headers': CORS_HEADERS,
                'body': json.dumps({'result': 'starting'})
            }

        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            return {
                'statusCode': 200,
                'headers': CORS_HEADERS,
                'body': json.dumps({'result': 'stopping'})
            }

        else:
            return {
                'statusCode': 400,
                'headers': CORS_HEADERS,
                'body': json.dumps({'error': f'Invalid action: {action}'})
            }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': CORS_HEADERS,
            'body': json.dumps({'error': str(e)})
        }
```

### Security Groups

**Web Server (`MyParisSG`) — Paris:**

| Type | Protocol | Port | Source |
|------|----------|------|--------|
| Custom TCP | TCP | 8000 | `100.64.0.0/10` (Tailscale range) |
| HTTP | TCP | 80 | `100.64.0.0/10` (Tailscale range) |
| HTTPS | TCP | 443 | `100.64.0.0/10` (Tailscale range) |
| SSH | TCP | 22 | 0.0.0.0 |

> Port 8000 is only accessible through Tailscale VPN — direct internet access is blocked.

**RDS (`rds-ec2-2`) — N. Virginia:**

| Type | Protocol | Port | Source |
|------|----------|------|--------|
| MySQL/Aurora | TCP | 3306 | `10.0.0.0/16` (Paris VPC CIDR) |

---

## Tailscale VPN

Tailscale is installed **only on the Paris web server**. All mobile users must join the tailnet to access the API.

### Install on Web Server

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Approve the auth link in browser
sudo tailscale status
```

### MagicDNS

This hostname resolves correctly for **every user on your tailnet** regardless of their assigned Tailscale IP — no hardcoded IPs needed.

### Joining the Network

1. Install Tailscale on your phone (App Store / Google Play)
2. Get the invite link from the network admin
3. Join the tailnet and connect
4. The app will automatically reach the server via MagicDNS

---

## Database Schema

Database: `haumonstersDB`

### `playerstbl`
| Column | Type | Notes |
|--------|------|-------|
| `player_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `player_name` | VARCHAR(150) | Display name (unique) |
| `username` | VARCHAR(100) | Login username (unique) |
| `password` | VARCHAR(255) | MD5 hashed |
| `created_at` | DATETIME | Default: CURRENT_TIMESTAMP |

### `monsterstbl`
| Column | Type | Notes |
|--------|------|-------|
| `monster_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `monster_name` | VARCHAR(100) | |
| `monster_type` | VARCHAR(100) | One of 18 types |
| `spawn_latitude` | DECIMAL(10,7) | GPS coordinate |
| `spawn_longitude` | DECIMAL(10,7) | GPS coordinate |
| `spawn_radius_meters` | DECIMAL(10,2) | Default: 100.00 |
| `picture_url` | VARCHAR(500) | Uploaded image URL |

### `monster_catchestbl`
| Column | Type | Notes |
|--------|------|-------|
| `catch_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `player_id` | INT UNSIGNED | FK → playerstbl |
| `monster_id` | INT UNSIGNED | FK → monsterstbl |
| `location_id` | INT UNSIGNED | FK → locationstbl |
| `latitude` | DECIMAL(10,7) | Where it was caught |
| `longitude` | DECIMAL(10,7) | Where it was caught |
| `catch_datetime` | DATETIME | Default: CURRENT_TIMESTAMP |

### `locationstbl`
| Column | Type | Notes |
|--------|------|-------|
| `location_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `location_name` | VARCHAR(100) | |

---

## API Server

### API Setup

SSH into the Paris web server:

```bash
ssh -i MyParisWebServerKP.pem ec2-user@<WEB_PUBLIC_IP>
```

```bash
# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

# Create project
mkdir /home/ec2-user/hauapi && cd /home/ec2-user/hauapi
npm init -y
npm install express mysql2 cors body-parser multer dotenv
```

Create `.env`:

```env
DB_HOST=your-rds-endpoint.rds.amazonaws.com
DB_PORT=3306
DB_USER=haumonsters_admin
DB_PASS=your_password
DB_NAME=haumonstersDB
API_PORT=8000
```

```bash
# Run with PM2
sudo npm install -g pm2
pm2 start index.js --name hauapi
pm2 startup
pm2 save
```

### Endpoints

#### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register` | Register new player |
| POST | `/login` | Login (returns player info) |

#### Players
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/players` | Get all players |
| GET | `/players/:id` | Get player by ID |
| PUT | `/players/:id` | Update player info |
| DELETE | `/players/:id` | Delete player |

#### Monsters
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/monsters` | Get all monsters |
| POST | `/monsters` | Add new monster |
| PUT | `/monsters/:id` | Edit monster |
| DELETE | `/monsters/:id` | Delete monster |

#### Catching
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/scan` | Scan for nearby monsters (lat/lng) |
| POST | `/catch` | Catch a monster |
| GET | `/catches/:player_id` | Get player's catches |
| DELETE | `/catches/:catch_id` | Release a caught monster |

#### Leaderboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/leaderboard` | Top 10 players by catches |

#### Upload
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/upload` | Upload monster image (multipart/form-data) |

#### Health
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health check (used for VPN detection) |

---

## Flutter App

### Prerequisites

- Flutter SDK 3.x
- Android Studio / VS Code
- Android device or emulator (API 23+)
- Tailscale installed on your phone

### Project Structure

```
lib/
├── main.dart                        # App entry, session restore
├── constants/
│   ├── theme.dart                   # Colors, gradients, type colors
│   └── api.dart                     # Base URL, instance IDs, Lambda URL
├── services/
│   ├── api_service.dart             # HTTP wrapper (get/post/put/delete)
│   ├── tailscale_service.dart       # VPN + server status checks
│   ├── lambda_service.dart          # EC2 start/stop/status via Lambda
│   └── permission_service.dart      # Android runtime permissions
├── models/
│   ├── player.dart
│   ├── monster.dart
│   └── catch.dart
├── screens/
│   ├── welcome_screen.dart          # Login/Register entry + status
│   ├── login_screen.dart            # Login form (MD5 password)
│   ├── register_screen.dart         # Registration form
│   ├── main_nav.dart                # Glass bottom navbar shell
│   ├── dashboard_screen.dart        # Caught monsters + catch FAB
│   ├── catch_screen.dart            # GPS scan + catch with flashlight/sound
│   ├── monsters_screen.dart         # Monster CRUD list + map
│   ├── monster_form_screen.dart     # Add/edit monster with map + image upload
│   ├── leaderboard_screen.dart      # Top 10 podium + rankings
│   └── settings_screen.dart        # Profile edit + VPN status + logout
├── widgets/
│   ├── ec2_status_button.dart       # EC2 toggle pill (welcome + settings)
│   ├── tailscale_dialog.dart        # VPN instructions popup + EC2 panel
│   └── app_snackbar.dart            # Styled success/error/gotcha snackbars
└── assets/
    ├── images/
    │   ├── android_branding.png     # Splash Screen Branding Android 12 & Above
    │   ├── android_logo.png         # Splash Screen Logo Android 12 & Above
    │   ├── branding_splash.png      # Splash Screen Branding Android 11 & Below
    │   ├── logo_splash.png          # Splash Screen Logo Android 11 & Below
    │   ├── logo.png                 # App logo    
    │   ├── logo.png                 # App logo
    │   └── types/                   # 18 type images (400x160px PNG)
    │       ├── normal.png
    │       ├── fire.png
    │       ├── water.png
    │       └── ... (all 18 types)
    ├── fonts/
    │   └── ComicRelief-Regular.ttf
    └── sounds/
        └── gotcha.mp3               # Catch sound effect
```

### Configuration

Update `lib/constants/api.dart` with your values:

```dart
class ApiConfig {
  static const String tailnetName = 'YOUR-TAILNET.ts.net';
  static const int apiPort = 8000;

  static String get baseUrl =>
      'http://.$tailnetName:$apiPort';

  static const String lambdaUrl =
      'https://XXXXXXX.lambda-url.us-east-1.on.aws/';

  // EC2 Instance IDs
  static const String webServerInstanceId = 'i-XXXXXXXXXXXXXXXXX';
  static const String dbServerInstanceId  = 'i-XXXXXXXXXXXXXXXXX';
  static const String webServerRegion = 'eu-west-3';
  static const String dbServerRegion  = 'us-east-1';
}

### Running the App

```bash
flutter clean
flutter pub get
flutter run
```

For release build:

```bash
flutter build apk --release
```

### Required Android Permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.FLASHLIGHT"/>
<uses-feature android:name="android.hardware.camera.flash" android:required="false"/>
```

---

## Features

### 🔐 Authentication
- Player registration with unique username and player name validation
- MD5 password hashing before transmission and storage
- Persistent session via SharedPreferences (auto-login on relaunch)
- Secure logout with session clearing

### 🌐 VPN & Server Guard
- All API access gated behind Tailscale VPN
- On every action: checks EC2 status first, then VPN reachability
- Server offline → EC2 panel opens automatically
- VPN disconnected → Tailscale instructions popup with step-by-step guide
- Login/Register buttons greyed out until both servers are running

### 🎮 Monster Catching
- GPS-based proximity detection using Haversine formula
- Monsters spawn at registered GPS coordinates with configurable radius
- SCAN AREA button checks for monsters within range
- On catch: plays sound + strobes flashlight for 5 seconds
- Caught monsters displayed with type-colored borders and timestamps (GMT+8)
- Tap any caught monster to see catch coordinates and details
- Release (delete) caught monsters

### 🦎 Monster Management
- Full CRUD for monsters
- Map view showing all spawn locations with radius circles
- Type dropdown with PNG type images (18 types supported)
- Image upload to web server with URL auto-populated
- Spawn location set by tapping on OpenStreetMap (no API key needed)
- Live radius circle preview on map

### 🏆 Leaderboard
- Top 10 players by total catches
- Podium display for top 3 (gold/silver/bronze)
- Handles 1, 2, or 3+ players gracefully

### ⚙️ Settings
- Change player name, username, and password
- Real-time Tailscale connection status
- EC2 instance toggle and status (web + DB servers)
- Logout with confirmation dialog

### ☁️ EC2 Management
- Start/stop EC2 instances directly from the app
- Live status indicators (running/stopped/pending)
- Available on Welcome screen and Settings screen
- Powered by AWS Lambda — no credentials stored in app

---

## Dependencies

### Flutter Packages

```yaml
dependencies:
  http: ^1.2.0
  shared_preferences: ^2.2.3
  geolocator: ^12.0.0
  permission_handler: ^11.3.1
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  audioplayers: ^6.0.0
  torch_light: ^1.0.0
  crypto: ^3.0.3
  cached_network_image: ^3.3.1
  image_picker: ^1.1.0
```

### API Server (Node.js)

```json
{
  "express": "latest",
  "mysql2": "latest",
  "cors": "latest",
  "body-parser": "latest",
  "multer": "latest",
  "dotenv": "latest",
  "pm2": "global"
}
```

---

## Monster Types

The app supports all 18 monster types, each with a custom color and PNG badge image:

| Type | Color | | Type | Color |
|------|-------|-|------|-------|
| Normal | `#bbbbaa` | | Fire | `#ff4422` |
| Water | `#3399ff` | | Grass | `#77cc55` |
| Electric | `#ffcc33` | | Ice | `#77ddff` |
| Fighting | `#bb5544` | | Poison | `#aa5599` |
| Ground | `#ddbb55` | | Flying | `#6699ff` |
| Psychic | `#ff5599` | | Bug | `#77cc55` |
| Rock | `#bbaa66` | | Ghost | `#6666bb` |
| Dragon | `#7766ee` | | Dark | `#775544` |
| Steel | `#aaaabb` | | Fairy | `#ffaaff` |

Type PNG images should be placed at `assets/images/types/<typename>.png` (400×160px recommended).

---

## Notes

- The app uses **OpenStreetMap** via `flutter_map` for all map views
- Images uploaded through the app are stored in `/home/ec2-user/hauapi/uploads/monsters/` on the web server and served statically at `http://<tailscale-host>:8000/uploads/monsters/<filename>`
- All timestamps are stored in UTC and displayed in **GMT+8 (24-hour format)**

---
