import 'dart:io';

/// Logical platform identifier used by Minecraft library rules and our
/// natives-extraction code.
enum LauncherOs { linux, osx, windows, android, ios }

/// Logical CPU architecture identifier matching Minecraft's manifest values
/// (`x86`, `x86_64`, `arm64`, `arm32`).
enum LauncherArch { x86, x64, arm32, arm64 }

class PlatformArch {
  PlatformArch._();

  static LauncherOs get os {
    if (Platform.isAndroid) return LauncherOs.android;
    if (Platform.isIOS) return LauncherOs.ios;
    if (Platform.isMacOS) return LauncherOs.osx;
    if (Platform.isWindows) return LauncherOs.windows;
    return LauncherOs.linux;
  }

  /// Minecraft's library rules treat Android as "linux" for native selection
  /// (we resolve real natives via our own bridge anyway, but rule evaluation
  /// must compare against linux/osx/windows strings).
  static String ruleOsName() {
    switch (os) {
      case LauncherOs.windows:
        return 'windows';
      case LauncherOs.osx:
      case LauncherOs.ios:
        return 'osx';
      default:
        return 'linux';
    }
  }

  /// Best-effort runtime detection of CPU architecture. On Android we ask the
  /// native plugin (see `JavaRuntimeBridge.getAbi`) for the ground-truth ABI;
  /// this Dart side fallback is only used when the bridge isn't reachable
  /// (e.g. tests).
  static LauncherArch fallbackArch() {
    final v = Platform.version.toLowerCase();
    if (v.contains('arm64') || v.contains('aarch64')) return LauncherArch.arm64;
    if (v.contains('arm')) return LauncherArch.arm32;
    if (v.contains('x86_64') || v.contains('x64')) return LauncherArch.x64;
    return LauncherArch.x86;
  }
}
