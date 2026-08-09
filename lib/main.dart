import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'attendance_store.dart';
import 'models.dart';

const String appBrandImageAsset = 'assets/images/app_logo.jpeg';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AttendanceStore _store;

  @override
  void initState() {
    super.initState();
    _store = AttendanceStore();
    _store.load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
    );

    return MaterialApp(
      title: 'Attendance Tracker',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const AppBackground(),
              child ?? const SizedBox.shrink(),
            ],
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          if (_store.isLoading) {
            return const LoadingScreen();
          }

          if (_store.errorMessage != null) {
            return ErrorScreen(
              message: _store.errorMessage!,
              onRetry: _store.load,
            );
          }

          return HomeScreen(store: _store);
        },
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF7F8FA),
      child: Opacity(
        opacity: 0.035,
        child: Image(image: AssetImage(appBrandImageAsset), fit: BoxFit.cover),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.store, super.key});

  final AttendanceStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final members = widget.store.members.where((member) {
          final query = _query.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return member.name.toLowerCase().contains(query) ||
              member.phone.toLowerCase().contains(query);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Attendance Tracker'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Scan QR',
                onPressed: () => _openScanner(context),
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openMemberForm(context),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('عضو جديد'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: <Widget>[
              DashboardGrid(
                store: widget.store,
                onOpenTodayAttendance: () => _openTodayAttendance(context),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'بحث بالاسم أو رقم التليفون',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              if (members.isEmpty)
                const EmptyMembersState()
              else
                ...members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MemberCard(
                      member: member,
                      attendanceCount: widget.store.attendanceCountFor(
                        member.id,
                      ),
                      onTap: () => _openProfile(context, member.id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScannerScreen(store: widget.store),
      ),
    );
  }

  void _openMemberForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberFormScreen(store: widget.store),
      ),
    );
  }

  void _openProfile(BuildContext context, String memberId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MemberProfileScreen(store: widget.store, memberId: memberId),
      ),
    );
  }

  void _openTodayAttendance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TodayAttendanceScreen(store: widget.store),
      ),
    );
  }
}

class DashboardGrid extends StatelessWidget {
  const DashboardGrid({
    required this.store,
    required this.onOpenTodayAttendance,
    super.key,
  });

  final AttendanceStore store;
  final VoidCallback onOpenTodayAttendance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 4 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: crossAxisCount == 4 ? 2.3 : 1.75,
          children: <Widget>[
            StatTile(
              label: 'الأعضاء',
              value: store.totalMembers.toString(),
              icon: Icons.groups_2_outlined,
              color: const Color(0xFF2563EB),
            ),
            StatTile(
              label: 'لديه حصص',
              value: store.activeMembers.toString(),
              icon: Icons.verified_user_outlined,
              color: const Color(0xFF0F766E),
            ),
            StatTile(
              label: 'خلصت حصصه',
              value: store.expiredMembers.toString(),
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFDC2626),
            ),
            StatTile(
              label: 'حضور اليوم',
              value: store.todayAttendance.toString(),
              icon: Icons.event_available_outlined,
              color: const Color(0xFF7C3AED),
              onTap: onOpenTodayAttendance,
            ),
          ],
        );
      },
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: Colors.black.withValues(alpha: 0.42),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyMembersState extends StatelessWidget {
  const EmptyMembersState({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.group_add_outlined,
              size: 46,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            Text(
              'لا يوجد أعضاء بعد',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class TodayAttendanceScreen extends StatelessWidget {
  const TodayAttendanceScreen({required this.store, super.key});

  final AttendanceStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final records = store.todayAttendanceRecords;

        return Scaffold(
          appBar: AppBar(title: const Text('حضور اليوم')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: <Widget>[
              Text(
                '${records.length} تسجيل حضور اليوم',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('لا يوجد حضور مسجل اليوم'),
                  ),
                )
              else
                ...records.map((record) {
                  final member = store.memberById(record.memberId);
                  final attendanceCount = member == null
                      ? 0
                      : store.attendanceCountFor(member.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TodayAttendanceTile(
                      record: record,
                      member: member,
                      attendanceCount: attendanceCount,
                      onTap: member == null
                          ? null
                          : () => _openProfile(context, member.id),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _openProfile(BuildContext context, String memberId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(store: store, memberId: memberId),
      ),
    );
  }
}

class TodayAttendanceTile extends StatelessWidget {
  const TodayAttendanceTile({
    required this.record,
    required this.member,
    required this.attendanceCount,
    required this.onTap,
    super.key,
  });

  final AttendanceRecord record;
  final Member? member;
  final int attendanceCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final member = this.member;
    if (member == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              const Icon(Icons.person_off_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text('عضو غير موجود - ${formatTime(record.scannedAt)}'),
              ),
            ],
          ),
        ),
      );
    }

    final remainingText = member.isSessionCountBased
        ? 'متبقي ${member.remainingSessions(attendanceCount)}'
        : subscriptionDaysText(member.daysUntilExpiry());
    final attendanceText = member.isSessionCountBased
        ? '$attendanceCount/${member.totalSessions} حضور'
        : '$attendanceCount حضور';
    final state = member.subscriptionState(attendanceCount);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(_memberInitial(member.name)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          member.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.black.withValues(alpha: 0.62),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SmallInfoPill(
                    text: formatTime(record.scannedAt),
                    icon: Icons.schedule,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  SubscriptionBadge(state: state),
                  SmallInfoPill(
                    text: member.subscriptionType,
                    icon: Icons.card_membership,
                  ),
                  SmallInfoPill(
                    text: attendanceText,
                    icon: Icons.fact_check_outlined,
                  ),
                  SmallInfoPill(
                    text: remainingText,
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  const MemberCard({
    required this.member,
    required this.attendanceCount,
    required this.onTap,
    super.key,
  });

  final Member member;
  final int attendanceCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = member.subscriptionState(attendanceCount);
    final remainingText = member.isSessionCountBased
        ? 'متبقي ${member.remainingSessions(attendanceCount)}'
        : subscriptionDaysText(member.daysUntilExpiry());
    final remainingIcon = member.isSessionCountBased
        ? Icons.event_available_outlined
        : Icons.event_busy_outlined;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text(_memberInitial(member.name)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        SubscriptionBadge(state: state),
                        SmallInfoPill(
                          text: member.subscriptionType,
                          icon: Icons.card_membership,
                        ),
                        SmallInfoPill(text: remainingText, icon: remainingIcon),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    member.isSessionCountBased
                        ? '$attendanceCount/${member.totalSessions}'
                        : attendanceCount.toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('حضر', style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmallInfoPill extends StatelessWidget {
  const SmallInfoPill({required this.text, required this.icon, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class SubscriptionBadge extends StatelessWidget {
  const SubscriptionBadge({required this.state, super.key});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final color = subscriptionColor(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(subscriptionIcon(state), size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            subscriptionLabel(state),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({required this.store, this.member, super.key});

  final AttendanceStore store;
  final Member? member;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _amountController;
  late final TextEditingController _totalSessionsController;
  late String _subscriptionType;
  late DateTime _paymentDate;
  bool _isSaving = false;

  bool get _isEditing => widget.member != null;
  bool get _isSessionCountBased =>
      isSessionCountSubscription(_subscriptionType);

  DateTime? get _calculatedExpiryDate {
    final durationMonths = subscriptionDurationMonths(_subscriptionType);
    if (durationMonths == null) {
      return null;
    }

    return addCalendarMonths(dateOnly(_paymentDate), durationMonths);
  }

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    final now = DateTime.now();

    _nameController = TextEditingController(text: member?.name ?? '');
    _phoneController = TextEditingController(text: member?.phone ?? '');
    _amountController = TextEditingController(
      text: member == null || member.amount == 0
          ? ''
          : _amountInputText(member.amount),
    );
    _totalSessionsController = TextEditingController(
      text: member == null || member.totalSessions == 0
          ? ''
          : member.totalSessions.toString(),
    );
    _subscriptionType = member?.subscriptionType ?? defaultSubscriptionTypes[0];
    _paymentDate = member?.paymentDate ?? now;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _totalSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionTypes = <String>{
      ...defaultSubscriptionTypes,
      _subscriptionType,
    }.toList();
    final isSessionCountBased = _isSessionCountBased;
    final calculatedExpiryDate = _calculatedExpiryDate;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'تعديل عضو' : 'عضو جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'اكتب اسم العضو';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'رقم التليفون',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'اكتب رقم التليفون';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _subscriptionType,
              items: subscriptionTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _subscriptionType = value);
                }
              },
              decoration: const InputDecoration(
                labelText: 'نوع الاشتراك',
                prefixIcon: Icon(Icons.card_membership),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: isSessionCountBased
                  ? TextInputAction.next
                  : TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (value) {
                final amount = _parseAmount(value);
                if (amount == null || amount < 0) {
                  return 'اكتب مبلغ صحيح';
                }
                return null;
              },
            ),
            if (isSessionCountBased) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                controller: _totalSessionsController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'عدد الحصص',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (value) {
                  final totalSessions = _parseSessions(value);
                  if (totalSessions == null || totalSessions <= 0) {
                    return 'اكتب عدد حصص صحيح';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 12),
            DateFieldTile(
              label: 'تاريخ السداد',
              date: _paymentDate,
              icon: Icons.receipt_long_outlined,
              onTap: () => _pickDate(
                initialDate: _paymentDate,
                onSelected: (date) => setState(() => _paymentDate = date),
              ),
            ),
            if (!isSessionCountBased &&
                calculatedExpiryDate != null) ...<Widget>[
              const SizedBox(height: 12),
              DateFieldTile(
                label: 'تاريخ الانتهاء',
                date: calculatedExpiryDate,
                icon: Icons.event_busy_outlined,
                onTap: null,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'حفظ التعديل' : 'حفظ العضو'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      onSelected(dateOnly(selectedDate));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final amount = _parseAmount(_amountController.text) ?? 0;
    final totalSessions = _isSessionCountBased
        ? _parseSessions(_totalSessionsController.text) ?? 0
        : 0;
    final member = widget.member;

    if (member == null) {
      await widget.store.createMember(
        name: _nameController.text,
        phone: _phoneController.text,
        subscriptionType: _subscriptionType,
        amount: amount,
        paymentDate: _paymentDate,
        totalSessions: totalSessions,
      );
    } else {
      await widget.store.updateMember(
        member.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          subscriptionType: _subscriptionType.trim(),
          amount: amount,
          paymentDate: dateOnly(_paymentDate),
          totalSessions: totalSessions,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    Navigator.of(context).pop();
  }

  double? _parseAmount(String? value) {
    final normalized = value?.replaceAll(',', '.').trim() ?? '';
    if (normalized.isEmpty) {
      return 0;
    }
    return double.tryParse(normalized);
  }

  int? _parseSessions(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }
}

class RenewSubscriptionScreen extends StatefulWidget {
  const RenewSubscriptionScreen({
    required this.store,
    required this.member,
    required this.attendanceCount,
    super.key,
  });

  final AttendanceStore store;
  final Member member;
  final int attendanceCount;

  @override
  State<RenewSubscriptionScreen> createState() =>
      _RenewSubscriptionScreenState();
}

class _RenewSubscriptionScreenState extends State<RenewSubscriptionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _addedSessionsController;
  late String _subscriptionType;
  late DateTime _renewalStartDate;
  bool _isSaving = false;

  bool get _isSessionCountBased =>
      isSessionCountSubscription(_subscriptionType);

  DateTime? get _calculatedExpiryDate {
    final durationMonths = subscriptionDurationMonths(_subscriptionType);
    if (durationMonths == null) {
      return null;
    }

    return addCalendarMonths(dateOnly(_renewalStartDate), durationMonths);
  }

  int get _currentRemainingSessions {
    return widget.member.remainingSessions(widget.attendanceCount);
  }

  int get _addedSessions {
    return _parseSessions(_addedSessionsController.text) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    _subscriptionType = member.subscriptionType.trim().isEmpty
        ? defaultSubscriptionTypes[0]
        : member.subscriptionType;
    _renewalStartDate = member.isSessionCountBased
        ? dateOnly(DateTime.now())
        : member.renewalStartDate();
    _amountController = TextEditingController(
      text: member.amount == 0 ? '' : _amountInputText(member.amount),
    );
    _addedSessionsController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addedSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionTypes = <String>{
      ...defaultSubscriptionTypes,
      _subscriptionType,
    }.toList();
    final isSessionCountBased = _isSessionCountBased;
    final calculatedExpiryDate = _calculatedExpiryDate;
    final addedSessions = _addedSessions;
    final remainingAfterRenewal = _currentRemainingSessions + addedSessions;

    return Scaffold(
      appBar: AppBar(title: const Text('تجديد الاشتراك')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            MemberHeaderCard(
              member: widget.member,
              attendanceCount: widget.attendanceCount,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _subscriptionType,
              items: subscriptionTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _subscriptionType = value;
                  _renewalStartDate = isSessionCountSubscription(value)
                      ? dateOnly(DateTime.now())
                      : widget.member.renewalStartDate();
                });
              },
              decoration: const InputDecoration(
                labelText: 'نوع التجديد',
                prefixIcon: Icon(Icons.card_membership),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: isSessionCountBased
                  ? TextInputAction.next
                  : TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (value) {
                final amount = _parseAmount(value);
                if (amount == null || amount < 0) {
                  return 'اكتب مبلغ صحيح';
                }
                return null;
              },
            ),
            if (isSessionCountBased) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                controller: _addedSessionsController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'حصص التجديد',
                  prefixIcon: Icon(Icons.add_card_outlined),
                ),
                validator: (value) {
                  final addedSessions = _parseSessions(value);
                  if (addedSessions == null || addedSessions <= 0) {
                    return 'اكتب عدد حصص صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      DetailRow(
                        icon: Icons.event_available_outlined,
                        label: 'الحصص المتبقية الآن',
                        value: _currentRemainingSessions.toString(),
                      ),
                      if (addedSessions > 0) ...<Widget>[
                        const Divider(height: 22),
                        DetailRow(
                          icon: Icons.autorenew,
                          label: 'بعد التجديد',
                          value: remainingAfterRenewal.toString(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DateFieldTile(
              label: isSessionCountBased ? 'تاريخ التجديد' : 'يبدأ من',
              date: _renewalStartDate,
              icon: Icons.receipt_long_outlined,
              onTap: () => _pickDate(
                initialDate: _renewalStartDate,
                onSelected: (date) => setState(() => _renewalStartDate = date),
              ),
            ),
            if (!isSessionCountBased &&
                calculatedExpiryDate != null) ...<Widget>[
              const SizedBox(height: 12),
              DateFieldTile(
                label: 'تاريخ الانتهاء الجديد',
                date: calculatedExpiryDate,
                icon: Icons.event_busy_outlined,
                onTap: null,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.autorenew),
              label: const Text('تجديد الاشتراك'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      onSelected(dateOnly(selectedDate));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final renewedMember = await widget.store.renewMember(
        memberId: widget.member.id,
        subscriptionType: _subscriptionType,
        amount: _parseAmount(_amountController.text) ?? 0,
        renewalStartDate: _renewalStartDate,
        addedSessions: _isSessionCountBased ? _addedSessions : 0,
      );

      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);

      if (renewedMember == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('العضو غير موجود')));
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Renew subscription failed: $error');
      if (!mounted) {
        return;
      }

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تجديد الاشتراك')));
    }
  }

  double? _parseAmount(String? value) {
    final normalized = value?.replaceAll(',', '.').trim() ?? '';
    if (normalized.isEmpty) {
      return 0;
    }
    return double.tryParse(normalized);
  }

  int? _parseSessions(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }
}

class DateFieldTile extends StatelessWidget {
  const DateFieldTile({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final DateTime date;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isInteractive = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black.withValues(alpha: 0.58),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatDate(date),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            Icon(
              isInteractive
                  ? Icons.calendar_month_outlined
                  : Icons.lock_clock_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({
    required this.store,
    required this.memberId,
    super.key,
  });

  final AttendanceStore store;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final member = store.memberById(memberId);
        if (member == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('العضو غير موجود')),
          );
        }

        final attendance = store.attendanceFor(member.id);
        final count = attendance.length;

        return Scaffold(
          appBar: AppBar(
            title: Text(member.name),
            actions: <Widget>[
              IconButton(
                tooltip: 'تجديد الاشتراك',
                onPressed: () => _openRenewalForm(context, member, count),
                icon: const Icon(Icons.autorenew),
              ),
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => _openEditForm(context, member),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () => _confirmDelete(context, member),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: <Widget>[
              MemberHeaderCard(member: member, attendanceCount: count),
              const SizedBox(height: 12),
              QrCard(member: member),
              const SizedBox(height: 12),
              SubscriptionDetailsCard(
                member: member,
                attendanceCount: count,
                onRenew: () => _openRenewalForm(context, member, count),
              ),
              const SizedBox(height: 12),
              Text(
                'سجل الحضور',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (attendance.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('لا يوجد حضور مسجل'),
                  ),
                )
              else
                ...attendance.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AttendanceRecordTile(record: record),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openRenewalForm(
    BuildContext context,
    Member member,
    int attendanceCount,
  ) async {
    final renewed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RenewSubscriptionScreen(
          store: store,
          member: member,
          attendanceCount: attendanceCount,
        ),
      ),
    );

    if (renewed == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تجديد الاشتراك')));
    }
  }

  void _openEditForm(BuildContext context, Member member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberFormScreen(store: store, member: member),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العضو'),
        content: Text('سيتم حذف ${member.name} وسجل حضوره.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await store.deleteMember(member.id);

    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class MemberHeaderCard extends StatelessWidget {
  const MemberHeaderCard({
    required this.member,
    required this.attendanceCount,
    super.key,
  });

  final Member member;
  final int attendanceCount;

  @override
  Widget build(BuildContext context) {
    final state = member.subscriptionState(attendanceCount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                _memberInitial(member.name),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(member.phone),
                  const SizedBox(height: 10),
                  SubscriptionBadge(state: state),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  attendanceCount.toString(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'حصة حضرها',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class QrCard extends StatelessWidget {
  const QrCard({required this.member, super.key});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: QrImageView(
                data: member.qrToken,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              member.qrToken,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionDetailsCard extends StatelessWidget {
  const SubscriptionDetailsCard({
    required this.member,
    required this.attendanceCount,
    required this.onRenew,
    super.key,
  });

  final Member member;
  final int attendanceCount;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final expiryDate = member.expiryDate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            DetailRow(
              icon: Icons.card_membership,
              label: 'نوع الاشتراك',
              value: member.subscriptionType,
            ),
            const Divider(height: 22),
            DetailRow(
              icon: Icons.payments_outlined,
              label: 'المبلغ',
              value: formatAmount(member.amount),
            ),
            const Divider(height: 22),
            DetailRow(
              icon: Icons.receipt_long_outlined,
              label: 'تاريخ السداد',
              value: formatDate(member.paymentDate),
            ),
            if (member.isSessionCountBased) ...<Widget>[
              const Divider(height: 22),
              DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: 'عدد الحصص',
                value: member.totalSessions.toString(),
              ),
              const Divider(height: 22),
              DetailRow(
                icon: Icons.event_available_outlined,
                label: 'الحصص المتبقية',
                value: member.remainingSessions(attendanceCount).toString(),
              ),
            ] else if (expiryDate != null) ...<Widget>[
              const Divider(height: 22),
              DetailRow(
                icon: Icons.event_busy_outlined,
                label: 'تاريخ الانتهاء',
                value:
                    '${formatDate(expiryDate)} - ${subscriptionDaysText(member.daysUntilExpiry())}',
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRenew,
              icon: const Icon(Icons.autorenew),
              label: const Text('تجديد الاشتراك'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({required this.record, super.key});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(formatDateTime(record.scannedAt)),
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({required this.store, super.key});

  final AttendanceStore store;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final TextEditingController _manualQrController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isHandlingScan = false;
  ScanResult? _lastResult;

  @override
  void initState() {
    super.initState();
    if (cameraScannerSupported) {
      _scannerController = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _manualQrController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR')),
      body: cameraScannerSupported ? _buildCameraScanner() : _buildManualScan(),
    );
  }

  Widget _buildCameraScanner() {
    return Stack(
      children: <Widget>[
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcodeCapture,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.1),
                  width: 12,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: ScanResultPanel(
            result: _lastResult,
            isWaiting: !_isHandlingScan,
            onScanAgain: _scanAgain,
            onRenewMember: _openRenewalForm,
          ),
        ),
      ],
    );
  }

  Widget _buildManualScan() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _manualQrController,
            decoration: const InputDecoration(
              labelText: 'QR Token',
              prefixIcon: Icon(Icons.qr_code_2),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isHandlingScan ? null : _submitManualScan,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('تسجيل حضور'),
          ),
          const SizedBox(height: 16),
          ScanResultPanel(
            result: _lastResult,
            isWaiting: false,
            onScanAgain: _scanAgain,
            onRenewMember: _openRenewalForm,
          ),
        ],
      ),
    );
  }

  Future<void> _handleBarcodeCapture(BarcodeCapture capture) async {
    if (_isHandlingScan || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;
    await _registerQrValue(rawValue ?? '');
  }

  Future<void> _submitManualScan() async {
    await _registerQrValue(_manualQrController.text);
  }

  Future<void> _registerQrValue(String rawValue) async {
    if (_isHandlingScan) {
      return;
    }

    setState(() => _isHandlingScan = true);
    await _scannerController?.stop();

    final result = await widget.store.registerScan(rawValue);

    if (!mounted) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _lastResult = result);
  }

  Future<void> _scanAgain() async {
    _manualQrController.clear();
    setState(() {
      _isHandlingScan = false;
      _lastResult = null;
    });
    await _scannerController?.start();
  }

  Future<void> _openRenewalForm(Member member) async {
    final renewed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RenewSubscriptionScreen(
          store: widget.store,
          member: member,
          attendanceCount: widget.store.attendanceCountFor(member.id),
        ),
      ),
    );

    if (renewed != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تجديد الاشتراك')));
    await _scanAgain();
  }
}

class ScanResultPanel extends StatelessWidget {
  const ScanResultPanel({
    required this.result,
    required this.isWaiting,
    required this.onScanAgain,
    required this.onRenewMember,
    super.key,
  });

  final ScanResult? result;
  final bool isWaiting;
  final VoidCallback onScanAgain;
  final ValueChanged<Member>? onRenewMember;

  @override
  Widget build(BuildContext context) {
    final result = this.result;

    if (result == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const Icon(Icons.qr_code_scanner),
              const SizedBox(width: 10),
              Expanded(
                child: Text(isWaiting ? 'جاهز للمسح' : 'بانتظار النتيجة'),
              ),
            ],
          ),
        ),
      );
    }

    final color = scanResultColor(result.type);
    final title = scanResultTitle(result);
    final subtitle = scanResultSubtitle(result);
    final expiredMember = result.type == ScanResultType.expired
        ? result.member
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(scanResultIcon(result.type), color: color, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(subtitle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.refresh),
              label: const Text('مسح آخر'),
            ),
            if (expiredMember != null && onRenewMember != null) ...<Widget>[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => onRenewMember!(expiredMember),
                icon: const Icon(Icons.autorenew),
                label: const Text('تجديد الاشتراك'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool get cameraScannerSupported {
  if (kIsWeb) {
    return true;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
  };
}

String _memberInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '؟';
  }
  return trimmed.substring(0, 1).toUpperCase();
}

String formatDate(DateTime date) {
  return intl.DateFormat('yyyy/MM/dd').format(date);
}

String formatDateTime(DateTime date) {
  return intl.DateFormat('yyyy/MM/dd - hh:mm a').format(date);
}

String formatTime(DateTime date) {
  return intl.DateFormat('hh:mm a').format(date);
}

String _amountInputText(double amount) {
  return amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
}

String formatAmount(double amount) {
  return '${intl.NumberFormat('#,##0.##').format(amount)} جنيه';
}

String subscriptionDaysText(int? daysLeft) {
  if (daysLeft == null) {
    return 'بدون تاريخ انتهاء';
  }

  if (daysLeft < 0) {
    return 'منتهي منذ ${daysLeft.abs()} يوم';
  }

  if (daysLeft == 0) {
    return 'ينتهي اليوم';
  }

  return 'متبقي $daysLeft يوم';
}

Color subscriptionColor(SubscriptionState state) {
  return switch (state) {
    SubscriptionState.active => const Color(0xFF0F766E),
    SubscriptionState.nearExpiry => const Color(0xFFD97706),
    SubscriptionState.expired => const Color(0xFFDC2626),
  };
}

IconData subscriptionIcon(SubscriptionState state) {
  return switch (state) {
    SubscriptionState.active => Icons.check_circle_outline,
    SubscriptionState.nearExpiry => Icons.timelapse_outlined,
    SubscriptionState.expired => Icons.error_outline,
  };
}

String subscriptionLabel(SubscriptionState state) {
  return switch (state) {
    SubscriptionState.active => 'ساري',
    SubscriptionState.nearExpiry => 'قرب الانتهاء',
    SubscriptionState.expired => 'منتهي',
  };
}

Color scanResultColor(ScanResultType type) {
  return switch (type) {
    ScanResultType.success => const Color(0xFF0F766E),
    ScanResultType.empty => const Color(0xFFD97706),
    ScanResultType.notFound => const Color(0xFFDC2626),
    ScanResultType.expired => const Color(0xFFDC2626),
  };
}

IconData scanResultIcon(ScanResultType type) {
  return switch (type) {
    ScanResultType.success => Icons.check_circle,
    ScanResultType.empty => Icons.qr_code_2,
    ScanResultType.notFound => Icons.search_off,
    ScanResultType.expired => Icons.error,
  };
}

String scanResultTitle(ScanResult result) {
  return switch (result.type) {
    ScanResultType.success => 'تم تسجيل الحضور',
    ScanResultType.empty => 'QR فارغ',
    ScanResultType.notFound => 'QR غير مسجل',
    ScanResultType.expired => 'الاشتراك منتهي',
  };
}

String? scanResultSubtitle(ScanResult result) {
  final member = result.member;

  return switch (result.type) {
    ScanResultType.success =>
      member == null
          ? 'تم تسجيل الحضور'
          : member.isSessionCountBased
          ? '${member.name} - عدد الحصص: ${result.attendanceCount}/${member.totalSessions}'
          : '${member.name} - عدد مرات الحضور: ${result.attendanceCount}',
    ScanResultType.empty => 'لم يتم قراءة بيانات من الكود',
    ScanResultType.notFound => 'لا يوجد عضو مرتبط بهذا الكود',
    ScanResultType.expired => '${member?.name ?? ''} يحتاج إلى تجديد الاشتراك',
  };
}
