import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/picklist_models.dart';
import 'picklist_repository.dart';

class FirebasePickListRepository implements PickListRepository {
  FirebasePickListRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _workspaces => _firestore.collection('workspaces');

  @override
  Future<EventWorkspace> createWorkspace({
    required String teamOrgId,
    required String name,
    required PickListUser createdBy,
  }) async {
    final now = DateTime.now();
    final workspace = EventWorkspace(
      id: _workspaces.doc().id,
      name: name,
      teamOrgId: teamOrgId,
      createdBy: createdBy.id,
      status: WorkspaceStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
    final state = WorkspaceState(
      workspace: workspace,
      teams: const [],
      rankings: const [],
      buckets: const [],
      auditTrail: [_audit(createdBy, 'create_workspace', workspace.id, now)],
      members: [createdBy],
    );
    await _doc(workspace.id).set(_stateToMap(state));
    return workspace;
  }

  @override
  Future<void> addMember({
    required String workspaceId,
    required PickListUser member,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final members = [...state.members.where((item) => item.id != member.id), member];
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: state.teams,
        rankings: state.rankings,
        buckets: state.buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'add_member', member.id, now)],
        members: members,
      );
    });
  }

  @override
  Future<void> addNote({
    required String workspaceId,
    required String teamId,
    required ScoutNote note,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final teams = state.teams.map((team) {
        if (team.id != teamId) return team;
        return team.copyWith(notes: [...team.notes, note], updatedAt: now);
      }).toList(growable: false);
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: teams,
        rankings: state.rankings,
        buckets: state.buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'add_note', teamId, now)],
        members: state.members,
      );
    });
  }

  @override
  Future<void> importTeams({
    required String workspaceId,
    required List<ImportedTeamRow> rows,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final existingByNumber = {for (final team in state.teams) team.teamNumber: team};
      final teams = <TeamCard>[];
      for (final row in rows) {
        final current = existingByNumber[row.teamNumber];
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
      final nextRankingIds = [
        ...state.rankings.map((entry) => entry.teamId),
        ...teams.map((team) => team.id).where((id) => !state.rankings.any((entry) => entry.teamId == id)),
      ];
      final rankings = [
        for (var index = 0; index < nextRankingIds.length; index++)
          RankingEntry(teamId: nextRankingIds[index], order: index, updatedBy: actor.id, updatedAt: now),
      ];
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: teams,
        rankings: rankings,
        buckets: state.buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'import_teams', workspaceId, now)],
        members: state.members,
      );
    });
  }

  @override
  Stream<List<WorkspaceSummary>> watchWorkspaceSummaries(String teamOrgId) {
    return _workspaces.where('workspace.teamOrgId', isEqualTo: teamOrgId).snapshots().map(
          (snap) => snap.docs.map(_summaryFromDoc).toList(growable: false),
        );
  }

  @override
  Stream<WorkspaceState?> watchWorkspace(String workspaceId) {
    return _doc(workspaceId).snapshots().map((doc) => doc.data() == null ? null : _stateFromDoc(doc));
  }

  @override
  Future<void> setRankingOrder({
    required String workspaceId,
    required List<String> orderedTeamIds,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final rankings = [
        for (var index = 0; index < orderedTeamIds.length; index++)
          RankingEntry(teamId: orderedTeamIds[index], order: index, updatedBy: actor.id, updatedAt: now),
      ];
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: state.teams,
        rankings: rankings,
        buckets: state.buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'reorder_master', workspaceId, now)],
        members: state.members,
      );
    });
  }

  @override
  Future<void> upsertBucket({
    required String workspaceId,
    required StrategyBucket bucket,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final buckets = [
        ...state.buckets.where((item) => item.id != bucket.id),
        bucket.copyWith(updatedAt: now),
      ];
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: state.teams,
        rankings: state.rankings,
        buckets: buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'upsert_bucket', bucket.id, now)],
        members: state.members,
      );
    });
  }

  @override
  Future<void> removeTeamFromBucket({
    required String workspaceId,
    required String bucketId,
    required String teamId,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final buckets = state.buckets.map((bucket) {
        if (bucket.id != bucketId) return bucket;
        return bucket.copyWith(
          teamIds: bucket.teamIds.where((id) => id != teamId).toList(growable: false),
          updatedAt: now,
        );
      }).toList(growable: false);
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: state.teams,
        rankings: state.rankings,
        buckets: buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'remove_from_bucket', bucketId, now)],
        members: state.members,
      );
    });
  }

  @override
  Future<void> moveTeamBetweenBuckets({
    required String workspaceId,
    required String sourceBucketId,
    required String destinationBucketId,
    required String teamId,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final buckets = state.buckets.map((bucket) {
        if (bucket.id == sourceBucketId) {
          return bucket.copyWith(
            teamIds: bucket.teamIds.where((id) => id != teamId).toList(growable: false),
            updatedAt: now,
          );
        }
        if (bucket.id == destinationBucketId) {
          return bucket.copyWith(
            teamIds: [...bucket.teamIds.where((id) => id != teamId), teamId],
            updatedAt: now,
          );
        }
        return bucket;
      }).toList(growable: false);
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: state.teams,
        rankings: state.rankings,
        buckets: buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'move_between_buckets', teamId, now)],
        members: state.members,
      );
    });
  }

  @override
  Future<void> updateTeamAvailability({
    required String workspaceId,
    required String teamId,
    required AvailabilityState availability,
    required PickListUser actor,
  }) async {
    await _updateWorkspace(workspaceId, actor, (state, now) {
      final teams = state.teams.map((team) {
        if (team.id != teamId) return team;
        return team.copyWith(availability: availability, updatedAt: now);
      }).toList(growable: false);
      return WorkspaceState(
        workspace: state.workspace.copyWith(updatedAt: now),
        teams: teams,
        rankings: state.rankings,
        buckets: state.buckets,
        auditTrail: [...state.auditTrail, _audit(actor, 'set_availability', teamId, now)],
        members: state.members,
      );
    });
  }

  DocumentReference<Map<String, dynamic>> _doc(String workspaceId) => _workspaces.doc(workspaceId);

  Future<void> _updateWorkspace(
    String workspaceId,
    PickListUser actor,
    WorkspaceState Function(WorkspaceState state, DateTime now) transform,
  ) async {
    final snapshot = await _doc(workspaceId).get();
    final existing = snapshot.data();
    if (existing == null) {
      throw StateError('Workspace $workspaceId does not exist.');
    }
    final current = _stateFromData(existing);
    final now = DateTime.now();
    final next = transform(current, now);
    await _doc(workspaceId).set(_stateToMap(next));
  }

  WorkspaceSummary _summaryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final state = _stateFromData(doc.data());
    return WorkspaceSummary(
      workspace: state.workspace,
      teamCount: state.teams.length,
      updatedAt: state.workspace.updatedAt,
    );
  }

  WorkspaceState _stateFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Workspace ${doc.id} does not exist.');
    }
    return _stateFromData(data);
  }

  WorkspaceState _stateFromData(Map<String, dynamic> data) {
    final workspaceData = Map<String, dynamic>.from(data['workspace'] as Map);
    final workspace = EventWorkspace(
      id: workspaceData['id'] as String,
      name: workspaceData['name'] as String,
      teamOrgId: workspaceData['teamOrgId'] as String,
      createdBy: workspaceData['createdBy'] as String,
      status: _workspaceStatusFromName(workspaceData['status'] as String),
      createdAt: _readDateTime(workspaceData['createdAt']),
      updatedAt: _readDateTime(workspaceData['updatedAt']),
    );

    final teams = (data['teams'] as List<dynamic>? ?? const [])
        .map((item) => TeamCard(
              id: item['id'] as String,
              teamNumber: (item['teamNumber'] as num).toInt(),
              nickname: item['nickname'] as String,
              importedMetrics: _doubleMap(item['importedMetrics'] as Map? ?? const {}),
              notes: (item['notes'] as List<dynamic>? ?? const [])
                  .map((note) => _noteFromMap(Map<String, dynamic>.from(note as Map)))
                  .toList(growable: false),
              tags: List<String>.from(item['tags'] as List<dynamic>? ?? const []),
              availability: _availabilityFromName(item['availability'] as String),
              updatedAt: _readDateTime(item['updatedAt']),
            ))
        .toList(growable: false);

    final rankings = (data['rankings'] as List<dynamic>? ?? const [])
        .map((item) => RankingEntry(
              teamId: item['teamId'] as String,
              order: (item['order'] as num).toInt(),
              updatedBy: item['updatedBy'] as String,
              updatedAt: _readDateTime(item['updatedAt']),
            ))
        .toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));

    final buckets = (data['buckets'] as List<dynamic>? ?? const [])
        .map((item) => StrategyBucket(
              id: item['id'] as String,
              name: item['name'] as String,
              type: _bucketTypeFromName(item['type'] as String),
              teamIds: List<String>.from(item['teamIds'] as List<dynamic>? ?? const []),
              comment: item['comment'] as String? ?? '',
              updatedAt: _readDateTime(item['updatedAt']),
            ))
        .toList(growable: false);

    final auditTrail = (data['auditTrail'] as List<dynamic>? ?? const [])
        .map((item) => AuditEntry(
              id: item['id'] as String,
              actorId: item['actorId'] as String,
              actorName: item['actorName'] as String,
              action: item['action'] as String,
              targetId: item['targetId'] as String,
              createdAt: _readDateTime(item['createdAt']),
            ))
        .toList(growable: false);

    final members = (data['members'] as List<dynamic>? ?? const [])
        .map((item) => PickListUser(
              id: item['id'] as String,
              displayName: item['displayName'] as String,
              teamOrgId: item['teamOrgId'] as String,
              email: item['email'] as String,
              role: _memberRoleFromName(item['role'] as String),
            ))
        .toList(growable: false);

    return WorkspaceState(
      workspace: workspace,
      teams: teams,
      rankings: rankings,
      buckets: buckets,
      auditTrail: auditTrail,
      members: members,
    );
  }

  Map<String, dynamic> _stateToMap(WorkspaceState state) {
    return {
      'workspace': {
        'id': state.workspace.id,
        'name': state.workspace.name,
        'teamOrgId': state.workspace.teamOrgId,
        'createdBy': state.workspace.createdBy,
        'status': state.workspace.status.name,
        'createdAt': Timestamp.fromDate(state.workspace.createdAt),
        'updatedAt': Timestamp.fromDate(state.workspace.updatedAt),
      },
      'teams': state.teams
          .map(
            (team) => {
              'id': team.id,
              'teamNumber': team.teamNumber,
              'nickname': team.nickname,
              'importedMetrics': team.importedMetrics,
              'notes': team.notes.map(_noteToMap).toList(growable: false),
              'tags': team.tags,
              'availability': team.availability.name,
              'updatedAt': Timestamp.fromDate(team.updatedAt),
            },
          )
          .toList(growable: false),
      'rankings': state.rankings
          .map(
            (ranking) => {
              'teamId': ranking.teamId,
              'order': ranking.order,
              'updatedBy': ranking.updatedBy,
              'updatedAt': Timestamp.fromDate(ranking.updatedAt),
            },
          )
          .toList(growable: false),
      'buckets': state.buckets
          .map(
            (bucket) => {
              'id': bucket.id,
              'name': bucket.name,
              'type': bucket.type.name,
              'teamIds': bucket.teamIds,
              'comment': bucket.comment,
              'updatedAt': Timestamp.fromDate(bucket.updatedAt),
            },
          )
          .toList(growable: false),
      'auditTrail': state.auditTrail
          .map(
            (entry) => {
              'id': entry.id,
              'actorId': entry.actorId,
              'actorName': entry.actorName,
              'action': entry.action,
              'targetId': entry.targetId,
              'createdAt': Timestamp.fromDate(entry.createdAt),
            },
          )
          .toList(growable: false),
      'members': state.members
          .map(
            (member) => {
              'id': member.id,
              'displayName': member.displayName,
              'teamOrgId': member.teamOrgId,
              'email': member.email,
              'role': member.role.name,
            },
          )
          .toList(growable: false),
      'memberIds': state.members.map((member) => member.id).toList(growable: false),
    };
  }

  Map<String, double> _doubleMap(Map<dynamic, dynamic> values) {
    return {
      for (final entry in values.entries)
        entry.key.toString(): (entry.value as num).toDouble(),
    };
  }

  Map<String, dynamic> _noteToMap(ScoutNote note) {
    return {
      'id': note.id,
      'authorId': note.authorId,
      'authorName': note.authorName,
      'body': note.body,
      'createdAt': Timestamp.fromDate(note.createdAt),
    };
  }

  ScoutNote _noteFromMap(Map<String, dynamic> map) {
    return ScoutNote(
      id: map['id'] as String,
      authorId: map['authorId'] as String,
      authorName: map['authorName'] as String,
      body: map['body'] as String,
      createdAt: _readDateTime(map['createdAt']),
    );
  }

  AuditEntry _audit(PickListUser actor, String action, String targetId, DateTime createdAt) {
    return AuditEntry(
      id: _firestore.collection('_').doc().id,
      actorId: actor.id,
      actorName: actor.displayName,
      action: action,
      targetId: targetId,
      createdAt: createdAt,
    );
  }

  DateTime _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    throw StateError('Unsupported date value: $value');
  }

  WorkspaceStatus _workspaceStatusFromName(String name) {
    return WorkspaceStatus.values.firstWhere((value) => value.name == name);
  }

  AvailabilityState _availabilityFromName(String name) {
    return AvailabilityState.values.firstWhere((value) => value.name == name);
  }

  BucketType _bucketTypeFromName(String name) {
    return BucketType.values.firstWhere((value) => value.name == name);
  }

  MemberRole _memberRoleFromName(String name) {
    return MemberRole.values.firstWhere((value) => value.name == name);
  }
}

extension on EventWorkspace {
  EventWorkspace copyWith({
    String? id,
    String? name,
    String? teamOrgId,
    String? createdBy,
    WorkspaceStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventWorkspace(
      id: id ?? this.id,
      name: name ?? this.name,
      teamOrgId: teamOrgId ?? this.teamOrgId,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension on TeamCard {
  TeamCard copyWith({
    String? id,
    int? teamNumber,
    String? nickname,
    Map<String, double>? importedMetrics,
    List<ScoutNote>? notes,
    List<String>? tags,
    AvailabilityState? availability,
    DateTime? updatedAt,
  }) {
    return TeamCard(
      id: id ?? this.id,
      teamNumber: teamNumber ?? this.teamNumber,
      nickname: nickname ?? this.nickname,
      importedMetrics: importedMetrics ?? this.importedMetrics,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      availability: availability ?? this.availability,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension on StrategyBucket {
  StrategyBucket copyWith({
    String? id,
    String? name,
    BucketType? type,
    List<String>? teamIds,
    String? comment,
    DateTime? updatedAt,
  }) {
    return StrategyBucket(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      teamIds: teamIds ?? this.teamIds,
      comment: comment ?? this.comment,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
