import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/picklist_models.dart';

class AuthCredentials {
  const AuthCredentials({
    required this.displayName,
    required this.email,
    required this.teamOrgId,
    required this.password,
  });

  final String displayName;
  final String email;
  final String teamOrgId;
  final String password;
}

abstract class AuthService {
  Stream<PickListUser?> watchUser();
  PickListUser? currentUser();
  Future<void> signIn(AuthCredentials credentials);
  Future<void> signOut();
  Future<void> saveProfile(PickListUser user);
}

class MockAuthService implements AuthService {
  MockAuthService();

  PickListUser? _user;
  final StreamController<PickListUser?> _controller = StreamController<PickListUser?>.broadcast();

  @override
  PickListUser? currentUser() => _user;

  @override
  Stream<PickListUser?> watchUser() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<void> signIn(AuthCredentials credentials) async {
    _user = PickListUser(
      id: 'local-${credentials.email}',
      displayName: credentials.displayName,
      teamOrgId: credentials.teamOrgId,
      email: credentials.email,
      role: MemberRole.lead,
    );
    _controller.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<void> saveProfile(PickListUser user) async {
    _user = user;
    _controller.add(user);
  }
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  PickListUser? _cachedUser;

  @override
  PickListUser? currentUser() {
    return _cachedUser;
  }

  @override
  Future<void> signIn(AuthCredentials credentials) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: credentials.email,
        password: credentials.password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' || error.code == 'wrong-password') {
        await _firebaseAuth.createUserWithEmailAndPassword(
          email: credentials.email,
          password: credentials.password,
        );
      } else {
        rethrow;
      }
    }
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await saveProfile(
        PickListUser(
          id: user.uid,
          displayName: credentials.displayName,
          teamOrgId: credentials.teamOrgId,
          email: credentials.email,
          role: MemberRole.lead,
        ),
      );
    }
  }

  @override
  Stream<PickListUser?> watchUser() {
    return _firebaseAuth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        _cachedUser = null;
        return Stream.value(null);
      }
      return _firestore.collection('users').doc(user.uid).snapshots().asyncMap((profile) async {
        final token = await user.getIdTokenResult();
        final mapped = _mapUser(user, profile.data(), token.claims);
        _cachedUser = mapped;
        return mapped;
      });
    });
  }

  PickListUser _mapUser(User user, Map<String, dynamic>? profile, Map<String, dynamic>? claims) {
    const fallbackTeamOrgId = String.fromEnvironment('FIREBASE_TEAM_ORG_ID', defaultValue: '');
    final roleName = (claims?['role'] as String?) ?? (profile?['role'] as String?) ?? 'scout';
    final teamOrgId = (claims?['teamOrgId'] as String?) ?? (profile?['teamOrgId'] as String?) ?? fallbackTeamOrgId;
    return PickListUser(
      id: user.uid,
      displayName: (profile?['displayName'] as String?) ?? user.displayName ?? user.email ?? 'FRC Member',
      teamOrgId: teamOrgId,
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
