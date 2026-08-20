import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/main_shell.dart';
import 'theme/omnispex_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OmnispexApp()));
}

class OmnispexApp extends StatelessWidget {
  const OmnispexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omnispex Engine',
      debugShowCheckedModeBanner: false,
      theme: OmnispexTheme.darkTheme,
      home: const MainShell(),
    );
  }
}
