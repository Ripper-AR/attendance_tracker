import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AttendanceStore extends ChangeNotifier {
  AttendanceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _membersKey = 'attendance_tracker_members_v1';
  static const _attendanceKey = 'attendance_tracker_attendance_v1';

  final SharedPreferencesAsync _preferences;
  final Uuid _uuid = const Uuid();

  bool _isLoading = true;
  String? _errorMessage;
  List<Member> _members = <Member>[];
  List<AttendanceRecord> _attendance = <AttendanceRecord>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Member> get members {
    final sortedMembers = List<Member>.from(_members);
    sortedMembers.sort((a, b) => a.name.compareTo(b.name));
    return List<Member>.unmodifiable(sortedMembers);
  }

  List<AttendanceRecord> get attendance {
    final sortedAttendance = List<AttendanceRecord>.from(_attendance);
    sortedAttendance.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return List<AttendanceRecord>.unmodifiable(sortedAttendance);
  }

  int get totalMembers => _members.length;

  int get activeMembers {
    return _members.where((member) {
      final attendanceCount = attendanceCountFor(member.id);
      return member.subscriptionState(attendanceCount) !=
          SubscriptionState.expired;
    }).length;
  }

  int get expiredMembers {
    return _members.where((member) {
      final attendanceCount = attendanceCountFor(member.id);
      return member.subscriptionState(attendanceCount) ==
          SubscriptionState.expired;
    }).length;
  }

  int get todayAttendance {
    final today = dateKey(DateTime.now());
    return _attendance.where((record) => record.dayKey == today).length;
  }

  List<AttendanceRecord> get todayAttendanceRecords {
    final today = dateKey(DateTime.now());
    final records = _attendance
        .where((record) => record.dayKey == today)
        .toList();
    records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return List<AttendanceRecord>.unmodifiable(records);
  }

  List<AttendanceRecord> todayAttendanceRecordsFor(AttendanceTrack track) {
    final records = todayAttendanceRecords
        .where((record) => record.track == track)
        .toList();
    return List<AttendanceRecord>.unmodifiable(records);
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadPersistedData();
    } catch (error) {
      _errorMessage = 'تعذر تحميل البيانات المحلية';
      debugPrint('Local load failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFromStorage() async {
    try {
      await _loadPersistedData();
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      debugPrint('Local refresh failed: $error');
    }
  }

  Member? memberById(String id) {
    for (final member in _members) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
  }

  Member? memberByQrToken(String qrToken) {
    final normalizedToken = qrToken.trim();
    for (final member in _members) {
      if (member.qrToken == normalizedToken) {
        return member;
      }
    }
    return null;
  }

  int attendanceCountFor(String memberId) {
    return _attendance.where((record) => record.memberId == memberId).length;
  }

  List<AttendanceRecord> attendanceFor(String memberId) {
    final records = _attendance
        .where((record) => record.memberId == memberId)
        .toList();
    records.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return List<AttendanceRecord>.unmodifiable(records);
  }

  Future<Member> createMember({
    required String name,
    required String phone,
    required String subscriptionType,
    required double amount,
    required DateTime paymentDate,
    required int totalSessions,
  }) async {
    final now = DateTime.now();
    final member = Member(
      id: _uuid.v4(),
      qrToken: 'ATT-${_uuid.v4()}',
      name: name.trim(),
      phone: phone.trim(),
      subscriptionType: subscriptionType.trim(),
      amount: amount,
      paymentDate: dateOnly(paymentDate),
      totalSessions: totalSessions,
      createdAt: now,
    );

    _members = <Member>[..._members, member];
    await _persist();
    notifyListeners();
    return member;
  }

  Future<void> updateMember(Member updatedMember) async {
    _members = _members
        .map((member) => member.id == updatedMember.id ? updatedMember : member)
        .toList();
    await _persist();
    notifyListeners();
  }

  Future<Member?> renewMember({
    required String memberId,
    required String subscriptionType,
    required double amount,
    required DateTime renewalStartDate,
    required int addedSessions,
  }) async {
    final member = memberById(memberId);
    if (member == null) {
      return null;
    }

    final normalizedSubscriptionType = subscriptionType.trim();
    final attendanceCount = attendanceCountFor(member.id);
    final isRenewingSessionPackage = isSessionCountSubscription(
      normalizedSubscriptionType,
    );
    final currentRemainingSessions = member.isSessionCountBased
        ? member.remainingSessions(attendanceCount)
        : 0;
    final totalSessions = isRenewingSessionPackage
        ? attendanceCount + currentRemainingSessions + addedSessions
        : 0;
    final updatedMember = member.copyWith(
      subscriptionType: normalizedSubscriptionType,
      amount: amount,
      paymentDate: dateOnly(renewalStartDate),
      totalSessions: totalSessions,
    );

    await updateMember(updatedMember);
    return updatedMember;
  }

  Future<void> deleteMember(String id) async {
    _members = _members.where((member) => member.id != id).toList();
    _attendance = _attendance.where((record) => record.memberId != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<ScanResult> registerScan(
    String rawQrValue, {
    AttendanceTrack track = AttendanceTrack.launch,
  }) async {
    final qrToken = rawQrValue.trim();
    if (qrToken.isEmpty) {
      return const ScanResult(type: ScanResultType.empty);
    }

    final member = memberByQrToken(qrToken);
    if (member == null) {
      return const ScanResult(type: ScanResultType.notFound);
    }

    final attendanceCount = attendanceCountFor(member.id);
    if (member.subscriptionState(attendanceCount) ==
        SubscriptionState.expired) {
      return ScanResult(
        type: ScanResultType.expired,
        member: member,
        attendanceCount: attendanceCount,
      );
    }

    final record = AttendanceRecord(
      id: _uuid.v4(),
      memberId: member.id,
      scannedAt: DateTime.now(),
      track: track,
    );

    _attendance = <AttendanceRecord>[..._attendance, record];
    await _persist();
    notifyListeners();

    return ScanResult(
      type: ScanResultType.success,
      member: member,
      attendanceCount: attendanceCountFor(member.id),
    );
  }

  Future<void> _loadPersistedData() async {
    final membersJson = await _preferences.getString(_membersKey);
    final attendanceJson = await _preferences.getString(_attendanceKey);

    _members = _decodeList(membersJson)
        .map((json) => Member.fromJson(json))
        .where((member) => member.id.isNotEmpty && member.qrToken.isNotEmpty)
        .toList();

    _attendance = _decodeList(attendanceJson)
        .map((json) => AttendanceRecord.fromJson(json))
        .where((record) => record.id.isNotEmpty && record.memberId.isNotEmpty)
        .toList();
  }

  Future<void> _persist() async {
    final membersJson = jsonEncode(
      _members.map((member) => member.toJson()).toList(),
    );
    final attendanceJson = jsonEncode(
      _attendance.map((record) => record.toJson()).toList(),
    );

    await _preferences.setString(_membersKey, membersJson);
    await _preferences.setString(_attendanceKey, attendanceJson);
  }

  List<Map<String, Object?>> _decodeList(String? source) {
    if (source == null || source.isEmpty) {
      return <Map<String, Object?>>[];
    }

    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return <Map<String, Object?>>[];
    }

    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (item) => item.map(
            (key, value) => MapEntry<String, Object?>(key.toString(), value),
          ),
        )
        .toList();
  }
}
