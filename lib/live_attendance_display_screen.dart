import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;

import 'attendance_store.dart';
import 'models.dart';

const String _appBrandImageAsset = 'assets/images/app_logo.jpeg';

enum LiveAttendanceDisplayMode { beginnersSchool, generalAttendance }

class LiveAttendanceDisplayScreen extends StatefulWidget {
  const LiveAttendanceDisplayScreen({required this.store, super.key});

  final AttendanceStore store;

  @override
  State<LiveAttendanceDisplayScreen> createState() =>
      _LiveAttendanceDisplayScreenState();
}

class _LiveAttendanceDisplayScreenState
    extends State<LiveAttendanceDisplayScreen> {
  late DateTime _now;
  late LiveAttendanceDisplayMode _mode;
  Timer? _clockTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _now = cairoNow();
    _mode = isBeginnersSchoolDay(_now)
        ? LiveAttendanceDisplayMode.beginnersSchool
        : LiveAttendanceDisplayMode.generalAttendance;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = cairoNow());
      }
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(widget.store.refreshFromStorage());
    });
    unawaited(widget.store.refreshFromStorage());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pollTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _displayTheme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF070A12),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final records = widget.store.todayAttendanceRecords.reversed
                  .toList();

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    LiveAttendanceHeader(
                      now: _now,
                      totalCount: records.length,
                      mode: _mode,
                      isBeginnersDay: isBeginnersSchoolDay(_now),
                      onModeChanged: (mode) => setState(() => _mode = mode),
                      onClose: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child:
                            _mode == LiveAttendanceDisplayMode.beginnersSchool
                            ? SplitBeginnersAttendanceBoard(
                                key: const ValueKey<String>('beginners'),
                                records: records,
                                store: widget.store,
                              )
                            : GeneralAttendanceBoard(
                                key: const ValueKey<String>('general'),
                                records: records,
                                store: widget.store,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LiveAttendanceHeader extends StatelessWidget {
  const LiveAttendanceHeader({
    required this.now,
    required this.totalCount,
    required this.mode,
    required this.isBeginnersDay,
    required this.onModeChanged,
    required this.onClose,
    super.key,
  });

  final DateTime now;
  final int totalCount;
  final LiveAttendanceDisplayMode mode;
  final bool isBeginnersDay;
  final ValueChanged<LiveAttendanceDisplayMode> onModeChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1180;
        final identity = Expanded(
          child: HeaderIdentity(isBeginnersDay: isBeginnersDay),
        );
        final compactControls = <Widget>[
          TotalCheckedInBadge(totalCount: totalCount),
          LiveClockBadge(now: now),
          DisplayModeSwitch(mode: mode, onModeChanged: onModeChanged),
        ];
        final controls = <Widget>[
          compactControls[0],
          const SizedBox(width: 12),
          compactControls[1],
          const SizedBox(width: 12),
          compactControls[2],
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'رجوع',
            onPressed: onClose,
            icon: const Icon(Icons.close_fullscreen),
          ),
        ];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF10131F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        identity,
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          tooltip: 'رجوع',
                          onPressed: onClose,
                          icon: const Icon(Icons.close_fullscreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      children: compactControls,
                    ),
                  ],
                )
              : Row(children: <Widget>[identity, ...controls]),
        );
      },
    );
  }
}

class HeaderIdentity extends StatelessWidget {
  const HeaderIdentity({required this.isBeginnersDay, super.key});

  final bool isBeginnersDay;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            _appBrandImageAsset,
            width: 58,
            height: 58,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'مدرسة المبتدئين - كشف الحضور المباشر',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isBeginnersDay
                    ? 'اليوم: مدرسة المبتدئين'
                    : 'اليوم: الحضور العام',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TotalCheckedInBadge extends StatelessWidget {
  const TotalCheckedInBadge({required this.totalCount, super.key});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'إجمالي الحضور',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            totalCount.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveClockBadge extends StatelessWidget {
  const LiveClockBadge({required this.now, super.key});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            intl.DateFormat('EEEE، d MMMM yyyy', 'ar_EG').format(now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            intl.DateFormat('hh:mm:ss a', 'ar_EG').format(now),
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class DisplayModeSwitch extends StatelessWidget {
  const DisplayModeSwitch({
    required this.mode,
    required this.onModeChanged,
    super.key,
  });

  final LiveAttendanceDisplayMode mode;
  final ValueChanged<LiveAttendanceDisplayMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<LiveAttendanceDisplayMode>(
      selected: <LiveAttendanceDisplayMode>{mode},
      showSelectedIcon: false,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF07110C);
          }
          return Colors.white;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFA7F3D0);
          }
          return const Color(0xFF111827);
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
      ),
      onSelectionChanged: (selection) => onModeChanged(selection.first),
      segments: const <ButtonSegment<LiveAttendanceDisplayMode>>[
        ButtonSegment<LiveAttendanceDisplayMode>(
          value: LiveAttendanceDisplayMode.beginnersSchool,
          icon: Icon(Icons.dashboard_customize_outlined),
          label: Text('مدرسة المبتدئين'),
        ),
        ButtonSegment<LiveAttendanceDisplayMode>(
          value: LiveAttendanceDisplayMode.generalAttendance,
          icon: Icon(Icons.groups_2_outlined),
          label: Text('الحضور العام'),
        ),
      ],
    );
  }
}

class SplitBeginnersAttendanceBoard extends StatelessWidget {
  const SplitBeginnersAttendanceBoard({
    required this.records,
    required this.store,
    super.key,
  });

  final List<AttendanceRecord> records;
  final AttendanceStore store;

  @override
  Widget build(BuildContext context) {
    final launchRecords = records
        .where((record) => record.track == AttendanceTrack.launch)
        .toList();
    final roundsRecords = records
        .where((record) => record.track == AttendanceTrack.rounds)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final panels = <Widget>[
          Expanded(
            child: AttendanceTrackColumn(
              title: 'لانش (Launch)',
              icon: Icons.rocket_launch_outlined,
              accentColor: const Color(0xFF22C55E),
              records: launchRecords,
              store: store,
              emptyText: 'لا يوجد حضور لانش حتى الآن',
            ),
          ),
          const SizedBox(width: 18, height: 18),
          Expanded(
            child: AttendanceTrackColumn(
              title: 'راوندز (Rounds)',
              icon: Icons.sync_alt,
              accentColor: const Color(0xFFF59E0B),
              records: roundsRecords,
              store: store,
              emptyText: 'لا يوجد حضور راوندز حتى الآن',
            ),
          ),
        ];

        if (compact) {
          return Column(children: panels);
        }

        return Row(textDirection: TextDirection.rtl, children: panels);
      },
    );
  }
}

class AttendanceTrackColumn extends StatelessWidget {
  const AttendanceTrackColumn({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.records,
    required this.store,
    required this.emptyText,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<AttendanceRecord> records;
  final AttendanceStore store;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.42)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.32)),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, color: accentColor, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                CountBadge(count: records.length, color: accentColor),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? EmptyAttendancePanel(text: emptyText, color: accentColor)
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final member = store.memberById(record.memberId);

                        return LiveAttendeeCard(
                          key: ValueKey<String>(record.id),
                          record: record,
                          member: member,
                          sequenceNumber: index + 1,
                          accentColor: accentColor,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({required this.count, required this.color, super.key});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'العدد: $count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class GeneralAttendanceBoard extends StatelessWidget {
  const GeneralAttendanceBoard({
    required this.records,
    required this.store,
    super.key,
  });

  final List<AttendanceRecord> records;
  final AttendanceStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.groups_2_outlined,
                  color: Color(0xFF93C5FD),
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'الحضور العام اليوم',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                CountBadge(
                  count: records.length,
                  color: const Color(0xFF93C5FD),
                ),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? const EmptyAttendancePanel(
                    text: 'لا يوجد حضور مسجل اليوم',
                    color: Color(0xFF93C5FD),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 1500
                          ? 3
                          : constraints.maxWidth >= 960
                          ? 2
                          : 1;

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: crossAxisCount == 1 ? 5.7 : 4.8,
                        ),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          final member = store.memberById(record.memberId);
                          final accentColor =
                              record.track == AttendanceTrack.rounds
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF22C55E);

                          return LiveAttendeeCard(
                            key: ValueKey<String>(record.id),
                            record: record,
                            member: member,
                            sequenceNumber: index + 1,
                            accentColor: accentColor,
                            showTrack: true,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class LiveAttendeeCard extends StatelessWidget {
  const LiveAttendeeCard({
    required this.record,
    required this.member,
    required this.sequenceNumber,
    required this.accentColor,
    this.showTrack = false,
    super.key,
  });

  final AttendanceRecord record;
  final Member? member;
  final int sequenceNumber;
  final Color accentColor;
  final bool showTrack;

  @override
  Widget build(BuildContext context) {
    final member = this.member;
    final category = member?.subscriptionType ?? 'عضو غير موجود';
    final categoryColor = _membershipCategoryColor(category);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border(right: BorderSide(color: accentColor, width: 6)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            SequenceBadge(number: sequenceNumber, color: accentColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    member?.name ?? 'عضو غير موجود',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF0B1220),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      DisplayCategoryTag(
                        text: category,
                        color: categoryColor,
                        icon: Icons.card_membership,
                      ),
                      if (showTrack)
                        DisplayCategoryTag(
                          text: attendanceTrackLabel(record.track),
                          color: accentColor,
                          icon: record.track == AttendanceTrack.rounds
                              ? Icons.sync_alt
                              : Icons.rocket_launch_outlined,
                        ),
                      DisplayCategoryTag(
                        text: intl.DateFormat(
                          'hh:mm a',
                          'ar_EG',
                        ).format(record.scannedAt),
                        color: const Color(0xFF475569),
                        icon: Icons.schedule,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SequenceBadge extends StatelessWidget {
  const SequenceBadge({required this.number, required this.color, super.key});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '#$number',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class DisplayCategoryTag extends StatelessWidget {
  const DisplayCategoryTag({
    required this.text,
    required this.color,
    required this.icon,
    super.key,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyAttendancePanel extends StatelessWidget {
  const EmptyAttendancePanel({
    required this.text,
    required this.color,
    super.key,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hourglass_empty, color: color, size: 30),
            const SizedBox(width: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ThemeData _displayTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFA7F3D0),
      secondary: Color(0xFFFDE68A),
      surface: Color(0xFF10131F),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}

Color _membershipCategoryColor(String category) {
  final normalized = category.trim();
  if (normalized == beginnerCivilSubscriptionType) {
    return const Color(0xFF2563EB);
  }
  if (normalized == beginnerGuardSubscriptionType) {
    return const Color(0xFF047857);
  }
  if (normalized == beginnerPresidencySubscriptionType) {
    return const Color(0xFFC2410C);
  }
  if (normalized == privateSubscriptionType) {
    return const Color(0xFF7C3AED);
  }
  if (normalized == jumpingSubscriptionType) {
    return const Color(0xFFBE123C);
  }
  if (normalized == teamSubscriptionType) {
    return const Color(0xFF0891B2);
  }
  if (normalized == accommodationSubscriptionType) {
    return const Color(0xFF4B5563);
  }
  return const Color(0xFF334155);
}
