# Voice Docs AI — Play release preparation

## Current boundary

Source updates and automated checks are not a production approval. Do not upload
the earlier debug UI preview as the release. A release candidate must be built
from this source with the upload key, verified on devices, then tested through
Play. No Play Console account or production access is assumed.

## Developer identity and privacy

1. Copy identity.example.json to identity.json and provide DEVELOPER_NAME,
   SUPPORT_EMAIL and the public HTTPS PRIVACY_POLICY_URL. These fields are public;
   never put API keys or passwords in this file.
2. Run `dart run scripts/prepare_play_release.dart release/identity.json`.
3. Publish generated/privacy-policy.html on your website at that URL. Open it
   signed out and check the contact details. The app reads the same policy copy
   offline and embeds identity via --dart-define-from-file.
4. The --draft option generates review material from identity.example.json.
   Drafts cannot satisfy the release preparation script.

## Signing

Existing android/key.properties and the upload keystore are retained, not
replaced. Keep them offline/backed up and outside source control. The release
Gradle configuration now fails if signing fields are missing, the file is absent,
or the alias is androiddebugkey. scripts/VerifyUploadKey.java checks the actual
certificate, key/password and expiry without printing the private key/password.

Build using `powershell -File scripts/build_play_release.ps1`.
The script generates the policy, verifies signing, resolves locked dependencies,
generates Dart models, checks formatting/analyzer/tests, builds a signed release
AAB, and inspects every 64-bit native ELF LOAD segment for 16 KB compatibility.
Set -FlutterSdk if Flutter is elsewhere. Java 17+ is required.

Output: build/app/outputs/bundle/release/app-release.aab.
Current source version: 1.0.0+4. If Play already has version code 4 or above, choose
a higher code before upload. Keep application ID com.aivoicedocs.app unchanged
for updates to an existing listing; verify ownership in your Play Console.

Target and compile SDK are API 36. Native build uses Flutter's NDK 28 default
and Android Gradle Plugin 9.0.1. The ELF checker is additional evidence; it does
not replace runtime testing or Play-generated APK compatibility checks.

## Store assets and app-content forms

- Review store-listing.txt; it describes the actual Cloud limits and does not
  promise offline recognition or perfect accuracy.
- Run `flutter test scripts/render_store_artwork.dart` to regenerate the RGB PNG
  icon (512x512) and feature graphic (1024x500). Current artwork is in generated/.
- Capture current release screenshots on representative phones. Preview/widget
  screenshots are review aids, not evidence of a release running on hardware.
- Complete data-safety-worksheet.md against the final release.
- Confirm support email, public policy URL, audience/age declarations, content
  rating questionnaire, ad declaration and developer identity verification.
- Reviewer access: no server login exists. Explain creating a local name/PIN and
  testing device speech. Cloud mode requires a working user-supplied API key.
  If reviewers must test that mode, arrange restricted test credentials through
  Play's private reviewer access process, never in screenshots or public copy.
- USE_EXACT_ALARM was removed; SCHEDULE_EXACT_ALARM remains optional with an
  inexact fallback. Do not restore the restricted permission casually.

## Test, then publish

Complete device-test-matrix.md and run Play's internal testing/pre-launch report.
For personal developer accounts created after 2023-11-13, confirm the current
12-testers/14-continuous-days closed-test requirement and production-access
application in Play Console. Account-specific eligibility cannot be inferred
from the code. Publishing is a separate owner decision after review.

Official references:
- https://docs.flutter.dev/deployment/android
- https://developer.android.com/guide/practices/page-sizes
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://support.google.com/googleplay/android-developer/answer/14151465
