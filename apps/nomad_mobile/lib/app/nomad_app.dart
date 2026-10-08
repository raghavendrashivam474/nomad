import 'package:flutter/material.dart';
import 'package:nomad_core/nomad_core.dart';
import '../branding/nomad_brand.dart';
import '../data/repositories/local_file_content_repository.dart';
import '../data/repositories/local_project_repository.dart';
import '../data/repositories/local_workspace_repository.dart';
import 'app_shell.dart';

class NomadApp extends StatelessWidget {
  final ProjectRepository? repository;
  final WorkspaceRepository? workspaceRepository;
  final FileContentRepository? contentRepository;

  const NomadApp({
    super.key,
    this.repository,
    this.workspaceRepository,
    this.contentRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: NomadBrand.productName,
      debugShowCheckedModeBanner: false,
      theme: NomadBrand.lightTheme(),
      darkTheme: NomadBrand.darkTheme(),
      themeMode: ThemeMode.system,
      home: AppShell(
        repository: repository ?? LocalProjectRepository(),
        workspaceRepository: workspaceRepository ?? LocalWorkspaceRepository(),
        contentRepository: contentRepository ?? LocalFileContentRepository(),
      ),
    );
  }
}
