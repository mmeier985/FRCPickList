import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:picklist_app/src/data/picklist_repository.dart';
import 'package:picklist_app/src/models/picklist_models.dart';
import 'package:picklist_app/src/services/auth_service.dart';
import 'package:picklist_app/src/state/picklist_controller.dart';

void main() {
  test('scout cannot edit board while strategist can', () async {
    final repository = FakePickListRepository();
    final controller = PickListController(
      repository: repository,
      authService: FakeAuthService(
        const PickListUser(
          id: 'user-1',
          displayName: 'Scout',
          teamOrgId: 'team-4414',
          email: 'scout@example.org',
          role: MemberRole.scout,
        ),
      ),
    );

    await controller.initialize();
    controller.debugSetSelectedWorkspace(_workspaceWithMember(
      userId: 'user-1',
      role: MemberRole.scout,
    ));

    await controller.reorderMasterList('workspace-1', ['team-1']);
    expect(repository.reorderCalls, isEmpty);

    controller.dispose();

    final strategistController = PickListController(
      repository: repository,
      authService: FakeAuthService(
        const PickListUser(
          id: 'user-1',
          displayName: 'Strategist',
          teamOrgId: 'team-4414',
          email: 'strategist@example.org',
          role: MemberRole.strategist,
        ),
      ),
    );
    await strategistController.initialize();
    strategistController.debugSetSelectedWorkspace(_workspaceWithMember(
      userId: 'user-1',
      role: MemberRole.strategist,
    ));

    await strategistController.reorderMasterList('workspace-1', ['team-1']);
    expect(repository.reorderCalls, hasLength(1));
  });

  test('lead can manage workspace but scout cannot', () async {
    final repository = FakePickListRepository();
    final leadController = PickListController(
      repository: repository,
      authService: FakeAuthService(
        const PickListUser(
          id: 'user-2',
          displayName: 'Lead',
          teamOrgId: 'team-4414',
          email: 'lead@example.org',
          role: MemberRole.lead,
        ),
      ),
    );
    await leadController.initialize();
    leadController.debugSetSelectedWorkspace(_workspaceWithMember(userId: 'user-2', role: MemberRole.lead));
    await leadController.addMember(
      'workspace-1',
      const PickListUser(
        id: 'member-1',
        displayName: 'New Member',
        teamOrgId: 'team-4414',
        email: 'member@example.org',
        role: MemberRole.scout,
      ),
    );
    expect(repository.addMemberCalls, hasLength(1));

    final scoutController = PickListController(
      repository: repository,
      authService: FakeAuthService(
        const PickListUser(
          id: 'user-3',
          displayName: 'Scout',
          teamOrgId: 'team-4414',
          email: 'scout@example.org',
          role: MemberRole.scout,
        ),
      ),
    );
    await scoutController.initialize();
    scoutController.debugSetSelectedWorkspace(_workspaceWithMember(userId: 'user-3', role: MemberRole.scout));
    await scoutController.addMember(
      'workspace-1',
      const PickListUser(
        id: 'member-2',
        displayName: 'Blocked Member',
        teamOrgId: 'team-4414',
        email: 'blocked@example.org',
        role: MemberRole.scout,
      ),
    );
    expect(repository.addMemberCalls, hasLength(1));
  });
}

WorkspaceState _workspaceWithMember({required String userId, required MemberRole role}) {
    final workspace = EventWorkspace(
      id: 'workspace-1',
      name: 'Test',
      teamOrgId: 'team-4414',
      createdBy: 'user-1',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
    return WorkspaceState(
      workspace: workspace,
      teams: const [],
      rankings: const [],
      auditTrail: const [],
      members: [
      PickListUser(
        id: userId,
        displayName: 'Member',
        teamOrgId: 'team-4414',
        email: 'member@example.org',
        role: role,
      ),
    ],
  );
}

class FakeAuthService implements AuthService {
  FakeAuthService(this._user);

  PickListUser? _user;

  @override
  PickListUser? currentUser() => _user;

  @override
  Stream<PickListUser?> watchUser() async* {
    yield _user;
  }

  @override
  Future<void> signIn(AuthCredentials credentials) async {
    _user = PickListUser(
      id: 'signed-in-${credentials.email}',
      displayName: credentials.displayName,
      teamOrgId: credentials.teamOrgId,
      email: credentials.email,
      role: MemberRole.scout,
    );
  }

  @override
  Future<void> saveProfile(PickListUser user) async {
    _user = user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

class FakePickListRepository implements PickListRepository {
  final _summaryController = StreamController<List<WorkspaceSummary>>.broadcast();
  final _workspaceController = StreamController<WorkspaceState?>.broadcast();
  final reorderCalls = <List<String>>[];
  final addMemberCalls = <PickListUser>[];

  void pushWorkspace(WorkspaceState state) {
    _workspaceController.add(state);
    _summaryController.add([
      WorkspaceSummary(workspace: state.workspace, teamCount: state.teams.length, updatedAt: state.workspace.updatedAt),
    ]);
  }

  @override
  Future<EventWorkspace> createWorkspace({
    required String teamOrgId,
    required String name,
    required PickListUser createdBy,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> addMember({
    required String workspaceId,
    required PickListUser member,
    required PickListUser actor,
  }) async {
    addMemberCalls.add(member);
  }

  @override
  Future<void> addNote({
    required String workspaceId,
    required String teamId,
    required ScoutNote note,
    required PickListUser actor,
  }) async {}

  @override
  Future<void> importTeams({
    required String workspaceId,
    required List<ImportedTeamRow> rows,
    required PickListUser actor,
  }) async {}

  @override
  Future<void> createTeam({
    required String workspaceId,
    required ImportedTeamRow row,
    required PickListUser actor,
  }) async {}

  @override
  Future<void> setRankingOrder({
    required String workspaceId,
    required List<String> orderedTeamIds,
    required PickListUser actor,
  }) async {
    reorderCalls.add(orderedTeamIds);
  }

  @override
  Future<void> updateTeamAvailability({
    required String workspaceId,
    required String teamId,
    required AvailabilityState availability,
    required PickListUser actor,
  }) async {}

  @override
  Stream<List<WorkspaceSummary>> watchWorkspaceSummaries(String teamOrgId) async* {
    yield* _summaryController.stream;
  }

  @override
  Stream<WorkspaceState?> watchWorkspace(String workspaceId) async* {
    yield* _workspaceController.stream;
  }
}
