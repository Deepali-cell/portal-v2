# Push Notifications — Activation Guide

The **backend is complete**: device tokens are stored in the `TCB Device Token`
DocType, registered via `tcb_inside.api.notifications.register_device`, and
pushed via FCM HTTP v1 in `send_to_user`. A sample hook already fires on Leave
Application approval/rejection (`on_leave_application_update`).

Push is **not active** yet because it needs a Firebase project + native config.
Complete these steps to turn it on.

## 1. Firebase project
1. Create a Firebase project at https://console.firebase.google.com.
2. Add an **Android app** (package `com.tcbinfotech.tcbPortal`) → download
   `google-services.json` → place in `android/app/`.
3. Add an **iOS app** (bundle `com.tcbinfotech.tcbPortal`) → download
   `GoogleService-Info.plist` → add to `ios/Runner/` (via Xcode so it's bundled).
4. Project Settings → Service accounts → **Generate new private key** → save the
   JSON somewhere readable by the bench.

## 2. Bench config (server)
Add to `frappe-bench-v16/sites/tcb.local/site_config.json`:
```json
"fcm_project_id": "<your-firebase-project-id>",
"fcm_service_account_path": "/absolute/path/to/service-account.json"
```
Ensure `google-auth` is in the bench env: `./env/bin/pip install google-auth requests`.

## 3. Flutter client
```sh
flutter pub add firebase_core firebase_messaging
flutterfire configure   # generates lib/firebase_options.dart
```
- Android: apply the Google Services Gradle plugin (`android/settings.gradle.kts`
  + `android/app/build.gradle.kts`), minSdk ≥ 23.
- iOS: enable Push Notifications + Background Modes (remote notifications) in Xcode;
  add an APNs key in the Firebase console.

Then complete `lib/core/notifications/notification_service.dart`:
```dart
Future<void> syncRegistration() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  final token = await messaging.getToken();
  if (token != null) {
    await registerToken(token, Platform.isIOS ? 'iOS' : 'Android');
  }
  FirebaseMessaging.onMessage.listen((msg) {/* show in-app banner */});
}
```
Call `Firebase.initializeApp(...)` in `main()` before `runApp`.

## 4. Verify
- Sign in on a device → a `TCB Device Token` row appears for the user.
- Approve that user's Leave Application in Frappe → device receives a push.

The registration endpoints (`registerToken`/`unregisterToken`) and the
post-login call site (`AuthController.login → syncRegistration`) are already in
place, so only the Firebase wiring above remains.
