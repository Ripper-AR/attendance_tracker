import 'package:attendance_tracker/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Member renewalStartDate', () {
    test('uses current expiry date when renewing before expiry', () {
      final member = _member(
        subscriptionType: monthlySubscriptionType,
        paymentDate: DateTime(2026, 8),
      );

      expect(member.renewalStartDate(DateTime(2026, 8, 20)), DateTime(2026, 9));
    });

    test('uses today when renewing after expiry', () {
      final member = _member(
        subscriptionType: monthlySubscriptionType,
        paymentDate: DateTime(2026, 8),
      );

      expect(
        member.renewalStartDate(DateTime(2026, 9, 5)),
        DateTime(2026, 9, 5),
      );
    });

    test('uses today for session packages', () {
      final member = _member(
        subscriptionType: sessionCountSubscriptionType,
        paymentDate: DateTime(2026, 8),
      );

      expect(
        member.renewalStartDate(DateTime(2026, 8, 15)),
        DateTime(2026, 8, 15),
      );
    });
  });

  group('subscription types', () {
    test('new subscription options are session based', () {
      expect(isSessionCountSubscription(privateSubscriptionType), isTrue);
      expect(isSessionCountSubscription(jumpingSubscriptionType), isTrue);
      expect(isSessionCountSubscription(teamSubscriptionType), isTrue);
      expect(isSessionCountSubscription(beginnerGuardSubscriptionType), isTrue);
      expect(
        isSessionCountSubscription(beginnerPresidencySubscriptionType),
        isTrue,
      );
      expect(isSessionCountSubscription(beginnerCivilSubscriptionType), isTrue);
      expect(isSessionCountSubscription(accommodationSubscriptionType), isTrue);
    });
  });

  group('attendance track', () {
    test('serializes selected track', () {
      final record = AttendanceRecord(
        id: 'record-1',
        memberId: 'member-1',
        scannedAt: DateTime(2026, 8, 14, 17, 15),
        track: AttendanceTrack.rounds,
      );

      expect(record.toJson()['track'], 'rounds');
      expect(
        AttendanceRecord.fromJson(record.toJson()).track,
        AttendanceTrack.rounds,
      );
    });

    test('defaults old records to launch', () {
      final record = AttendanceRecord.fromJson(<String, Object?>{
        'id': 'record-1',
        'memberId': 'member-1',
        'scannedAt': DateTime(2026, 8, 14, 17, 15).toIso8601String(),
      });

      expect(record.track, AttendanceTrack.launch);
    });
  });

  group('beginners school routing', () {
    test('matches Mondays and Thursdays only', () {
      expect(isBeginnersSchoolDay(DateTime(2026, 8, 17)), isTrue);
      expect(isBeginnersSchoolDay(DateTime(2026, 8, 20)), isTrue);
      expect(isBeginnersSchoolDay(DateTime(2026, 8, 14)), isFalse);
    });
  });
}

Member _member({
  required String subscriptionType,
  required DateTime paymentDate,
}) {
  return Member(
    id: 'member-1',
    qrToken: 'ATT-token-1',
    name: 'Member',
    phone: '01000000000',
    subscriptionType: subscriptionType,
    amount: 100,
    paymentDate: paymentDate,
    totalSessions: 10,
    createdAt: DateTime(2026),
  );
}
