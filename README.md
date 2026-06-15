# WiskLauncher Mobile

A cross-platform Minecraft Java Edition launcher for Android and iOS, built with Flutter.

**Legal notice:** WiskLauncher only supports official Microsoft/Mojang authentication and official game files downloaded from Mojang/Microsoft endpoints. It does not ship, support, or enable cracked logins, piracy, or any unofficial account bypass. See [LEGAL.md](LEGAL.md).

## Status

| Platform | Download / Install | Profiles | Launch         |
|----------|--------------------|----------|----------------|
| Android  | Supported          | Supported| Supported (native JVM bridge) |
| iOS      | Supported          | Supported| **Unsupported** on stock iOS (sandbox / JIT restrictions). The iOS build runs as a manager/downloader. |

See [docs/IOS_LIMITATIONS.md](docs/IOS_LIMITATIONS.md) for the honest breakdown.

## Architecture

```
lib/
  core/         constants, errors, small utilities
  data/         datasources (HTTP, FS), DTO models, repository impls
  domain/       pure entities, repository interfaces, services
  platform/    platform channel bridges (Android, iOS, common)
  presentation/ Flutter pages, widgets, theme
```

Native modules:

```
android/app/src/main/kotlin/com/wiskcraft/wisklauncher/
    WiskLauncherPlugin.kt    -- MethodChannel host
    JavaRuntimeBridge.kt     -- spawn java process, pipe stdout/stderr
    NativeExtractor.kt       -- extract Minecraft natives (.so) to per-profile dir

ios/Runner/
    WiskLauncherPlugin.swift -- limitation-honest bridge (download/profile ops only)
```

## Setup

Prereqs: Flutter 3.22+, Android Studio (Android SDK 34, NDK 26), Xcode 15+ (iOS dev only).

```bash
cd WiskLauncherMobile
flutter pub get
# Android
flutter run -d <android-device>
# iOS  (downloader / manager mode only)
flutter run -d <ios-device>
```

### Microsoft OAuth

The app uses the public Minecraft launcher client id `00000000402b5328` (the same one used by the official Java launcher) via the device-code flow so that we never need a web redirect. Configure overrides in `lib/core/constants/auth_constants.dart` if you want to use your own Azure app.

### File layout on device

```
<app docs>/wisklauncher/
  runtimes/{java-8,java-17,java-21}/
  versions/<id>/<id>.{jar,json}
  libraries/...
  assets/{indexes,objects}/
  profiles/<profile>/
  logs/
  mods/
  configs/
```

## Tests

```bash
flutter test
```

## Roadmap & Legal

* [ROADMAP.md](ROADMAP.md)
* [LEGAL.md](LEGAL.md)
