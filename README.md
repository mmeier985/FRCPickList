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
