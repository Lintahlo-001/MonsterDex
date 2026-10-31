# Flutter App

[← Back to README](../README.md)

## Contents

- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Running the App](#running-the-app)
- [Android Permissions](#android-permissions)
- [Project Structure](#project-structure)
- [Monster Types](#monster-types)
- [Notes](#notes)

## Prerequisites

- Flutter 3.32 or newer (Dart `^3.8.1`, see `pubspec.yaml`)
- Android Studio or VS Code
- Android device or emulator (API 23+)
- Tailscale installed on your phone

## Configuration

The app reads its server settings **at build time** from a git-ignored `env.json` file, so your real addresses are never committed. They are passed to Flutter with `--dart-define-from-file`, and `lib/constants/api.dart` reads them with `String.fromEnvironment`.

**1. Create your config from the template:**

```bash
cp env.example.json env.json
```

**2. Fill in `env.json`:**

```json
{
  "TAILNET_NAME": "<machine>.<your-tailnet>.ts.net",
  "API_PORT": 8000,
  "LAMBDA_URL": "https://<your-function-id>.lambda-url.us-east-1.on.aws/",
  "WEB_SERVER_INSTANCE_ID": "i-XXXXXXXXXXXXXXXXX",
  "WEB_SERVER_REGION": "eu-west-3"
}
```

| Key | Description | Default |
|-----|-------------|---------|
| `TAILNET_NAME` | Full MagicDNS hostname of the web server ([tailscale.md](tailscale.md#magicdns)) | none, required |
| `API_PORT` | Port the API listens on | `8000` |
| `LAMBDA_URL` | Lambda Function URL ([aws-setup.md](aws-setup.md#lambda-function)) | none, required |
| `WEB_SERVER_INSTANCE_ID` | EC2 instance ID of the web server (the DB is managed by RDS) | none, required |
| `WEB_SERVER_REGION` | AWS region of the web server | `eu-west-3` |

## Running the App

Always pass the config file, otherwise the app is built with empty server settings and cannot reach a server:

```bash
flutter clean
flutter pub get
flutter run --dart-define-from-file=env.json
```

Release build:

```bash
flutter build apk --release --dart-define-from-file=env.json
```

**IDE setup**

- **VS Code:** in `.vscode/launch.json`, add `"args": ["--dart-define-from-file=env.json"]` to your Flutter launch configuration.
- **Android Studio:** open **Run → Edit Configurations**, then put `--dart-define-from-file=env.json` in **Additional run args** (and **Additional build args** for release builds).

## Android Permissions

The permissions below are declared in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
<uses-permission android:name="android.permission.FLASHLIGHT"/>
<uses-feature android:name="android.hardware.camera.flash" android:required="false"/>
```

## Project Structure

```
lib/
├── main.dart                        # App entry, session restore
├── constants/
│   ├── theme.dart                   # Colors, gradients, type colors
│   └── api.dart                     # Server settings read from env.json
├── models/
│   ├── player.dart
│   ├── monster.dart
│   └── catch.dart
├── services/
│   ├── api_service.dart             # HTTP wrapper (get/post/put/delete)
│   ├── tailscale_service.dart       # VPN + server status checks
│   ├── lambda_service.dart          # EC2 start/stop/status via Lambda
│   └── permission_service.dart      # Android runtime permissions
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
│   └── settings_screen.dart         # Profile edit + VPN status + logout
└── widgets/
    ├── ec2_status_button.dart       # EC2 toggle pill (welcome + settings)
    ├── tailscale_dialog.dart        # VPN instructions popup + EC2 panel
    └── app_snackbar.dart            # Styled success/error/gotcha snackbars

assets/
├── images/
│   ├── icon.png                     # Launcher icon source
│   ├── logo.png                     # App logo
│   ├── android_branding.png         # Splash branding, Android 12 and above
│   ├── android_logo.png             # Splash logo, Android 12 and above
│   ├── branding_splash.png          # Splash branding, Android 11 and below
│   ├── logo_splash.png              # Splash logo, Android 11 and below
│   ├── readme/                      # Screenshots used in the README
│   └── types/                       # 18 type images (400x160px PNG)
│       ├── normal.png
│       ├── fire.png
│       ├── water.png
│       └── ... (all 18 types)
├── fonts/
│   ├── ComicRelief-Regular.ttf
│   └── ComicRelief-Bold.ttf
└── sounds/
    └── gotcha.mp3                   # Catch sound effect
```

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

Type PNG images should be placed at `assets/images/types/<typename>.png` (400×160px recommended). They are taken from the Pokémon X/Y game assets, see [Credits](../README.md#credits).

## Notes

- The app uses OpenStreetMap via `flutter_map` for all map views.
- Images uploaded through the app are stored on the web server and served by the API, see [api.md](api.md#file-uploads).
- All timestamps are stored in UTC and displayed in **GMT+8 (24-hour format)**.
