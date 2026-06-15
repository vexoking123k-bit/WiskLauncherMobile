import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/errors/launcher_exception.dart';
import '../../domain/entities/java_runtime.dart';
import '../../domain/services/launch_command_builder.dart';
import '../android/android_runtime_bridge.dart';
import '../ios/ios_runtime_bridge.dart';

/// Event from a running game process.
sealed class ProcessEvent {
  const ProcessEvent();
}

class ProcessStdout extends ProcessEvent {
  final String line;
  const ProcessStdout(this.line);
}

class ProcessStderr extends ProcessEvent {
  final String line;
  const ProcessStderr(this.line);
}

class ProcessExited extends ProcessEvent {
  final int exitCode;
  const ProcessExited(this.exitCode);
}

/// Abstract interface implemented by per-platform runtime bridges.
///
/// * Android: spawns a real `java` process via a Kotlin MethodChannel host.
/// * iOS:    every "launch" method throws PlatformUnsupportedException.
abstract class RuntimeBridge {
  /// Returns the bridge for the current platform.
  factory RuntimeBridge.platform() {
    if (Platform.isAndroid) return AndroidRuntimeBridge();
    if (Platform.isIOS) return IosRuntimeBridge();
    // Desktop dev builds fall through to a noop so the UI still works.
    return _DesktopNoopBridge();
  }

  /// CPU ABI of the current device, e.g. "arm64-v8a". Used to pick a Java
  /// runtime download.
  Future<String> getAbi();

  /// Runs `<executablePath> -version` and returns true on exit code 0.
  Future<bool> verifyJava(String executablePath);

  /// Downloads & extracts an OpenJDK build for [majorVersion] into
  /// [targetDir]. Returns the registered [JavaRuntime].
  ///
  /// Implementations should choose builds from a reputable source (e.g.
  /// Adoptium / Azul) and verify checksums. iOS throws
  /// PlatformUnsupportedException.
  Future<JavaRuntime> installJava({
    required int majorVersion,
    required String targetDir,
  });

  /// Spawns the Java process described by [plan]. Returns a stream of
  /// process events terminated by [ProcessExited].
  Stream<ProcessEvent> launch(LaunchPlan plan);

  /// Cancels any in-flight launch.
  Future<void> stop();
}

class _DesktopNoopBridge implements RuntimeBridge {
  @override
  Future<String> getAbi() async => 'x86_64';

  @override
  Future<bool> verifyJava(String executablePath) async {
    final result = await Process.run(executablePath, ['-version']);
    return result.exitCode == 0;
  }

  @override
  Future<JavaRuntime> installJava({
    required int majorVersion,
    required String targetDir,
  }) async {
    throw const PlatformUnsupportedException(
        'Auto-installing Java is only implemented on Android. Point at a system JVM instead.');
  }

  @override
  Stream<ProcessEvent> launch(LaunchPlan plan) async* {
    final proc = await Process.start(
      plan.javaExecutable,
      plan.arguments,
      workingDirectory: plan.workingDirectory,
      environment: plan.environment,
    );
    yield* StreamGroup.combine(proc);
  }

  @override
  Future<void> stop() async {}
}

/// Internal helper to combine stdout/stderr/exit code into a single stream.
class StreamGroup {
  static Stream<ProcessEvent> combine(Process p) async* {
    final controller = StreamController<ProcessEvent>();
    p.stdout.transform(const SystemEncoding().decoder).transform(const LineSplitter())
        .listen((line) => controller.add(ProcessStdout(line)));
    p.stderr.transform(const SystemEncoding().decoder).transform(const LineSplitter())
        .listen((line) => controller.add(ProcessStderr(line)));
    unawaited(p.exitCode.then((code) async {
      controller.add(ProcessExited(code));
      await controller.close();
    }));
    yield* controller.stream;
  }
}
