import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/errors/launcher_exception.dart';
import '../../domain/entities/java_runtime.dart';
import '../../domain/services/launch_command_builder.dart';
import '../common/runtime_bridge.dart';

/// iOS bridge. The native side (`WiskLauncherPlugin.swift`) only implements
/// safe, sandbox-legal operations: ABI detection and Java-binary metadata
/// inspection if the user supplies a sideloaded JDK. Any attempt to actually
/// *launch* the JVM throws PlatformUnsupportedException — see
/// docs/IOS_LIMITATIONS.md for the why.
class IosRuntimeBridge implements RuntimeBridge {
  static const _method = MethodChannel('wisklauncher/runtime');

  @override
  Future<String> getAbi() async {
    final result = await _method.invokeMethod<String>('getAbi');
    return result ?? 'arm64';
  }

  @override
  Future<bool> verifyJava(String executablePath) async {
    // On stock iOS we cannot exec a binary, but we can stat the file and
    // confirm it's a Mach-O. The native side does that check.
    final ok = await _method.invokeMethod<bool>(
      'inspectJava',
      {'executablePath': executablePath},
    );
    return ok ?? false;
  }

  @override
  Future<JavaRuntime> installJava({
    required int majorVersion,
    required String targetDir,
  }) async {
    throw const PlatformUnsupportedException(
        'Installing a runnable JVM is not possible on stock iOS. '
        'See docs/IOS_LIMITATIONS.md.');
  }

  @override
  Stream<ProcessEvent> launch(LaunchPlan plan) {
    return Stream.error(const PlatformUnsupportedException(
        'Launching Minecraft Java is not supported on iOS. '
        'WiskLauncher Mobile on iOS is a manager / downloader only.'));
  }

  @override
  Future<void> stop() async {}
}
