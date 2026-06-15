import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/errors/launcher_exception.dart';
import '../../domain/entities/java_runtime.dart';
import '../../domain/services/launch_command_builder.dart';
import '../common/runtime_bridge.dart';

/// Android bridge into native Kotlin code.
///
/// The native side (`WiskLauncherPlugin.kt`) exposes:
///   * `getAbi`              -> String  (e.g. "arm64-v8a")
///   * `verifyJava`          -> bool
///   * `installJava`         -> Map (executablePath, fullVersion, vendor)
///   * `launch`              -> void (starts a process; events come via the
///                                    `wisklauncher/events` EventChannel)
///   * `stop`                -> void
class AndroidRuntimeBridge implements RuntimeBridge {
  static const _method = MethodChannel('wisklauncher/runtime');
  static const _events = EventChannel('wisklauncher/events');

  @override
  Future<String> getAbi() async {
    final result = await _method.invokeMethod<String>('getAbi');
    return result ?? 'arm64-v8a';
  }

  @override
  Future<bool> verifyJava(String executablePath) async {
    final ok = await _method.invokeMethod<bool>(
      'verifyJava',
      {'executablePath': executablePath},
    );
    return ok ?? false;
  }

  @override
  Future<JavaRuntime> installJava({
    required int majorVersion,
    required String targetDir,
  }) async {
    final Map<String, dynamic>? m;
    try {
      m = await _method.invokeMapMethod<String, dynamic>(
        'installJava',
        {'majorVersion': majorVersion, 'targetDir': targetDir},
      );
    } on PlatformException catch (e) {
      throw LauncherException(
        e.code,
        e.message ?? 'Java $majorVersion could not be installed.',
        cause: e,
      );
    }
    if (m == null) {
      throw StateError('installJava returned null');
    }
    return JavaRuntime(
      id: 'java-$majorVersion',
      majorVersion: majorVersion,
      executablePath: m['executablePath'] as String,
      vendor: m['vendor'] as String?,
      fullVersion: m['fullVersion'] as String?,
    );
  }

  @override
  Stream<ProcessEvent> launch(LaunchPlan plan) async* {
    final controller = StreamController<ProcessEvent>();
    late final StreamSubscription sub;
    sub = _events.receiveBroadcastStream().listen((raw) {
      controller.add(_parseProcessEvent(raw));
    }, onError: controller.addError);
    await _method.invokeMethod('launch', {
      'executablePath': plan.javaExecutable,
      'arguments': plan.arguments,
      'workingDirectory': plan.workingDirectory,
      'environment': plan.environment,
    });
    try {
      yield* controller.stream;
    } finally {
      await sub.cancel();
      await controller.close();
    }
  }

  ProcessEvent _parseProcessEvent(Object? raw) {
    final m = (raw as Map).cast<String, dynamic>();
    switch (m['type'] as String) {
      case 'stdout':
        return ProcessStdout(m['line'] as String);
      case 'stderr':
        return ProcessStderr(m['line'] as String);
      case 'exit':
        return ProcessExited((m['code'] as num).toInt());
      default:
        return ProcessStdout('[unknown event] $m');
    }
  }

  @override
  Future<void> stop() async {
    await _method.invokeMethod('stop');
  }
}
