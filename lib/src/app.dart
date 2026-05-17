import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/app_bootstrap.dart';
import 'state/picklist_controller.dart';
import 'ui/screens/event_list_screen.dart';
import 'ui/screens/workspace_screen.dart';

class ProviderScope extends StatelessWidget {
  const ProviderScope({required this.bootstrap, required this.child, super.key});

  final AppBootstrap bootstrap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PickListController(
            repository: bootstrap.repository,
            authService: bootstrap.authService,
          )..initialize(),
        ),
      ],
      child: child,
    );
  }
}

class PickListApp extends StatelessWidget {
  const PickListApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1D4ED8),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF07111F),
      cardTheme: CardThemeData(
        color: const Color(0xFF0E1A2B),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );

    return MaterialApp(
      title: 'PickList',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const _AppFrame(),
    );
  }
}

class _AppFrame extends StatelessWidget {
  const _AppFrame();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PickListController>();
    final selectedWorkspace = controller.selectedWorkspace;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: selectedWorkspace == null
          ? const EventListScreen(key: ValueKey('events'))
          : WorkspaceScreen(
              key: ValueKey(selectedWorkspace.workspace.id),
            ),
    );
  }
}
