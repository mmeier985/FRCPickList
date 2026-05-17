import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.initialize();
  runApp(
    ProviderScope(
      bootstrap: bootstrap,
      child: const PickListApp(),
    ),
  );
}
