import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/picklist_repository.dart';
import '../data/mock_picklist_repository.dart';
import '../data/firebase_picklist_repository.dart';
import 'auth_service.dart';

class AppBootstrap {
  AppBootstrap({
    required this.repository,
    required this.authService,
  });

  final PickListRepository repository;
  final AuthService authService;

  static Future<AppBootstrap> initialize() async {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
    const appId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
    const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
    final firebaseConfigured = _firebaseConfigured(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
    );
    if (firebaseConfigured) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          authDomain: authDomain.isEmpty ? null : authDomain,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: '$projectId.appspot.com',
        ),
      );
      final firestore = FirebaseFirestore.instance;
      return AppBootstrap(
        repository: FirebasePickListRepository(),
        authService: FirebaseAuthService(firestore: firestore),
      );
    }

    return AppBootstrap(
      repository: MockPickListRepository.seeded(),
      authService: MockAuthService(),
    );
  }

  static bool _firebaseConfigured({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
  }) {
    return apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;
  }
}
