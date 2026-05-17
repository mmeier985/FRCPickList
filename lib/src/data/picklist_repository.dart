import '../models/picklist_models.dart';

abstract class PickListRepository {
  Stream<List<WorkspaceSummary>> watchWorkspaceSummaries(String teamOrgId);
  Stream<WorkspaceState?> watchWorkspace(String workspaceId);
  Future<EventWorkspace> createWorkspace({
    required String teamOrgId,
    required String name,
    required PickListUser createdBy,
  });
  Future<void> importTeams({
    required String workspaceId,
    required List<ImportedTeamRow> rows,
    required PickListUser actor,
  });
  Future<void> setRankingOrder({
    required String workspaceId,
    required List<String> orderedTeamIds,
    required PickListUser actor,
  });
  Future<void> upsertBucket({
    required String workspaceId,
    required StrategyBucket bucket,
    required PickListUser actor,
  });
  Future<void> removeTeamFromBucket({
    required String workspaceId,
    required String bucketId,
    required String teamId,
    required PickListUser actor,
  });
  Future<void> moveTeamBetweenBuckets({
    required String workspaceId,
    required String sourceBucketId,
    required String destinationBucketId,
    required String teamId,
    required PickListUser actor,
  });
  Future<void> addNote({
    required String workspaceId,
    required String teamId,
    required ScoutNote note,
    required PickListUser actor,
  });
  Future<void> updateTeamAvailability({
    required String workspaceId,
    required String teamId,
    required AvailabilityState availability,
    required PickListUser actor,
  });
  Future<void> addMember({
    required String workspaceId,
    required PickListUser member,
    required PickListUser actor,
  });
}

class ImportedTeamRow {
  ImportedTeamRow({
    required this.teamNumber,
    required this.nickname,
    required this.metrics,
  });

  final int teamNumber;
  final String nickname;
  final Map<String, double> metrics;
}
