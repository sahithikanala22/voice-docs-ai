import 'package:app_badge_plus/app_badge_plus.dart';

/// Puts a count on the app's launcher icon — the "unread messages"-style red
/// badge, not the OS notification that fires later at a reminder's
/// scheduled time. This is what makes adding a task or a reminder show up
/// immediately, while `NotificationService`'s channel badge only appears
/// once that reminder's notification has actually posted.
///
/// Every call is best-effort: a launcher that doesn't support badges (or a
/// platform this doesn't run on) just does nothing rather than surfacing an
/// error the user can't act on.
class AppBadgeService {
  AppBadgeService._();

  static final AppBadgeService instance = AppBadgeService._();

  bool? _supported;

  Future<void> setCount(int count) async {
    try {
      final supported = _supported ??= await AppBadgePlus.isSupported();
      if (!supported) return;
      await AppBadgePlus.updateBadge(count);
    } catch (_) {
      // Best-effort — see class doc.
    }
  }
}
