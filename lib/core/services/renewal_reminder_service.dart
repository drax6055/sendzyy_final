import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sendzyy/core/theme/app_theme.dart';

/// Checks panel expiry every [checkInterval] and shows a reminder dialog
/// if expiry is within [warnDays] days. Respects a [snoozeInterval] so the
/// dialog doesn't reappear until that duration has passed.
class RenewalReminderService {
  static const Duration checkInterval = Duration(hours: 4);
  static const Duration snoozeInterval = Duration(hours: 4);
  static const Duration initialDelay = Duration(seconds: 5);
  static const int warnDays = 7;
  static const String _prefKey = 'renewal_reminder_last_shown';

  Timer? _timer;
  final SharedPreferences _prefs;

  RenewalReminderService(this._prefs);

  /// Start the periodic check. [getExpiryDate] is called each tick to get
  /// the current panel expiry. [onShow] is called when the dialog should appear.
  void start({
    required DateTime? Function() getExpiryDate,
    required void Function(DateTime expiresAt, int daysLeft) onShow,
  }) {
    // Delay first check to ensure expiry date is loaded
    Future.delayed(initialDelay, () => _check(getExpiryDate, onShow));
    _timer = Timer.periodic(checkInterval, (_) => _check(getExpiryDate, onShow));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _check(
    DateTime? Function() getExpiryDate,
    void Function(DateTime, int) onShow,
  ) {
    final expiresAt = getExpiryDate();
    if (expiresAt == null) return;

    final daysLeft = expiresAt.difference(DateTime.now()).inDays;
    // Only warn if within warnDays and not already expired
    if (daysLeft < 0 || daysLeft > warnDays) return;

    // Respect snooze — don't show again until snoozeInterval has passed
    final lastShownMs = _prefs.getInt(_prefKey) ?? 0;
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
    if (DateTime.now().difference(lastShown) < snoozeInterval) return;

    onShow(expiresAt, daysLeft);
  }

  Future<void> markShown() async {
    await _prefs.setInt(_prefKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Show the renewal reminder dialog. Returns true if user tapped "Renew Now".
  static Future<bool> showReminderDialog(
    BuildContext context, {
    required DateTime expiresAt,
    required int daysLeft,
  }) async {
    final expStr =
        '${expiresAt.day.toString().padLeft(2, '0')}/${expiresAt.month.toString().padLeft(2, '0')}/${expiresAt.year}';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RenewalReminderDialog(
        expiryDateStr: expStr,
        daysLeft: daysLeft,
      ),
    );
    return result == true;
  }
}

class _RenewalReminderDialog extends StatelessWidget {
  final String expiryDateStr;
  final int daysLeft;

  const _RenewalReminderDialog({
    required this.expiryDateStr,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = daysLeft == 0;
    final isTomorrow = daysLeft == 1;
    final urgentColor = daysLeft <= 2 ? Colors.red : Colors.orange;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: urgentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: urgentColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isToday
                  ? 'Panel Expires Today!'
                  : isTomorrow
                      ? 'Panel Expires Tomorrow!'
                      : 'Panel Expiring Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: urgentColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87, height: 1.5),
                children: [
                  const TextSpan(text: 'Your panel plan expires on '),
                  TextSpan(
                    text: expiryDateStr,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: urgentColor),
                  ),
                  TextSpan(
                    text: isToday
                        ? '.\nRenew now to avoid service interruption.'
                        : isTomorrow
                            ? '.\nRenew today to keep your service running.'
                            : ' — $daysLeft days left.\nRenew your plan to keep sending messages without interruption.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'Remind Later',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Renew Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

