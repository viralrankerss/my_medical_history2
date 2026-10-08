# My Medical History — Flutter SQLite Android demo

This is a **student demonstration app**; use fictional medical records only.

## What's included
- Add, edit, delete medical visits (SQLite on Android)
- Doctor-wise visit history; search by doctor, diagnosis, medicine, symptom, or test
- Doctor phone, hospital, dosage/medicine and test notes
- Image/PDF file selection (attachments stored within the app documents directory)
- Location address that opens a Google Maps search
- Manual JSON backup export via system share sheet and JSON restore (photos/PDFs are **not** included)

Not included: automatic Google Drive sync, Google OAuth, GPS coordinates/pin selection, encrypted storage, or attachment viewer. Medicine/tests are entered as text, not normalized relational records.

## Build an APK without Android Studio
1. In your GitHub repo, replace `lib/main.dart` and `pubspec.yaml` with these versions.
2. Add `.github/workflows/build-apk.yml` to your repo exactly as shown.
3. Commit to the `main` branch.
4. Open GitHub repository > **Actions** > **Build Android APK** > **Run workflow** > `main` > **Run workflow**.
5. Open the run and wait for success. Under **Artifacts**, download `my-medical-history-debug-apk` ZIP and extract `app-debug.apk`.
6. Install the debug APK on your Android phone for personal testing. **Debug APK is not suitable for Play Store publishing.**

If GitHub Actions are disabled, enable them in repository settings. Public repository standard hosted runner use is generally free subject to GitHub policies/limits.

## Important
The generated APK's debug signing certificate can differ across GitHub Actions runs. Updates might require uninstalling the previous APK, which deletes on-device local data. Test only with fictional records. Do not depend on the JSON backup for complete attachment recovery.

The project does not include a committed `android/` folder; the workflow uses `flutter create` to generate it. Build has not been executed in this environment. If it fails, read the first red error under the failing GitHub Actions step.
