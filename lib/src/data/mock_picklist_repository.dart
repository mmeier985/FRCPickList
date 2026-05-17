import 'dart:async';
import 'package:uuid/uuid.dart';

import '../models/picklist_models.dart';
import 'picklist_repository.dart';

class MockPickListRepository implements PickListRepository {
  MockPickListRepository._(this._state, this._summaries);

  factory MockPickListRepository.seeded() {
    final now = DateTime.now();
    final workspace = EventWorkspace(
      id: 'workspace-4414',
      name: 'TideScout Demo',
      teamOrgId: 'team-4414',
      createdBy: 'local-lead',
      status: WorkspaceStatus.active,
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now,
    );
    final teams = <TeamCard>[
      _team(4414, 'TideScout', {'auto': 87, 'teleop': 92, 'endgame': 81}, AvailabilityState.available, now),
      _team(254, 'The Cheesy Poofs', {'auto': 95, 'teleop': 90, 'endgame': 88}, AvailabilityState.captainOnly, now),
      _team(1678, 'Citrus Circuits', {'auto': 88, 'teleop': 94, 'endgame': 90}, AvailabilityState.available, now),
      _team(6328, 'Mechanical Advantage', {'auto': 90, 'teleop': 89, 'endgame': 79}, AvailabilityState.defense, now),
      _team(118, 'Robonauts', {'auto': 82, 'teleop': 87, 'endgame': 84}, AvailabilityState.highRisk, now),
      _team(900, 'The Zebracorns', {'auto': 84, 'teleop': 83, 'endgame': 82}, AvailabilityState.available, now),
    ];
    final rankings = List.generate(
      teams.length,
      (index) => RankingEntry(
        teamId: teams[index].id,
        order: index,
        updatedBy: 'local-lead',
        updatedAt: now,
      ),
    );
    final state = WorkspaceState(
      workspace: workspace,
      teams: teams,
      rankings: rankings,
      auditTrail: const [],
      members: const [
        PickListUser(
          id: 'local-lead',
          displayName: 'Local Lead',
          teamOrgId: 'team-4414',
          email: 'lead@example.org',
          role: MemberRole.lead,
        ),
      ],
    );
    final summaries = [
      WorkspaceSummary(workspace: workspace, teamCount: teams.length, updatedAt: now),
    ];
    return MockPickListRepository._(state, summaries);
  }

  static TeamCard _team(
    int number,
    String nickname,
    Map<String, double> metrics,
    AvailabilityState availability,
    DateTime updatedAt,
  ) {
    return TeamCard(
      id: 'team-$number',
      teamNumber: number,
      nickname: nickname,
      importedMetrics: metrics,
      notes: const [],
      tags: const [],
      availability: availability,
      updatedAt: updatedAt,
    );
  }

  WorkspaceState _state;
  List<WorkspaceSummary> _summaries;
  final StreamController<List<WorkspaceSummary>> _summaryController = StreamController.broadcast();
  final StreamController<WorkspaceState?> _workspaceController = StreamController.broadcast();
  final Uuid _uuid = const Uuid();

  void _emit() {
    _summaryController.add(List.unmodifiable(_summaries));
    _workspaceController.add(_state);
  }

  @override
  Future<EventWorkspace> createWorkspace({
    required String teamOrgId,
    required String name,
    required PickListUser createdBy,
  }) async {
    final now = DateTime.now();
    final workspace = EventWorkspace(
      id: 'workspace-${_uuid.v4()}',
      name: name,
      teamOrgId: teamOrgId,
      createdBy: createdBy.id,
      status: WorkspaceStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    _state = WorkspaceState(
      workspace: workspace,
      teams: const [],
      rankings: const [],
      auditTrail: const [],
      members: [createdBy],
    );
    _summaries = [WorkspaceSummary(workspace: workspace, teamCount: 0, updatedAt: now), ..._summaries];
    _emit();
    return workspace;
  }

  @override
  Future<void> importTeams({
    required String workspaceId,
    required List<ImportedTeamRow> rows,
    required PickListUser actor,
  }) async {
    if (_state.workspace.id != workspaceId) return;
    final now = DateTime.now();
    final existing = {for (final team in _state.teams) team.teamNumber: team};
    final teams = <TeamCard>[];
    for (final row in rows) {
      final current = existing[row.teamNumber];
      teams.add(
        TeamCard(
          id: current?.id ?? 'team-${row.teamNumber}',
          teamNumber: row.teamNumber,
          nickname: row.nickname,
          importedMetrics: row.metrics,
          notes: current?.notes ?? const [],
          tags: current?.tags ?? const [],
          availability: current?.availability ?? AvailabilityState.available,
          updatedAt: now,
        ),
      );
    }
    final rankingIds = [
      ..._state.rankings.map((entry) => entry.teamId),
      ...teams.map((team) => team.id).where((id) => !_state.rankings.any((entry) => entry.teamId == id)),
    ];
    _state = WorkspaceState(
      workspace: _state.workspace,
      teams: teams,
      rankings: [
        for (var i = 0; i < rankingIds.length; i++)
          RankingEntry(teamId: rankingIds[i], order: i, updatedBy: actor.id, updatedAt: now),
      ],
      auditTrail: [
        ..._state.auditTrail,
        AuditEntry(
          id: _uuid.v4(),
          actorId: actor.id,
          actorName: actor.displayName,
          action: 'import_teams',
          targetId: workspaceId,
          createdAt: now,
        ),
      ],
      members: _state.members,
    );
    _summaries = _summaries
        .map((summary) => summary.workspace.id == workspaceId
            ? WorkspaceSummary(workspace: summary.workspace, teamCount: teams.length, updatedAt: now)
            : summary)
        .toList();
    _emit();
  }

  @override
  Future<void> createTeam({
    required String workspaceId,
    required ImportedTeamRow row,
    required PickListUser actor,
  }) async {
    if (_state.workspace.id != workspaceId) return;
    final now = DateTime.now();
    final existing = {for (final team in _state.teams) team.teamNumber: team};
    final current = existing[row.teamNumber];
    final team = TeamCard(
      id: current?.id ?? 'team-${row.teamNumber}',
      teamNumber: row.teamNumber,
      nickname: row.nickname,
      importedMetrics: row.metrics,
      notes: current?.notes ?? const [],
      tags: current?.tags ?? const [],
      availability: current?.availability ?? AvailabilityState.available,
      updatedAt: now,
    );
    final teams = [
      ..._state.teams.where((item) => item.id != team.id),
      team,
    ];
    final rankings = [
      ..._state.rankings.where((entry) => entry.teamId != team.id),
      RankingEntry(teamId: team.id, order: _state.rankings.length, updatedBy: actor.id, updatedAt: now),
    ];
    _state = WorkspaceState(
      workspace: _state.workspace,
      teams: teams,
      rankings: rankings,
      auditTrail: [
        ..._state.auditTrail,
        AuditEntry(
          id: _uuid.v4(),
          actorId: actor.id,
          actorName: actor.displayName,
          action: 'create_team',
          targetId: team.id,
          createdAt: now,
        ),
      ],
      members: _state.members,
    );
    _summaries = _summaries
        .map((summary) => summary.workspace.id == workspaceId
            ? WorkspaceSummary(workspace: summary.workspace, teamCount: teams.length, updatedAt: now)
            : summary)
        .toList();
    _emit();
  }

  @override
  Future<void> setRankingOrder({
    required String workspaceId,
    required List<String> orderedTeamIds,
    required PickListUser actor,
  }) async {
    if (_state.workspace.id != workspaceId) return;
    final now = DateTime.now();
    _state = WorkspaceState(
      workspace: _state.workspace,
      teams: _state.teams,
      rankings: [
        for (var i = 0; i < orderedTeamIds.length; i++)
          RankingEntry(teamId: orderedTeamIds[i], order: i, updatedBy: actor.id, updatedAt: now),
      ],
      auditTrail: [
        ..._state.auditTrail,
        AuditEntry(
          id: _uuid.v4(),
          actorId: actor.id,
          actorName: actor.displayName,
          action: 'reorder_master',
          targetId: workspaceId,
          createdAt: now,
        ),
      ],
      members: _state.members,
    );
    _emit();
  }

  @override
  Future<void> addNote({
    required String workspaceId,
    required String teamId,
    required ScoutNote note,
    required PickListUser actor,
  }) async {
    if (_state.workspace.id != workspaceId) return;
    final now = DateTime.now();
    final teams = _state.teams.map((team) {
      if (team.id != teamId) return team;
      return TeamCard(
        id: team.id,
        teamNumber: team.teamNumber,
        nickname: team.nickname,
        importedMetrics: team.importedMetrics,
        notes: [...team.notes, note],
        tags: team.tags,
        availability: team.availability,
        updatedAt: now,
      );
    }).toList();
    _state = WorkspaceState(
      workspace: _state.workspace,
      teams: teams,
      rankings: _state.rankings,
      auditTrail: [
        ..._state.auditTrail,
        AuditEntry(
          id: _uuid.v4(),
          actorId: actor.id,
          actorName: actor.displayName,
          action: 'add_note',
          targetId: teamId,
          createdAt: now,
        ),
      ],
      members: _state.members,
    );
    _emit();
  }

  @override
  Future<void> updateTeamAvailability({
    required String workspaceId,
    required String teamId,
    required AvailabilityState availability,
    required PickListUser actor,
  }) async {
    if (_state.workspace.id != workspaceId) return;
    final now = DateTime.now();
    final teams = _state.teams.map((team) {
      if (team.id != teamId) return team;
      return TeamCard(
        id: team.id,
        teamNumber: team.teamNumber,
        nickname: team.nickname,
        importedMetrics: team.importedMetrics,
        notes: team.notes,
        tags: team.tags,
        availability: availability,
        updatedAt: now,
      );
    }).toList();
    _state = WorkspaceState(
      workspace: _state.workspace,
      teams: teams,
      rankings: _state.rankings,
      auditTrail: [
        ..._state.auditTrail,
        AuditEntry(
          id: _uuid.v4(),
          actorId: actor.id,
          actorName: actor.displayName,
          action: 'set_availability',
          targetId: teamId,
          createdAt: now,
        ),
      ],
      members: _state.members,
    );
    _emit();
  }

  @override
  Future<void> addMember({
    required String workspaceId,
    required PickListUser member,
    required PickListUser actor,
  }) async {
    if (_state.workspace.id != workspaceId) return;
    _state = WorkspaceState(
      workspace: _state.workspace,
      teams: _state.teams,
      rankings: _state.rankings,
      auditTrail: [
        ..._state.auditTrail,
        AuditEntry(
          id: _uuid.v4(),
          actorId: actor.id,
          actorName: actor.displayName,
          action: 'add_member',
          targetId: member.id,
          createdAt: DateTime.now(),
        ),
      ],
      members: [..._state.members, member],
    );
    _emit();
  }

  @override
  Stream<List<WorkspaceSummary>> watchWorkspaceSummaries(String teamOrgId) async* {
    yield _summaries.where((summary) => summary.workspace.teamOrgId == teamOrgId).toList(growable: false);
    yield* _summaryController.stream.map((items) => items.where((summary) => summary.workspace.teamOrgId == teamOrgId).toList(growable: false));
  }

  @override
  Stream<WorkspaceState?> watchWorkspace(String workspaceId) async* {
    if (_state.workspace.id == workspaceId) yield _state;
    yield* _workspaceController.stream.map((state) => state?.workspace.id == workspaceId ? state : null);
  }
}
