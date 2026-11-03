import 'package:flutter_test/flutter_test.dart';
import 'package:our_home/core/utils.dart';

void main() {
  group('RelationshipStats (numbers from the design)', () {
    // Design: "412 days together, since 24 Aug 2025" on 10 Oct 2026.
    final start = DateTime(2025, 8, 24);
    final now = DateTime(2026, 10, 10, 20, 0);
    final stats = RelationshipStats.compute(start, now);

    test('days together', () => expect(stats.days, 412));
    test('next day mark', () {
      expect(stats.nextDayMark, 500);
      expect(stats.daysToMark, 88);
    });
    test('next monthly milestone', () {
      expect(stats.nextMonth.label, '14 months');
      expect(stats.nextMonth.daysAway, 14);
    });
    test('next yearly milestone', () {
      expect(stats.nextYear.label, '2 years');
      expect(stats.nextYear.daysAway, 318); // the mock-up says 319, but 24 Aug 2027 is 318 days after 10 Oct 2026
    });
    test('progress', () => expect(stats.progress, closeTo(0.824, 0.001)));
  });

  test('addMonths clamps the day', () {
    expect(addMonths(DateTime(2025, 1, 31), 1), DateTime(2025, 2, 28));
    expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
  });

  test('couple day uses the shared offset, not the device zone', () {
    final utc = DateTime.utc(2026, 10, 10, 20, 0); // 04:00 on the 11th at +8
    expect(dateKey(coupleToday(utc, 8 * 60)), '2026-10-11');
    expect(dateKey(coupleToday(utc, -5 * 60)), '2026-10-10');
  });

  test('greeting', () {
    expect(greetingFor(DateTime(2026, 10, 10, 20)), 'Saturday evening');
  });
}
