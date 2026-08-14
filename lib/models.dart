DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String dateKey(DateTime value) {
  final date = dateOnly(value);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime cairoNow() {
  return DateTime.now().toUtc().add(const Duration(hours: 3));
}

const String monthlySubscriptionType = 'شهري';
const String quarterlySubscriptionType = 'ربع سنوي';
const String yearlySubscriptionType = 'سنوي';
const String sessionCountSubscriptionType = 'عدد حصص';
const String privateSubscriptionType = 'برايفت';
const String jumpingSubscriptionType = 'قفز';
const String teamSubscriptionType = 'فريق';
const String beginnerGuardSubscriptionType = 'مبتدئين حرس';
const String beginnerPresidencySubscriptionType = 'مبتدئين رئاسة';
const String beginnerCivilSubscriptionType = 'مبتدئين مدني';
const String accommodationSubscriptionType = 'إيواء';

const List<String> defaultSubscriptionTypes = <String>[
  privateSubscriptionType,
  jumpingSubscriptionType,
  teamSubscriptionType,
  beginnerGuardSubscriptionType,
  beginnerPresidencySubscriptionType,
  beginnerCivilSubscriptionType,
  accommodationSubscriptionType,
];

const List<String> sessionBasedSubscriptionTypes = <String>[
  sessionCountSubscriptionType,
  ...defaultSubscriptionTypes,
];

const int nearExpiryDaysThreshold = 7;

bool isBeginnersSchoolDay(DateTime value) {
  return value.weekday == DateTime.monday || value.weekday == DateTime.thursday;
}

bool isSessionCountSubscription(String subscriptionType) {
  return sessionBasedSubscriptionTypes.contains(subscriptionType.trim());
}

int? subscriptionDurationMonths(String subscriptionType) {
  return switch (subscriptionType.trim()) {
    monthlySubscriptionType => 1,
    quarterlySubscriptionType => 3,
    yearlySubscriptionType => 12,
    _ => null,
  };
}

DateTime addCalendarMonths(DateTime value, int months) {
  final targetMonthIndex = value.month - 1 + months;
  final targetYear = value.year + targetMonthIndex ~/ 12;
  final targetMonth = targetMonthIndex % 12 + 1;
  final lastDay = _lastDayOfMonth(targetYear, targetMonth);
  final targetDay = value.day > lastDay ? lastDay : value.day;
  return DateTime(targetYear, targetMonth, targetDay);
}

int _lastDayOfMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

enum SubscriptionState { active, nearExpiry, expired }

enum AttendanceTrack { launch, rounds }

String attendanceTrackLabel(AttendanceTrack track) {
  return switch (track) {
    AttendanceTrack.launch => 'لانش',
    AttendanceTrack.rounds => 'راوندز',
  };
}

String attendanceTrackJsonValue(AttendanceTrack track) {
  return switch (track) {
    AttendanceTrack.launch => 'launch',
    AttendanceTrack.rounds => 'rounds',
  };
}

AttendanceTrack attendanceTrackFromJson(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'rounds' || 'round' || 'راوندز' => AttendanceTrack.rounds,
    'launch' || 'لانش' => AttendanceTrack.launch,
    _ => AttendanceTrack.launch,
  };
}

class Member {
  const Member({
    required this.id,
    required this.qrToken,
    required this.name,
    required this.phone,
    required this.subscriptionType,
    required this.amount,
    required this.paymentDate,
    required this.totalSessions,
    required this.createdAt,
  });

  final String id;
  final String qrToken;
  final String name;
  final String phone;
  final String subscriptionType;
  final double amount;
  final DateTime paymentDate;
  final int totalSessions;
  final DateTime createdAt;

  bool get isSessionCountBased {
    return isSessionCountSubscription(subscriptionType);
  }

  DateTime? get expiryDate {
    final durationMonths = subscriptionDurationMonths(subscriptionType);
    if (durationMonths == null) {
      return null;
    }

    return addCalendarMonths(paymentDate, durationMonths);
  }

  int? daysUntilExpiry([DateTime? from]) {
    final expiry = expiryDate;
    if (expiry == null) {
      return null;
    }

    final today = dateOnly(from ?? DateTime.now());
    return dateOnly(expiry).difference(today).inDays;
  }

  DateTime renewalStartDate([DateTime? from]) {
    final today = dateOnly(from ?? DateTime.now());
    final expiry = expiryDate;
    if (expiry == null) {
      return today;
    }

    final normalizedExpiry = dateOnly(expiry);
    return normalizedExpiry.isBefore(today) ? today : normalizedExpiry;
  }

  int remainingSessions(int attendanceCount) {
    final remaining = totalSessions - attendanceCount;
    return remaining < 0 ? 0 : remaining;
  }

  SubscriptionState subscriptionState([int attendanceCount = 0]) {
    if (isSessionCountBased) {
      final remaining = remainingSessions(attendanceCount);
      if (remaining <= 0) {
        return SubscriptionState.expired;
      }

      if (remaining <= 2) {
        return SubscriptionState.nearExpiry;
      }

      return SubscriptionState.active;
    }

    final daysLeft = daysUntilExpiry();
    if (daysLeft == null) {
      return SubscriptionState.active;
    }

    if (daysLeft < 0) {
      return SubscriptionState.expired;
    }

    if (daysLeft <= nearExpiryDaysThreshold) {
      return SubscriptionState.nearExpiry;
    }

    return SubscriptionState.active;
  }

  Member copyWith({
    String? id,
    String? qrToken,
    String? name,
    String? phone,
    String? subscriptionType,
    double? amount,
    DateTime? paymentDate,
    int? totalSessions,
    DateTime? createdAt,
  }) {
    return Member(
      id: id ?? this.id,
      qrToken: qrToken ?? this.qrToken,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      totalSessions: totalSessions ?? this.totalSessions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'qrToken': qrToken,
      'name': name,
      'phone': phone,
      'subscriptionType': subscriptionType,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'totalSessions': totalSessions,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Member.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return Member(
      id: json['id']?.toString() ?? '',
      qrToken: json['qrToken']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      subscriptionType: json['subscriptionType']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentDate: _parseDate(json['paymentDate'], now),
      totalSessions: _parseInt(json['totalSessions']),
      createdAt: _parseDate(json['createdAt'], now),
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.memberId,
    required this.scannedAt,
    this.track = AttendanceTrack.launch,
  });

  final String id;
  final String memberId;
  final DateTime scannedAt;
  final AttendanceTrack track;

  String get dayKey => dateKey(scannedAt);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'memberId': memberId,
      'scannedAt': scannedAt.toIso8601String(),
      'track': attendanceTrackJsonValue(track),
    };
  }

  factory AttendanceRecord.fromJson(Map<String, Object?> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      memberId: json['memberId']?.toString() ?? '',
      scannedAt: _parseDate(json['scannedAt'], DateTime.now()),
      track: attendanceTrackFromJson(json['track']),
    );
  }
}

enum ScanResultType { success, empty, notFound, expired }

class ScanResult {
  const ScanResult({required this.type, this.member, this.attendanceCount = 0});

  final ScanResultType type;
  final Member? member;
  final int attendanceCount;
}

DateTime _parseDate(Object? value, DateTime fallback) {
  return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
}

int _parseInt(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
