import 'dart:math' as math;

import 'package:intl/intl.dart';

/// `yyyy-MM-dd` from the date components (works for local and UTC dates).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Both partners can live in different time zones, so "today's question" and
/// the streak use one shared "couple day": the calendar day in the time zone of
/// whoever created the space (stored on the couple as `tzOffsetMinutes`).
DateTime coupleToday(DateTime now, int offsetMinutes) {
  final t = now.toUtc().add(Duration(minutes: offsetMinutes));
  return DateTime.utc(t.year, t.month, t.day);
}

int epochDay(DateTime utcDay) =>
    utcDay.difference(DateTime.utc(2025, 1, 1)).inDays;

String greetingFor(DateTime now) {
  final h = now.hour;
  final part = h < 5
      ? 'night'
      : h < 12
          ? 'morning'
          : h < 17
              ? 'afternoon'
              : h < 21
                  ? 'evening'
                  : 'night';
  return '${DateFormat('EEEE').format(now)} $part';
}

/// Adds calendar months, clamping the day (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, math.min(d.day, last));
}

int calendarDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

String inDaysLabel(int days) {
  if (days <= 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

class Milestone {
  const Milestone(this.label, this.date, this.daysAway);
  final String label;
  final DateTime date;
  final int daysAway;
}

/// Everything shown on the big "days together" card.
class RelationshipStats {
  const RelationshipStats({
    required this.days,
    required this.nextDayMark,
    required this.nextMonth,
    required this.nextYear,
  });

  final int days;
  final int nextDayMark;
  final Milestone nextMonth;
  final Milestone nextYear;

  int get daysToMark => nextDayMark - days;
  double get progress => (days / nextDayMark).clamp(0.0, 1.0).toDouble();

  static RelationshipStats compute(DateTime start, DateTime now) {
    final s = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = math.max(0, calendarDaysBetween(s, today));

    final mark = days == 0 ? 100 : ((days + 99) ~/ 100) * 100;

    var m = 1;
    while (addMonths(s, m).isBefore(today)) {
      m++;
    }
    final monthDate = addMonths(s, m);
    final monthLabel = m % 12 == 0
        ? _years(m ~/ 12)
        : '$m ${m == 1 ? 'month' : 'months'}';

    var y = 1;
    while (addMonths(s, 12 * y).isBefore(today)) {
      y++;
    }
    final yearDate = addMonths(s, 12 * y);

    return RelationshipStats(
      days: days,
      nextDayMark: mark,
      nextMonth:
          Milestone(monthLabel, monthDate, calendarDaysBetween(today, monthDate)),
      nextYear:
          Milestone(_years(y), yearDate, calendarDaysBetween(today, yearDate)),
    );
  }

  static String _years(int y) => '$y ${y == 1 ? 'year' : 'years'}';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String shortDate(DateTime d, DateTime now) => d.year == now.year
    ? DateFormat('d MMM').format(d)
    : DateFormat('d MMM yyyy').format(d);

String relativeDay(DateTime d, DateTime now) {
  if (sameDay(d, now)) return 'today';
  if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'yesterday';
  return shortDate(d, now);
}

String clockTime(DateTime d) => DateFormat('h:mm a').format(d);

String chatDayLabel(DateTime d, DateTime now) {
  if (sameDay(d, now)) return 'TODAY';
  if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
  return DateFormat('EEE, d MMM').format(d).toUpperCase();
}

String lastSeenLabel(DateTime? t, DateTime now) {
  if (t == null) return 'offline';
  final diff = now.difference(t);
  if (diff.inSeconds < 150) return 'online now';
  if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
  return 'last seen ${shortDate(t, now)}';
}

String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';
