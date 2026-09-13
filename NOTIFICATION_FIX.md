# Notification fix

## Main fixes
- Fixed Android 13+ notification permission check.
- Fixed Hanoi timezone construction for scheduled wall-clock times.
- `requestAllPermissions()` initializes the service itself.
- Exact alarm is preferred; inexact is only a runtime fallback if exact scheduling is rejected.
- Existing SQLite events are rescheduled at startup.
- Built-in Vietnamese holidays are rescheduled for current + next year.
- Editing an event with notifications disabled cancels the old alarm.
- Test notification no longer uses `Future.delayed()` as a fake fallback.
- `SCHEDULE_EXACT_ALARM` is limited to Android 12 (API 31-32); `USE_EXACT_ALARM` is used for newer Android versions.
- Notification channels use v3 IDs and `Importance.max`.

## Important Android limitation
The app cannot force notification display if the user disables notifications, lock-screen notifications, banners, sound, or Do Not Disturb blocks them. OEM battery policies (especially ColorOS/Realme UI) can also affect behavior.

## Recommended test
1. Uninstall old APK.
2. Install the new APK.
3. Grant notifications.
4. On Android 12, grant Alarms & reminders if requested.
5. Create an event 5-10 minutes in the future and enable notification.
6. Lock the screen and leave the app closed.
7. Check Settings > Notifications > Lịch Việt > Sự kiện lịch and ensure lock-screen/banner/sound are enabled.
