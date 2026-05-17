import 'package:flutter/foundation.dart';

enum MemberRole { scout, strategist, lead }
enum WorkspaceStatus { draft, active, archived }
enum SyncState { idle, syncing, saved, failed }
enum AvailabilityState { available, captainOnly, avoid, defense, highRisk }
enum BucketType { captain, firstPick, secondPick, backup, doNotPick, custom }

extension MemberRoleLabel on MemberRole {
  String get label => switch (this) {
        MemberRole.scout => 'Scout',
        MemberRole.strategist => 'Strategist',
        MemberRole.lead => 'Lead',
      };
}

extension AvailabilityStateLabel on AvailabilityState {
  String get label => switch (this) {
        AvailabilityState.available => 'Available',
        AvailabilityState.captainOnly => 'Captain only',
        AvailabilityState.avoid => 'Avoid',
        AvailabilityState.defense => 'Defense',
        AvailabilityState.highRisk => 'High risk',
      };
}

extension BucketTypeLabel on BucketType {
  String get label => switch (this) {
        BucketType.captain => 'Captain',
        BucketType.firstPick => 'First pick',
        BucketType.secondPick => 'Second pick',
        BucketType.backup => 'Backup',
        BucketType.doNotPick => 'Do not pick',
        BucketType.custom => 'Custom',
      };
}

@immutable
class PickListUser {
  const PickListUser({
    required this.id,
    required this.displayName,
    required this.teamOrgId,
    required this.email,
    required this.role,
  });

  final String id;
  final String displayName;
  final String teamOrgId;
  final String email;
  final MemberRole role;
}

@immutable
class EventWorkspace {
  const EventWorkspace({
    required this.id,
    required this.name,
    required this.teamOrgId,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String teamOrgId;
  final String createdBy;
  final WorkspaceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
class TeamCard {
  const TeamCard({
    required this.id,
    required this.teamNumber,
    required this.nickname,
    required this.importedMetrics,
    required this.notes,
    required this.tags,
    required this.availability,
    required this.updatedAt,
  });

  final String id;
  final int teamNumber;
  final String nickname;
  final Map<String, double> importedMetrics;
  final List<ScoutNote> notes;
  final List<String> tags;
  final AvailabilityState availability;
  final DateTime updatedAt;
}

@immutable
class ScoutNote {
  const ScoutNote({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
}

@immutable
class RankingEntry {
  const RankingEntry({
    required this.teamId,
    required this.order,
    required this.updatedBy,
    required this.updatedAt,
  });

  final String teamId;
  final int order;
  final String updatedBy;
  final DateTime updatedAt;
}

@immutable
class StrategyBucket {
  const StrategyBucket({
    required this.id,
    required this.name,
    required this.type,
    required this.teamIds,
    required this.comment,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final BucketType type;
  final List<String> teamIds;
  final String comment;
  final DateTime updatedAt;
}

@immutable
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.targetId,
    required this.createdAt,
  });

  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String targetId;
  final DateTime createdAt;
}

@immutable
class WorkspaceState {
  const WorkspaceState({
    required this.workspace,
    required this.teams,
    required this.rankings,
    required this.buckets,
    required this.auditTrail,
    required this.members,
  });

  final EventWorkspace workspace;
  final List<TeamCard> teams;
  final List<RankingEntry> rankings;
  final List<StrategyBucket> buckets;
  final List<AuditEntry> auditTrail;
  final List<PickListUser> members;

  TeamCard? teamById(String id) {
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  RankingEntry? rankingByTeamId(String teamId) {
    for (final entry in rankings) {
      if (entry.teamId == teamId) return entry;
    }
    return null;
  }

  StrategyBucket? bucketById(String id) {
    for (final bucket in buckets) {
      if (bucket.id == id) return bucket;
    }
    return null;
  }
}

@immutable
class WorkspaceSummary {
  const WorkspaceSummary({
    required this.workspace,
    required this.teamCount,
    required this.updatedAt,
  });

  final EventWorkspace workspace;
  final int teamCount;
  final DateTime updatedAt;
}
