# Data safety worksheet — requires owner confirmation before submission

This is an implementation inventory, not a completed Play Console declaration.
Review every bundled SDK and the actual release build. Local-only processing
is not automatically collection under Play's definitions; optional uploads do
not become local-only because the developer does not run a backend.

| Data | Current handling | Play Console review |
|---|---|---|
| Audio | Device speech provider may use its servers. Optional Google Cloud receives audio after stop and on retry. Recovery audio is encrypted locally. | Review Audio files / Voice or sound recordings; functionality purpose; optional use; collection and service-provider relationship. Do not claim nothing is collected without reviewing both speech modes. |
| Notes, diary, moods, tasks | Encrypted feature JSON in private app storage; no developer sync server. Shared/exported only by user action. | Review Other user-generated content against actual SDK transmission. |
| Name, optional email/date of birth | Local profile only. Not sent to a developer account server. | Confirm no future analytics or support SDK uploads these fields. |
| Photos | Local private copies; app does not upload images itself. User may export/share. | Review Photos if behavior or SDKs change. |
| API key and PIN | Key encrypted locally; PIN salted hash; excluded from portable backups. API key sent to Google for request authentication. | Never include shared developer credentials in the app or store listing. |
| Biometric data | OS handles verification; app receives success/failure. | App does not receive fingerprint/face templates. |
| Diagnostics, identifiers, ads | No developer analytics, advertising or crash-upload SDK identified in current dependencies. | Recheck dependencies and merged manifest before each release. |

Google Cloud requests use HTTPS; this alone does not prove every OS speech/TTS
provider's behavior. Verify processing/retention with Google's applicable terms.
Do not mark ephemeral processing merely because the app deletes a local copy.

Deletion: Settings > Delete all local data removes known app data and cancels
notifications. Individual items can be deleted in their respective screens.
The app creates a local profile, not a hosted account. No server account
deletion endpoint exists. Reassess Play's account-deletion requirements before
adding registration, server storage or synchronization. Externally shared files
and provider-held data are outside the local deletion operation.

Public privacy URL must be accessible without login, publicly readable and
consistent with the offline policy. The developer name and contact details must
match the Play Console listing.

Sources:
- https://support.google.com/googleplay/android-developer/answer/10787469
- https://support.google.com/googleplay/android-developer/answer/10144311
