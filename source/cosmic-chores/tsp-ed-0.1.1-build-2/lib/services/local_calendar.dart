// /////Block One/////////////////////////////////////////////////////////////
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Calendar arithmetic ignores elapsed hours, including daylight-saving time.
class LocalCalendar {
  static DateTime Function() now = DateTime.now;
  static DateTime date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static String key(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';
  static int daysBetween(DateTime start, DateTime end) => DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  static int daysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;
}

// /////Block Two/////////////////////////////////////////////////////////////
/// Refresh at midnight, on resume, and after foreground clock/time-zone changes.
mixin LocalDateObserver<T extends StatefulWidget> on State<T> {
  Timer? _midnightTimer;
  Timer? _clockCheck;
  late final AppLifecycleListener _lifecycle;
  DateTime localNow = LocalCalendar.now();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: refreshLocalDate);
    _armMidnight();
    _clockCheck = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshLocalDate(),
    );
  }

  void refreshLocalDate() {
    final now = LocalCalendar.now();
    final changed =
        LocalCalendar.key(now) != LocalCalendar.key(localNow) ||
        now.timeZoneOffset != localNow.timeZoneOffset;
    final previous = localNow;
    localNow = now;
    if (changed && mounted) {
      setState(() => onLocalDateChanged(previous, now));
    }
    _armMidnight();
  }

  void onLocalDateChanged(DateTime previous, DateTime current) {}

  void _armMidnight() {
    _midnightTimer?.cancel();
    final now = LocalCalendar.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(next.difference(now), refreshLocalDate);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _midnightTimer?.cancel();
    _clockCheck?.cancel();
    super.dispose();
  }
}
