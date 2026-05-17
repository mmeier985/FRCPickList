import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/picklist_models.dart';
import '../../state/picklist_controller.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  String? _selectedTeamId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PickListController>();
    final workspace = controller.selectedWorkspace;
    if (workspace == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final orderedTeams = _orderedTeams(workspace);
    final selectedTeam = _selectedTeamId == null ? null : workspace.teamById(_selectedTeamId!);
    final canEdit = controller.canEditBoard;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              workspace: workspace.workspace,
              onClose: controller.closeWorkspace,
              onImport: () => controller.importWorkspaceFile(workspace.workspace.id),
              onAddTeam: controller.canEditBoard ? () => _showAddTeamDialog(context, controller, workspace) : null,
              onAdmin: controller.canManageWorkspace ? () => _showAdminDialog(context, controller, workspace) : null,
              canEdit: controller.canEditBoard,
              canManage: controller.canManageWorkspace,
              memberCount: workspace.members.length,
              syncHint: controller.pendingImportMessage,
              syncState: controller.syncState,
              syncMessage: controller.syncMessage,
              lastSyncAt: controller.lastSyncAt,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;
                  final board = isWide
                      ? Row(
                          children: [
                            Expanded(flex: 5, child: _MasterRankingColumn(teams: orderedTeams, workspaceId: workspace.workspace.id, onSelect: _selectTeam, onReorder: controller.reorderMasterList, canEdit: canEdit)),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: _TeamDetailsPanel(team: selectedTeam, workspaceId: workspace.workspace.id, onAvailabilityChanged: controller.updateAvailability, onAddNote: controller.addNote)),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _MasterRankingColumn(teams: orderedTeams, workspaceId: workspace.workspace.id, onSelect: _selectTeam, onReorder: controller.reorderMasterList, canEdit: canEdit),
                            const SizedBox(height: 16),
                            _TeamDetailsPanel(team: selectedTeam, workspaceId: workspace.workspace.id, onAvailabilityChanged: controller.updateAvailability, onAddNote: controller.addNote),
                          ],
                        );
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: board,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectTeam(String teamId) {
    setState(() => _selectedTeamId = teamId);
  }

  Future<void> _showAdminDialog(
    BuildContext context,
    PickListController controller,
    WorkspaceState workspace,
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    MemberRole selectedRole = MemberRole.scout;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Workspace Members'),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current members'),
                        const SizedBox(height: 12),
                        ...workspace.members.map(
                          (member) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(member.displayName),
                            subtitle: Text('${member.email} • ${member.role.label}'),
                          ),
                        ),
                        const Divider(height: 24),
                        const Text('Invite member'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Display name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<MemberRole>(
                          initialValue: selectedRole,
                          items: MemberRole.values
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (role) {
                            if (role == null) return;
                            setDialogState(() => selectedRole = role);
                          },
                          decoration: const InputDecoration(labelText: 'Role'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  if (name.isEmpty || email.isEmpty) return;
                  await controller.addMember(
                    workspace.workspace.id,
                    PickListUser(
                      id: 'member-${DateTime.now().microsecondsSinceEpoch}',
                      displayName: name,
                      teamOrgId: workspace.workspace.teamOrgId,
                      email: email,
                      role: selectedRole,
                    ),
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    } finally {
      nameController.dispose();
      emailController.dispose();
    }
  }

  Future<void> _showAddTeamDialog(
    BuildContext context,
    PickListController controller,
    WorkspaceState workspace,
  ) async {
    final teamNumberController = TextEditingController();
    final nicknameController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add team'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: teamNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Team number'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(labelText: 'Nickname'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final number = int.tryParse(teamNumberController.text.trim());
                  final nickname = nicknameController.text.trim();
                  if (number == null || nickname.isEmpty) return;
                  await controller.createTeam(
                    workspace.workspace.id,
                    teamNumber: number,
                    nickname: nickname,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Add team'),
              ),
            ],
          );
        },
      );
    } finally {
      teamNumberController.dispose();
      nicknameController.dispose();
    }
  }

  List<TeamCard> _orderedTeams(WorkspaceState workspace) {
    final map = {for (final team in workspace.teams) team.id: team};
    return workspace.rankings
        .map((entry) => map[entry.teamId])
        .whereType<TeamCard>()
        .toList(growable: false);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.workspace,
    required this.onClose,
    required this.onImport,
    required this.onAddTeam,
    required this.onAdmin,
    required this.canEdit,
    required this.canManage,
    required this.memberCount,
    required this.syncHint,
    required this.syncState,
    required this.syncMessage,
    required this.lastSyncAt,
  });

  final EventWorkspace workspace;
  final VoidCallback onClose;
  final VoidCallback onImport;
  final VoidCallback? onAddTeam;
  final VoidCallback? onAdmin;
  final bool canEdit;
  final bool canManage;
  final int memberCount;
  final String? syncHint;
  final SyncState syncState;
  final String? syncMessage;
  final DateTime? lastSyncAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0E1A2B), Color(0xFF132742)]),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final actions = Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: isWide ? WrapAlignment.end : WrapAlignment.start,
            children: [
              if (syncHint != null) Text(syncHint!, style: const TextStyle(color: Colors.amberAccent)),
              _SyncBadge(state: syncState, message: syncMessage, lastSyncAt: lastSyncAt),
              OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import'),
              ),
              if (canEdit)
                OutlinedButton.icon(
                  onPressed: onAddTeam,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add team'),
                ),
              if (canManage)
                FilledButton.icon(
                  onPressed: onAdmin,
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Admin'),
                ),
              TextButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Workspaces'),
              ),
            ],
          );

          return isWide
              ? Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workspace.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${workspace.status.name.toUpperCase()} · $memberCount members · ${canEdit ? 'edit enabled' : 'view only'}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const Spacer(),
                    actions,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workspace.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${workspace.status.name.toUpperCase()} · $memberCount members · ${canEdit ? 'edit enabled' : 'view only'}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
        },
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({
    required this.state,
    required this.message,
    required this.lastSyncAt,
  });

  final SyncState state;
  final String? message;
  final DateTime? lastSyncAt;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      SyncState.idle => Colors.white70,
      SyncState.syncing => Colors.lightBlueAccent,
      SyncState.saved => Colors.lightGreenAccent,
      SyncState.failed => Colors.redAccent,
    };
    final label = switch (state) {
      SyncState.idle => 'Idle',
      SyncState.syncing => 'Saving...',
      SyncState.saved => 'Saved',
      SyncState.failed => 'Needs attention',
    };
    final subtitle = lastSyncAt == null ? '' : ' • ${TimeOfDay.fromDateTime(lastSyncAt!).format(context)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message == null ? '$label$subtitle' : '$label$subtitle • $message',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MasterRankingColumn extends StatelessWidget {
  const _MasterRankingColumn({
    required this.teams,
    required this.workspaceId,
    required this.onSelect,
    required this.onReorder,
    required this.canEdit,
  });

  final List<TeamCard> teams;
  final String workspaceId;
  final void Function(String teamId) onSelect;
  final Future<void> Function(String workspaceId, List<String> orderedTeamIds) onReorder;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Master Ranking', style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                Text('${teams.length} teams', style: const TextStyle(color: Colors.white60)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Drag to reorder the canonical alliance selection list.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 12),
            if (teams.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No teams imported yet.', style: TextStyle(color: Colors.white54)),
              )
            else if (!canEdit)
              ...[
                for (var index = 0; index < teams.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TeamTile(team: teams[index], rank: index + 1),
                  ),
              ]
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: teams.length,
                onReorder: (oldIndex, newIndex) async {
                  final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
                  final ids = teams.map((team) => team.id).toList(growable: true);
                  final moving = ids.removeAt(oldIndex);
                  ids.insert(adjustedIndex, moving);
                  await onReorder(workspaceId, ids);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    key: ValueKey(teams[index].id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReorderableTeamTile(
                      team: teams[index],
                      rank: index + 1,
                      onSelect: () => onSelect(teams[index].id),
                      dragIndex: index,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReorderableTeamTile extends StatelessWidget {
  const _ReorderableTeamTile({
    required this.team,
    required this.rank,
    required this.onSelect,
    required this.dragIndex,
  });

  final TeamCard team;
  final int rank;
  final VoidCallback onSelect;
  final int dragIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSelect,
          child: _TeamTile(team: team, rank: rank),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: ReorderableDragStartListener(
            index: dragIndex,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_indicator),
            ),
          ),
        ),
      ],
    );
  }
}

class _TeamDetailsPanel extends StatefulWidget {
  const _TeamDetailsPanel({
    required this.team,
    required this.workspaceId,
    required this.onAvailabilityChanged,
    required this.onAddNote,
  });

  final TeamCard? team;
  final String workspaceId;
  final Future<void> Function(String workspaceId, String teamId, AvailabilityState availability) onAvailabilityChanged;
  final Future<void> Function(String workspaceId, String teamId, String noteText) onAddNote;

  @override
  State<_TeamDetailsPanel> createState() => _TeamDetailsPanelState();
}

class _TeamDetailsPanelState extends State<_TeamDetailsPanel> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: widget.team == null
            ? const Center(child: Text('Select a team to see notes, metrics, and status'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.team!.teamNumber} ${widget.team!.nickname}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(label: widget.team!.availability.label),
                      ...widget.team!.tags.map((tag) => _StatusChip(label: tag)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Imported metrics', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...widget.team!.importedMetrics.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Text(entry.value.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Availability', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: AvailabilityState.values
                        .map(
                          (value) => ChoiceChip(
                            label: Text(value.label),
                            selected: value == widget.team!.availability,
                            onSelected: (_) => widget.onAvailabilityChanged(widget.workspaceId, widget.team!.id, value),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Add scouting note'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        final note = _noteController.text.trim();
                        if (note.isEmpty) return;
                        widget.onAddNote(widget.workspaceId, widget.team!.id, note);
                        _noteController.clear();
                      },
                      child: const Text('Save note'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: ListView.separated(
                      itemCount: widget.team!.notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final note = widget.team!.notes[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1D2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(note.authorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(note.body),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team, required this.rank});

  final TeamCard team;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1D4ED8),
            child: Text('$rank', style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${team.teamNumber} ${team.nickname}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(team.availability.label, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.drag_indicator),
        ],
      ),
    );
  }
}


class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: const Color(0xFF15263D),
      side: BorderSide.none,
    );
  }
}
