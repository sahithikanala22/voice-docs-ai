# Release-device verification

Record device model, Android version, speech service, language, build/version,
result and any issue for each test. No boxes below have been verified on a real
phone by this release-preparation pass.

- [ ] Install the signed release from Play internal testing, cold-launch, create local PIN.
- [ ] Upgrade an earlier version without uninstalling; history/diary/tasks/photos/PIN survive.
- [ ] Record a 30-second note, a 5-minute device-speech diary and a quiet/normal/noisy sample.
- [ ] Test each advertised language, pauses, mixed accents, wired/Bluetooth mic and phone mic.
- [ ] Deny/revoke microphone permission; no stuck recording or false saved message.
- [ ] Stop, switch tabs, lock phone, background, receive a call and relaunch; inspect saved text.
- [ ] Cloud: valid key, missing key, invalid key, lost internet, quota error and 50-second stop.
- [ ] Cloud failure: reopen app, recover encrypted audio, retry, edit/date/save once; delete recovery item.
- [ ] Cloud success with failed history save: recovery audio/transcript remain available.
- [ ] Calendar: open a past date, add dictated/typed content, confirm original day.
- [ ] Diary: edit, mood, photos, delete; tasks: complete, recurring reminders, revoke notifications.
- [ ] Reminder delivery/reboot/timezone changes with exact alarm access both denied and allowed.
- [ ] Large text/font scaling, TalkBack labels, small display, Dark/Light/System; no clipped actions.
- [ ] Export/import with photos; invalid backup rejected without losing existing data.
- [ ] Delete all local data: cancel first, then confirm; reminders/PIN/photos/recovery gone.
- [ ] Privacy policy available before local profile setup and while locked.
- [ ] Run on a 16 KB page-size Android image/device; inspect Play pre-launch report.
- [ ] Validate Play-generated release APKs, not only a locally installed debug APK.
