import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/picklist_models.dart';

abstract class AuthService {
  Stream<PickListUser?> watchUser();
  PickListUser currentUser();
  Future<void> signOut();
  Future<void> saveProfile(PickListUser user);
}

class MockAuthService implements AuthService {
  final PickListUser _user = const PickListUser(
    id: 'local-lead',
    displayName: 'Local Lead',
    teamOrgId: 'team-4414',
    email: 'lead@example.org',
    role: MemberRole.lead,
  );

  @override
  PickListUser currentUser() => _user;

  @override
  Stream<PickListUser?> watchUser() async* {
    yield _user;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> saveProfile(PickListUser user) async {}
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  @override
  PickListUser currentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return const PickListUser(
        id: 'anonymous',
        displayName: 'Anonymous',
        teamOrgId: '',
        email: '',
        role: MemberRole.scout,
      );
    }
    return _mapUser(user, null);
  }

  @override
  Stream<PickListUser?> watchUser() {
    return _firebaseAuth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(null);
      }
      return _firestore.collection('users').doc(user.uid).snapshots().map((profile) {
        return _mapUser(user, profile.data());
      });
    });
  }

  PickListUser _mapUser(User user, Map<String, dynamic>? profile) {
    const fallbackTeamOrgId = String.fromEnvironment('FIREBASE_TEAM_ORG_ID', defaultValue: '');
    const defaultRoleName = String.fromEnvironment('FIREBASE_DEFAULT_ROLE', defaultValue: 'strategist');
    final roleName = (profile?['role'] as String?) ?? defaultRoleName;
    return PickListUser(
      id: user.uid,
      displayName: (profile?['displayName'] as String?) ?? user.displayName ?? user.email ?? 'FRC Member',
      teamOrgId: (profile?['teamOrgId'] as String?) ?? fallbackTeamOrgId,
      email: (profile?['email'] as String?) ?? user.email ?? '',
      role: _roleFromName(roleName),
    );
  }

  MemberRole _roleFromName(String name) {
    return MemberRole.values.firstWhere((role) => role.name == name, orElse: () => MemberRole.strategist);
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Future<void> saveProfile(PickListUser user) async {
    await _firestore.collection('users').doc(user.id).set({
      'displayName': user.displayName,
      'teamOrgId': user.teamOrgId,
      'email': user.email,
      'role': user.role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
