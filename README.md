# PickList

Flutter-first FRC pick list app scaffold for collaborative alliance selection.

## Modes

- Without Firebase values, the app starts in local mock mode with seeded demo data.
- With Firebase values, it initializes Firebase and uses the Firebase repository/auth adapters.

## Firebase bootstrap

Provide these compile-time values when you launch Flutter:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_TEAM_ORG_ID`
- `FIREBASE_DEFAULT_ROLE`

## Firestore rules

The repo includes a starter `firestore.rules` file that expects two custom auth claims:

- `teamOrgId`
- `role`

For v1, set those claims in Firebase Auth or mirror them into `users/{uid}` profile documents so the app can resolve the current member role and team-scoped access correctly.

Example:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_TEAM_ORG_ID=team-4414 \
  --dart-define=FIREBASE_DEFAULT_ROLE=strategist
```

## Firebase deployment

This repo now includes a starter `firebase.json` that wires Firestore rules and Firebase Hosting to the Flutter web build output.

Before deploying:

1. Build the web app:
   - `flutter build web`
2. Point Firebase at your project:
   - `firebase use <your-project-id>`
3. Deploy hosting and rules:
   - `firebase deploy`

If you want to validate the hosted build locally first:

1. Build the app:
   - `flutter build web`
2. Start the Firebase emulators:
   - `firebase emulators:start --only hosting,firestore`

## v1 release checklist

- Confirm `users/{uid}` profile docs exist for the people testing the workspace.
- Verify the Firestore rules are deployed and block cross-workspace edits.
- Import one real event CSV or JSON file and confirm duplicate rows show warnings.
- Run the app in Chrome and check that save states move through `syncing`, `saved`, and `failed`.
- Do one drag-and-drop pass between the master list and a bucket after a refresh.
