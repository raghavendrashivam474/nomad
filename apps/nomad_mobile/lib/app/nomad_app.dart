import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import '../data/repositories/local_project_repository.dart';
import 'app_shell.dart';

class NomadApp extends StatelessWidget {
  final ProjectRepository? repository;

  const NomadApp({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nomad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: AppShell(
        repository: repository ?? LocalProjectRepository(),
      ),
    );
  }
}
