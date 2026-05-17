import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/import_parser.dart';
import '../data/picklist_repository.dart';
import '../models/picklist_models.dart';
import '../services/auth_service.dart';

class PickListController extends ChangeNotifier {
  PickListController({
    required this.repository,
    required this.authService,
  });

  final PickListRepository repository;
  final AuthService authService;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<WorkspaceSummary>>? _summarySub;
  StreamSubscription<WorkspaceState?>? _workspaceSub;
  StreamSubscription<PickListUser?>? _userSub;

  List<WorkspaceSummary> _summaries = const [];
  WorkspaceState? _selectedWorkspace;
  PickListUser? _user;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _pendingImportMessage;
  ImportPreview? _pendingImportPreview;

  List<WorkspaceSummary> get summaries => _summaries;
  WorkspaceState? get selectedWorkspace => _selectedWorkspace;
  PickListUser? get user => _user ?? authService.currentUser();
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  String? get pendingImportMessage => _pendingImportMessage;
  ImportPreview? get pendingImportPreview => _pendingImportPreview;

  bool get canEditBoard {
    final user = this.user;
    final workspace = _selectedWorkspace;
    return user != null && workspace != null && _isWorkspaceMember(workspace, user) && user.role != MemberRole.scout;
  }

  bool get canManageWorkspace {
    final user = this.user;
    final workspace = _selectedWorkspace;
    return user != null && workspace != null && _isWorkspaceMember(workspace, user) && user.role == MemberRole.lead;
  }

  bool canViewWorkspace(WorkspaceState workspace) {
    final user = this.user;
    return user != null && _isWorkspaceMember(workspace, user);
  }

  Future<void> initialize() async {
    _user = authService.currentUser();
    _userSub?.cancel();
    _userSub = authService.watchUser().listen((user) {
      _user = user;
      _subscribeToSummaries();
      notifyListeners();
    });
    _subscribeToSummaries();
    notifyListeners();
  }

  @override
  void dispose() {
    _summarySub?.cancel();
    _workspaceSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> createWorkspace(String name) async {
    final user = this.user;
    if (user == null) return;
    _setBusy(true);
    try {
      final workspace = await repository.createWorkspace(
        teamOrgId: user.teamOrgId,
        name: name,
        createdBy: user,
      );
      await selectWorkspace(workspace.id);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> selectWorkspace(String workspaceId) async {
    _workspaceSub?.cancel();
    _workspaceSub = repository.watchWorkspace(workspaceId).listen(
      (state) {
        if (state != null && !canViewWorkspace(state)) {
          _error = 'You do not have access to this workspace.';
          _selectedWorkspace = null;
          notifyListeners();
          return;
        }
        _selectedWorkspace = state;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        _error = error.toString();
        notifyListeners();
      },
    );
    notifyListeners();
  }

  Future<void> signOut() => authService.signOut();

  Future<void> saveMyProfile({
    required String displayName,
    required String teamOrgId,
    required MemberRole role,
  }) async {
    final user = this.user;
    if (user == null) return;
    await authService.saveProfile(
      PickListUser(
        id: user.id,
        displayName: displayName,
        teamOrgId: teamOrgId,
        email: user.email,
        role: role,
      ),
    );
  }

  void closeWorkspace() {
    _workspaceSub?.cancel();
    _workspaceSub = null;
    _selectedWorkspace = null;
    notifyListeners();
  }

  bool _isWorkspaceMember(WorkspaceState workspace, PickListUser user) {
    return workspace.members.any((member) => member.id == user.id) || workspace.workspace.teamOrgId == user.teamOrgId;
  }

  void _subscribeToSummaries() {
    final user = this.user;
    _summarySub?.cancel();
    if (user == null || user.teamOrgId.isEmpty) {
      _summaries = const [];
      _loading = false;
      notifyListeners();
      return;
    }
    _summarySub = repository.watchWorkspaceSummaries(user.teamOrgId).listen(
      (items) {
        _summaries = items;
        _loading = false;
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        _error = error.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<ImportPreview?> pickImportPreview() async {
    final user = this.user;
    if (user == null) return null;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('Selected file has no bytes.');
    }
    final content = utf8.decode(bytes);
    final preview = file.name.toLowerCase().endsWith('.json')
        ? previewJsonImport(file.name, content)
        : previewCsvImport(file.name, content);
    _pendingImportPreview = preview;
    notifyListeners();
    return preview;
  }

  Future<void> importWorkspaceFile(String workspaceId) async {
    final preview = await pickImportPreview();
    if (preview == null) return;
    await importWorkspacePreview(workspaceId, preview);
  }

  Future<void> importWorkspacePreview(String workspaceId, ImportPreview preview) async {
    final user = this.user;
    if (user == null) return;
    _pendingImportMessage = 'Imported ${preview.rows.length} teams from ${preview.fileName}';
    notifyListeners();
    await repository.importTeams(
      workspaceId: workspaceId,
      rows: preview.rows,
      actor: user,
    );
    _pendingImportMessage = null;
    _pendingImportPreview = null;
    notifyListeners();
  }

  void clearImportPreview() {
    _pendingImportPreview = null;
    notifyListeners();
  }

  Future<void> reorderMasterList(String workspaceId, List<String> orderedTeamIds) async {
    final user = this.user;
    if (user == null || !canEditBoard) return;
    await repository.setRankingOrder(
      workspaceId: workspaceId,
      orderedTeamIds: orderedTeamIds,
      actor: user,
    );
  }

  Future<void> moveTeamToBucket(String workspaceId, StrategyBucket bucket, String teamId) async {
    final user = this.user;
    if (user == null || !canEditBoard) return;
    final nextTeamIds = [
      ...bucket.teamIds.where((id) => id != teamId),
      teamId,
    ];
    await repository.upsertBucket(
      workspaceId: workspaceId,
      bucket: StrategyBucket(
        id: bucket.id,
        name: bucket.name,
        type: bucket.type,
        teamIds: nextTeamIds,
        comment: bucket.comment,
        updatedAt: DateTime.now(),
      ),
      actor: user,
    );
  }

  Future<void> removeTeamFromBucket(String workspaceId, String bucketId, String teamId) async {
    final user = this.user;
    if (user == null || !canEditBoard) return;
    await repository.removeTeamFromBucket(
      workspaceId: workspaceId,
      bucketId: bucketId,
      teamId: teamId,
      actor: user,
    );
  }

  Future<void> moveTeamBetweenBuckets(
    String workspaceId,
    String sourceBucketId,
    String destinationBucketId,
    String teamId,
  ) async {
    final user = this.user;
    if (user == null || !canEditBoard) return;
    await repository.moveTeamBetweenBuckets(
      workspaceId: workspaceId,
      sourceBucketId: sourceBucketId,
      destinationBucketId: destinationBucketId,
      teamId: teamId,
      actor: user,
    );
  }

  Future<void> reorderBucketTeams(String workspaceId, StrategyBucket bucket, List<String> orderedTeamIds) async {
    final user = this.user;
    if (user == null || !canEditBoard) return;
    await repository.upsertBucket(
      workspaceId: workspaceId,
      bucket: StrategyBucket(
        id: bucket.id,
        name: bucket.name,
        type: bucket.type,
        teamIds: orderedTeamIds,
        comment: bucket.comment,
        updatedAt: DateTime.now(),
      ),
      actor: user,
    );
  }

  Future<void> updateAvailability(String workspaceId, String teamId, AvailabilityState availability) async {
    final user = this.user;
    if (user == null || !canEditBoard) return;
    await repository.updateTeamAvailability(
      workspaceId: workspaceId,
      teamId: teamId,
      availability: availability,
      actor: user,
    );
  }

  Future<void> addNote(String workspaceId, String teamId, String noteText) async {
    final user = this.user;
    if (user == null) return;
    await repository.addNote(
      workspaceId: workspaceId,
      teamId: teamId,
      note: ScoutNote(
        id: _uuid.v4(),
        authorId: user.id,
        authorName: user.displayName,
        body: noteText,
        createdAt: DateTime.now(),
      ),
      actor: user,
    );
  }

  Future<void> addMember(String workspaceId, PickListUser member) async {
    final user = this.user;
    if (user == null || !canManageWorkspace) return;
    await repository.addMember(
      workspaceId: workspaceId,
      member: member,
      actor: user,
    );
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
