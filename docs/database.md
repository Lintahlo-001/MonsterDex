# Database Schema

[← Back to README](../README.md)

Database: `haumonstersDB` (MySQL 8.0 on Amazon RDS, see [aws-setup.md](aws-setup.md#rds-database)).

All timestamps are stored in UTC and displayed in the app in **GMT+8 (24-hour format)**.

## `playerstbl`

| Column | Type | Notes |
|--------|------|-------|
| `player_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `player_name` | VARCHAR(150) | Display name (unique) |
| `username` | VARCHAR(100) | Login username (unique) |
| `password` | VARCHAR(255) | MD5 hashed |
| `created_at` | DATETIME | Default: CURRENT_TIMESTAMP |

## `monsterstbl`

| Column | Type | Notes |
|--------|------|-------|
| `monster_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `monster_name` | VARCHAR(100) | |
| `monster_type` | VARCHAR(100) | One of 18 types |
| `spawn_latitude` | DECIMAL(10,7) | GPS coordinate |
| `spawn_longitude` | DECIMAL(10,7) | GPS coordinate |
| `spawn_radius_meters` | DECIMAL(10,2) | Default: 100.00 |
| `picture_url` | VARCHAR(500) | Uploaded image URL |

## `monster_catchestbl`

| Column | Type | Notes |
|--------|------|-------|
| `catch_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `player_id` | INT UNSIGNED | FK → playerstbl |
| `monster_id` | INT UNSIGNED | FK → monsterstbl |
| `location_id` | INT UNSIGNED | FK → locationstbl |
| `latitude` | DECIMAL(10,7) | Where it was caught |
| `longitude` | DECIMAL(10,7) | Where it was caught |
| `catch_datetime` | DATETIME | Default: CURRENT_TIMESTAMP |

## `locationstbl`

| Column | Type | Notes |
|--------|------|-------|
| `location_id` | INT UNSIGNED AUTO_INCREMENT | Primary Key |
| `location_name` | VARCHAR(100) | |

> **Setup note:** the API's `/catch` endpoint currently always writes `location_id = 1`, so `locationstbl` must contain a row with `location_id` 1 or catches will fail the foreign key check.
