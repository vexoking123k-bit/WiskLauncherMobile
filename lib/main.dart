import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/paths.dart';
import 'presentation/app_shell.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LauncherPaths.initialize();
  runApp(const ProviderScope(child: WiskLauncherApp()));
}

class WiskLauncherApp extends StatelessWidget {
  const WiskLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WiskLauncher Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
