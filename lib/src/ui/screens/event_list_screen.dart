import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/import_parser.dart';
import '../../models/picklist_models.dart';
import '../../state/picklist_controller.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final TextEditingController _nameController = TextEditingController(text: '2026 Week 1');

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PickListController>();
    final summaries = controller.summaries;
    final user = controller.user;
    final needsProfile = user != null && user.teamOrgId.isEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06111F), Color(0xFF0B1E35), Color(0xFF132A4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final content = isWide
                            ? Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _HeroPanel(
                                    onCreate: () => controller.createWorkspace(_nameController.text.trim().isEmpty ? 'New Event Workspace' : _nameController.text.trim()),
                                    onImport: () => _handleImport(context, controller),
                                    nameController: _nameController,
                                    busy: controller.busy,
                                    loading: controller.loading,
                                    error: controller.error,
                                    user: user,
                                    onSignOut: controller.signOutAndClear,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 4,
                                  child: needsProfile
                                      ? _ProfilePanel(
                                          user: user,
                                          onSave: controller.saveMyProfile,
                                        )
                                      : _WorkspaceList(
                                          summaries: summaries,
                                          onSelect: controller.selectWorkspace,
                                        ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _HeroPanel(
                                  onCreate: () => controller.createWorkspace(_nameController.text.trim().isEmpty ? 'New Event Workspace' : _nameController.text.trim()),
                                  onImport: () => _handleImport(context, controller),
                                  nameController: _nameController,
                                  busy: controller.busy,
                                  loading: controller.loading,
                                  error: controller.error,
                                  user: user,
                                  onSignOut: controller.signOutAndClear,
                                ),
                                const SizedBox(height: 24),
                                needsProfile
                                    ? _ProfilePanel(
                                        user: user,
                                        onSave: controller.saveMyProfile,
                                      )
                                    : _WorkspaceList(
                                        summaries: summaries,
                                        onSelect: controller.selectWorkspace,
                                      ),
                              ],
                            );
                      return content;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleImport(BuildContext context, PickListController controller) async {
    final preview = await controller.pickImportPreview();
    if (preview == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportPreviewDialog(preview: preview),
    );
    if (confirmed == true && context.mounted) {
      final workspace = controller.selectedWorkspace;
      if (workspace != null) {
        await controller.importWorkspacePreview(workspace.workspace.id, preview);
      }
    } else {
      controller.clearImportPreview();
    }
  }
}

class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({required this.preview});

  final ImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final visibleIssues = preview.issues.take(6).toList(growable: false);
    return AlertDialog(
      title: Text('Import preview: ${preview.fileName}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${preview.rows.length} teams ready to import.'),
              const SizedBox(height: 12),
              if (visibleIssues.isNotEmpty) ...[
                const Text('Review these issues before continuing:'),
                const SizedBox(height: 8),
                ...visibleIssues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $issue', style: const TextStyle(color: Colors.orangeAccent)),
                  ),
                ),
                if (preview.issues.length > visibleIssues.length)
                  Text('• and ${preview.issues.length - visibleIssues.length} more...', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
              ],
              if (preview.rows.isNotEmpty) ...[
                const Text('First few rows:'),
                const SizedBox(height: 8),
                ...preview.rows.take(5).map(
                  (row) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row.teamNumber} • ${row.nickname}'),
                    subtitle: Text(
                      row.metrics.isEmpty
                          ? 'No numeric metrics'
                          : row.metrics.entries.map((entry) => '${entry.key}: ${entry.value}').join(' • '),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: preview.rows.isEmpty ? null : () => Navigator.of(context).pop(true),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.onCreate,
    required this.onImport,
    required this.nameController,
    required this.busy,
    required this.loading,
    required this.error,
    required this.user,
    required this.onSignOut,
  });

  final VoidCallback onCreate;
  final VoidCallback onImport;
  final TextEditingController nameController;
  final bool busy;
  final bool loading;
  final String? error;
  final PickListUser? user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collaborative Pick List',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'One master ranking and live team collaboration for alliance selection.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Event workspace name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onCreate,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(loading ? 'Loading...' : 'Create workspace'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import teams'),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            _FeatureRow(
              label: 'Signed in',
              value: user == null ? 'No' : '${user!.displayName} • ${user!.teamOrgId}',
            ),
            if (user != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
            const SizedBox(height: 12),
            const _FeatureRow(label: 'Realtime sync', value: 'Firebase-ready'),
            const _FeatureRow(label: 'Offline cache', value: 'Basic retry queue'),
            const _FeatureRow(label: 'Roles', value: 'Workspace member roles'),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _WorkspaceList extends StatelessWidget {
  const _WorkspaceList({
    required this.summaries,
    required this.onSelect,
  });

  final List<WorkspaceSummary> summaries;
  final Future<void> Function(String workspaceId) onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Event workspaces', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: summaries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      tileColor: const Color(0xFF11243A),
                      title: Text(summary.workspace.name),
                      subtitle: Text('${summary.teamCount} teams'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSelect(summary.workspace.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePanel extends StatefulWidget {
  const _ProfilePanel({
    required this.user,
    required this.onSave,
  });

  final PickListUser? user;
  final Future<void> Function({
    required String displayName,
    required String teamOrgId,
  }) onSave;

  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _teamOrgController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.user?.displayName ?? '');
    _teamOrgController = TextEditingController(text: widget.user?.teamOrgId ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _teamOrgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complete your profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Set your team organization so the app can load your event workspaces.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teamOrgController,
              decoration: const InputDecoration(labelText: 'Team org id'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final displayName = _displayNameController.text.trim();
                      final teamOrgId = _teamOrgController.text.trim();
                      if (displayName.isEmpty || teamOrgId.isEmpty) return;
                      setState(() => _saving = true);
                      try {
                        await widget.onSave(
                          displayName: displayName,
                          teamOrgId: teamOrgId,
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _saving = false);
                        }
                      }
                    },
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}
