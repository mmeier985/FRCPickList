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
    final buckets = workspace.buckets;
    final canEdit = controller.canEditBoard;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              workspace: workspace.workspace,
              onClose: controller.closeWorkspace,
              onImport: () => controller.importWorkspaceFile(workspace.workspace.id),
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
                            Expanded(flex: 4, child: _MasterRankingColumn(teams: orderedTeams, workspaceId: workspace.workspace.id, onSelect: _selectTeam, onReorder: controller.reorderMasterList, canEdit: canEdit, onRemoveFromBucket: controller.removeTeamFromBucket)),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: _BucketsColumn(buckets: buckets, workspace: workspace, onSelectTeam: _selectTeam, onMoveToBucket: controller.moveTeamToBucket, onReorderBucket: controller.reorderBucketTeams, onMoveBetweenBuckets: controller.moveTeamBetweenBuckets, canEdit: canEdit)),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: _TeamDetailsPanel(team: selectedTeam, workspaceId: workspace.workspace.id, onAvailabilityChanged: controller.updateAvailability, onAddNote: controller.addNote)),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _MasterRankingColumn(teams: orderedTeams, workspaceId: workspace.workspace.id, onSelect: _selectTeam, onReorder: controller.reorderMasterList, canEdit: canEdit, onRemoveFromBucket: controller.removeTeamFromBucket),
                            const SizedBox(height: 16),
                            _BucketsColumn(buckets: buckets, workspace: workspace, onSelectTeam: _selectTeam, onMoveToBucket: controller.moveTeamToBucket, onReorderBucket: controller.reorderBucketTeams, onMoveBetweenBuckets: controller.moveTeamBetweenBuckets, canEdit: canEdit),
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
                        Text('${workspace.status.name.toUpperCase()} | $memberCount members | ${canEdit ? 'edit enabled' : 'view only'}', style: const TextStyle(color: Colors.white70)),
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
                    Text('${workspace.status.name.toUpperCase()} | $memberCount members | ${canEdit ? 'edit enabled' : 'view only'}', style: const TextStyle(color: Colors.white70)),
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
    required this.onRemoveFromBucket,
  });

  final List<TeamCard> teams;
  final String workspaceId;
  final void Function(String teamId) onSelect;
  final Future<void> Function(String workspaceId, List<String> orderedTeamIds) onReorder;
  final bool canEdit;
  final Future<void> Function(String workspaceId, String bucketId, String teamId) onRemoveFromBucket;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Master Ranking', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Canonical order for alliance selection.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 12),
            if (!canEdit)
              ...[
                for (var index = 0; index < teams.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TeamTile(team: teams[index], rank: index + 1),
                  ),
              ]
            else
              ...[
                DragTarget<_DraggedTeam>(
                  onAcceptWithDetails: (details) => _handleMasterDrop(
                    payload: details.data,
                    teams: teams,
                    targetIndex: 0,
                    onReorder: onReorder,
                    onRemoveFromBucket: onRemoveFromBucket,
                    workspaceId: workspaceId,
                  ),
                  builder: (context, candidateData, rejectedData) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: 28,
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: candidateData.isNotEmpty ? const Color(0xFF17304F) : const Color(0xFF0B1523),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: candidateData.isNotEmpty ? Colors.lightBlueAccent : Colors.white10),
                      ),
                      child: Text(
                        candidateData.isNotEmpty ? 'Drop to move to top' : 'Drop shortlist items here to return them to master',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    );
                  },
                ),
                for (var index = 0; index < teams.length; index++)
                  _RankingDropRow(
                    key: ValueKey(teams[index].id),
                    team: teams[index],
                    rank: index + 1,
                    canEdit: canEdit,
                    onSelect: () => onSelect(teams[index].id),
                    onDrop: (payload) => _handleMasterDrop(
                      payload: payload,
                      teams: teams,
                      targetIndex: index,
                      onReorder: onReorder,
                      onRemoveFromBucket: onRemoveFromBucket,
                      workspaceId: workspaceId,
                    ),
                  ),
                DragTarget<_DraggedTeam>(
                  onAcceptWithDetails: (details) => _handleMasterDrop(
                    payload: details.data,
                    teams: teams,
                    targetIndex: teams.length,
                    onReorder: onReorder,
                    onRemoveFromBucket: onRemoveFromBucket,
                    workspaceId: workspaceId,
                  ),
                  builder: (context, candidateData, rejectedData) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      height: 28,
                      margin: const EdgeInsets.only(top: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: candidateData.isNotEmpty ? const Color(0xFF17304F) : const Color(0xFF0B1523),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: candidateData.isNotEmpty ? Colors.lightBlueAccent : Colors.white10),
                      ),
                      child: Text(
                        candidateData.isNotEmpty ? 'Drop to place at bottom' : 'Drop here to place at bottom',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    );
                  },
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _BucketsColumn extends StatelessWidget {
  const _BucketsColumn({
    required this.buckets,
    required this.workspace,
    required this.onSelectTeam,
    required this.onMoveToBucket,
    required this.onReorderBucket,
    required this.onMoveBetweenBuckets,
    required this.canEdit,
  });

  final List<StrategyBucket> buckets;
  final WorkspaceState workspace;
  final void Function(String teamId) onSelectTeam;
  final Future<void> Function(String workspaceId, StrategyBucket bucket, String teamId) onMoveToBucket;
  final Future<void> Function(String workspaceId, StrategyBucket bucket, List<String> orderedTeamIds) onReorderBucket;
  final Future<void> Function(String workspaceId, String sourceBucketId, String destinationBucketId, String teamId) onMoveBetweenBuckets;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final teamMap = {for (final team in workspace.teams) team.id: team};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Strategy Buckets', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Shortlists and special-purpose views.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            const SizedBox(height: 12),
            ...buckets.map(
              (bucket) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _BucketCard(
                  bucket: bucket,
                  teams: bucket.teamIds.map((teamId) => teamMap[teamId]).whereType<TeamCard>().toList(growable: false),
                  onSelectTeam: onSelectTeam,
                  onDropTeam: (teamId) => onMoveToBucket(workspace.workspace.id, bucket, teamId),
                  onReorderTeams: (orderedTeamIds) => onReorderBucket(workspace.workspace.id, bucket, orderedTeamIds),
                  onMoveBetweenBuckets: (sourceBucketId, teamId) => onMoveBetweenBuckets(workspace.workspace.id, sourceBucketId, bucket.id, teamId),
                  canEdit: canEdit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.bucket,
    required this.teams,
    required this.onSelectTeam,
    required this.onDropTeam,
    required this.onReorderTeams,
    required this.onMoveBetweenBuckets,
    required this.canEdit,
  });

  final StrategyBucket bucket;
  final List<TeamCard> teams;
  final void Function(String teamId) onSelectTeam;
  final Future<void> Function(String teamId) onDropTeam;
  final Future<void> Function(List<String> orderedTeamIds) onReorderTeams;
  final Future<void> Function(String sourceBucketId, String teamId) onMoveBetweenBuckets;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    Future<void> placeAtIndex(_DraggedTeam payload, int index) async {
      if (payload.sourceBucketId == bucket.id) {
        await onReorderTeams(_reorderIds(teams, payload.teamId, index));
        return;
      }

      if (payload.sourceBucketId == null) {
        await onDropTeam(payload.teamId);
      } else {
        await onMoveBetweenBuckets(payload.sourceBucketId!, payload.teamId);
      }

      final ids = teams.map((team) => team.id).toList(growable: true);
      final insertIndex = index < 0
          ? 0
          : index > ids.length
              ? ids.length
              : index;
      ids.insert(insertIndex, payload.teamId);
      await onReorderTeams(ids);
    }

    final topDrop = _BucketDropZone(
      label: 'Drop here to add to the top',
      onAccept: (payload) => placeAtIndex(payload, 0),
    );
    final bottomDrop = _BucketDropZone(
      label: 'Drop here to add to the bottom',
      onAccept: (payload) => placeAtIndex(payload, teams.length),
    );
    final contentWidgets = <Widget>[
      if (!canEdit) ...[
        if (teams.isEmpty)
          const Text('Drop a team here', style: TextStyle(color: Colors.white54))
        else
          for (final team in teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelectTeam(team.id),
                child: _TeamPill(team: team, sourceBucketId: bucket.id),
              ),
            ),
      ] else ...[
        topDrop,
        const SizedBox(height: 8),
        if (teams.isEmpty)
          const Text('Drop a team here', style: TextStyle(color: Colors.white54))
        else
          for (var index = 0; index < teams.length; index++)
            _SortableBucketTeamRow(
              key: ValueKey(teams[index].id),
              team: teams[index],
              sourceBucketId: bucket.id,
              onSelectTeam: () => onSelectTeam(teams[index].id),
              onDrop: (payload) => placeAtIndex(payload, index),
            ),
        const SizedBox(height: 8),
        bottomDrop,
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D2F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(bucket.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(bucket.type.label, style: const TextStyle(color: Colors.white60)),
            ],
          ),
          if (bucket.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(bucket.comment, style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 10),
          ...contentWidgets,
        ],
      ),
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

class _DraggedTeam {
  const _DraggedTeam({
    required this.teamId,
    this.sourceBucketId,
  });

  final String teamId;
  final String? sourceBucketId;
}

Future<void> _handleMasterDrop({
  required _DraggedTeam payload,
  required List<TeamCard> teams,
  required int targetIndex,
  required Future<void> Function(String workspaceId, List<String> orderedTeamIds) onReorder,
  required Future<void> Function(String workspaceId, String bucketId, String teamId) onRemoveFromBucket,
  required String workspaceId,
}) async {
  final currentIndex = teams.indexWhere((team) => team.id == payload.teamId);
  if (currentIndex == -1) return;
  final next = [...teams];
  final moving = next.removeAt(currentIndex);
  var insertIndex = targetIndex;
  if (insertIndex > currentIndex) {
    insertIndex -= 1;
  }
  if (insertIndex < 0) {
    insertIndex = 0;
  }
  if (insertIndex > next.length) {
    insertIndex = next.length;
  }
  next.insert(insertIndex, moving);
  await onReorder(workspaceId, next.map((team) => team.id).toList(growable: false));
  if (payload.sourceBucketId != null) {
    await onRemoveFromBucket(workspaceId, payload.sourceBucketId!, payload.teamId);
  }
}

List<String> _reorderIds(List<TeamCard> teams, String teamId, int targetIndex) {
  final ids = teams.map((team) => team.id).toList(growable: true);
  final currentIndex = ids.indexOf(teamId);
  if (currentIndex == -1) return ids;
  ids.removeAt(currentIndex);
  var insertIndex = targetIndex;
  if (insertIndex > currentIndex) {
    insertIndex -= 1;
  }
  if (insertIndex < 0) {
    insertIndex = 0;
  }
  if (insertIndex > ids.length) {
    insertIndex = ids.length;
  }
  ids.insert(insertIndex, teamId);
  return ids;
}

class _RankingDropRow extends StatelessWidget {
  const _RankingDropRow({
    super.key,
    required this.team,
    required this.rank,
    required this.canEdit,
    required this.onSelect,
    required this.onDrop,
  });

  final TeamCard team;
  final int rank;
  final bool canEdit;
  final VoidCallback onSelect;
  final ValueChanged<_DraggedTeam> onDrop;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelect,
        child: _TeamTile(team: team, rank: rank),
      ),
    );

    if (!canEdit) {
      return row;
    }

    return DragTarget<_DraggedTeam>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<_DraggedTeam>(
          data: _DraggedTeam(teamId: team.id),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 320, child: _TeamTile(team: team, rank: rank)),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: row),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: candidateData.isNotEmpty ? Colors.lightBlueAccent : Colors.transparent),
            ),
            child: row,
          ),
        );
      },
    );
  }
}

class _SortableBucketTeamRow extends StatelessWidget {
  const _SortableBucketTeamRow({
    super.key,
    required this.team,
    required this.sourceBucketId,
    required this.onSelectTeam,
    required this.onDrop,
  });

  final TeamCard team;
  final String sourceBucketId;
  final VoidCallback onSelectTeam;
  final ValueChanged<_DraggedTeam> onDrop;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DraggedTeam>(
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<_DraggedTeam>(
          data: _DraggedTeam(teamId: team.id, sourceBucketId: sourceBucketId),
          feedback: Material(
            color: Colors.transparent,
            child: _TeamPill(team: team, sourceBucketId: sourceBucketId),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: _TeamPill(team: team, sourceBucketId: sourceBucketId)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: candidateData.isNotEmpty ? Colors.lightBlueAccent : Colors.transparent),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSelectTeam,
              child: _TeamPill(team: team, sourceBucketId: sourceBucketId),
            ),
          ),
        );
      },
    );
  }
}

class _BucketDropZone extends StatelessWidget {
  const _BucketDropZone({
    required this.label,
    required this.onAccept,
  });

  final String label;
  final Future<void> Function(_DraggedTeam payload) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DraggedTeam>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 20,
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty ? const Color(0xFF1C3E5F) : const Color(0xFF0B1523),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: candidateData.isNotEmpty ? Colors.lightBlueAccent : Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        );
      },
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

class _TeamPill extends StatelessWidget {
  const _TeamPill({required this.team, required this.sourceBucketId});

  final TeamCard team;
  final String sourceBucketId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14253C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('${team.teamNumber} ${team.nickname}'),
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
