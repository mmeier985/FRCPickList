# PickList

Flutter-first FRC pick list app scaffold for collaborative alliance selection.

## Modes

- Without Firebase values, the app starts in local mock mode with seeded demo data.
- With Firebase values, it initializes Firebase and uses the Firebase repository/auth adapters.

## Firebase bootstrap

Provide these compile-time values when you launch Flutter:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_TEAM_ORG_ID`

## Firestore rules

The repo includes a starter `firestore.rules` file that expects one custom auth claim and workspace-managed roles:

- `teamOrgId` for workspace scoping
- `memberMap` inside each workspace document for board/admin roles

For v1, set the `teamOrgId` claim in Firebase Auth during onboarding. The current user's board permissions come from the active workspace membership record, not from the editable profile doc.

To create the first workspace for an org, seed one Firebase Auth user with both `teamOrgId` and a `role=lead` claim. After the workspace exists, the lead can manage workspace membership from inside the app.

Example:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_TEAM_ORG_ID=team-4414
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

## Seeding the first lead

To seed the first lead account with custom claims, install the Node dependency and run the helper script:

1. Install the admin tool dependency:
   - `npm install`
2. Download your Firebase service account JSON from `Project settings > Service accounts`.
3. Run the seeding script:
   - `node seed-claims.js lead@example.org team-4414 lead ./serviceAccountKey.json`

This sets `teamOrgId` and `role` custom claims on the Firebase Auth user. After that, the user should sign out and sign back in so the new claims appear in their token.

## v1 release checklist

- Confirm `users/{uid}` profile docs exist for the people testing the workspace.
- Confirm the `teamOrgId` claim exists for every signed-in user.
- Confirm at least one account has a `lead` claim before trying to create the first workspace.
- Verify the Firestore rules are deployed and block cross-workspace edits.
- Import one real event CSV or JSON file and confirm duplicate rows show warnings.
- Run the app in Chrome and check that save states move through `syncing`, `saved`, and `failed`.
- Do one drag-and-drop pass on the master list after a refresh.
