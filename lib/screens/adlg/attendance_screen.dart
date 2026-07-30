import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/attendance_record.dart';
import '../../models/live_location.dart';
import '../../models/union_council.dart';
import '../../services/attendance_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/live_map/live_map_view.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/status_badge.dart';
import '../../utils/time_format.dart';

String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AdlgAttendanceScreen extends StatefulWidget {
  const AdlgAttendanceScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdlgAttendanceScreen> createState() => _AdlgAttendanceScreenState();
}

class _AdlgAttendanceScreenState extends State<AdlgAttendanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _liveMapTimer;

  bool _loading = true;
  String? _error;
  List<AttendanceRecord> _records = [];
  AttendanceMeta? _meta;
  List<MovementLog> _movements = [];
  List<LiveLocation> _liveLocations = [];
  List<Map<String, dynamic>> _ucOptions = [];

  int? _filterUcId;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  bool _exportingAttendance = false;
  bool _exportingMovement = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
    _liveMapTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshLiveLocations());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _liveMapTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AttendanceService.instance.indexForAdlg(
          unionCouncilId: _filterUcId,
          from: _filterFrom != null ? _fmtDate(_filterFrom!) : null,
          to: _filterTo != null ? _fmtDate(_filterTo!) : null,
        ),
        AttendanceService.instance.movementIndexForAdlg(),
        AttendanceService.instance.liveLocations(),
        if (_ucOptions.isEmpty) AttendanceService.instance.unionCouncilsForAdlg(),
      ]);
      if (!mounted) return;
      final (records, meta) = results[0] as (List<AttendanceRecord>, AttendanceMeta);
      setState(() {
        _records = records;
        _meta = meta;
        _movements = results[1] as List<MovementLog>;
        _liveLocations = results[2] as List<LiveLocation>;
        if (results.length > 3) _ucOptions = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load attendance data.";
        _loading = false;
      });
    }
  }

  Future<void> _refreshLiveLocations() async {
    try {
      final locations = await AttendanceService.instance.liveLocations();
      if (!mounted) return;
      setState(() => _liveLocations = locations);
    } catch (_) {
      // Best-effort periodic refresh.
    }
  }

  Future<void> _openFilterSheet() async {
    var ucId = _filterUcId;
    var from = _filterFrom;
    var to = _filterTo;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),
                const Text('Filter Attendance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 20),
                const Text('Union Council', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: ucId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All UCs')),
                    ..._ucOptions.map((uc) => DropdownMenuItem(
                          value: uc['id'] as int,
                          child: Text(uc['uc_no'] != null ? '${uc['uc_no']} · ${uc['name']}' : '${uc['name']}'),
                        )),
                  ],
                  onChanged: (v) => setSheetState(() => ucId = v),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _DatePickerField(label: 'From', value: from, onPick: (d) => setSheetState(() => from = d))),
                    const SizedBox(width: 12),
                    Expanded(child: _DatePickerField(label: 'To', value: to, onPick: (d) => setSheetState(() => to = d))),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() {
                          ucId = null;
                          from = null;
                          to = null;
                        }),
                        child: const Text('Clear'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filterUcId = ucId;
                            _filterFrom = from;
                            _filterTo = to;
                          });
                          Navigator.of(sheetContext).pop(true);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied == true) _loadAll();
  }

  Future<void> _exportAttendance() async {
    setState(() => _exportingAttendance = true);
    try {
      final file = await AttendanceService.instance.exportAttendance(
        unionCouncilId: _filterUcId,
        from: _filterFrom != null ? _fmtDate(_filterFrom!) : null,
        to: _filterTo != null ? _fmtDate(_filterTo!) : null,
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Attendance Export'));
    } catch (_) {
      if (mounted) _showExportError();
    } finally {
      if (mounted) setState(() => _exportingAttendance = false);
    }
  }

  Future<void> _exportMovementLog() async {
    setState(() => _exportingMovement = true);
    try {
      final file = await AttendanceService.instance.exportMovementLog();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Movement Registry'));
    } catch (_) {
      if (mounted) _showExportError();
    } finally {
      if (mounted) setState(() => _exportingMovement = false);
    }
  }

  void _showExportError() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't generate the export. Please try again.")));
  }

  bool get _hasActiveFilters => _filterUcId != null || _filterFrom != null || _filterTo != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: const [NotificationBell(), LogoutAction()],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary600,
          unselectedLabelColor: AppColors.inkFaint,
          indicatorColor: AppColors.primary500,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Live Map'),
            Tab(text: 'Movement Log'),
          ],
        ),
      ),
      drawer: AppDrawer(role: 'adlg', currentKey: 'attendance', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : TabBarView(
                  controller: _tabController,
                  // The Live Map tab needs its own drag gestures for panning —
                  // if TabBarView also claims horizontal drags, dragging the
                  // map gets misread as a swipe-to-next-tab. Tabs are still
                  // reachable via the tab bar above, just not by swiping.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _AttendanceTab(
                      records: _records,
                      meta: _meta,
                      hasActiveFilters: _hasActiveFilters,
                      exporting: _exportingAttendance,
                      onRefresh: _loadAll,
                      onOpenFilters: _openFilterSheet,
                      onExport: _exportAttendance,
                    ),
                    _LiveMapTab(
                      locations: _liveLocations,
                      unionCouncils: _ucOptions.map(UnionCouncil.fromJson).toList(),
                      onRefresh: _refreshLiveLocations,
                    ),
                    _MovementTab(
                      logs: _movements,
                      exporting: _exportingMovement,
                      onRefresh: _loadAll,
                      onExport: _exportMovementLog,
                    ),
                  ],
                ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.label, required this.value, required this.onPick});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 2),
              lastDate: now,
            );
            onPick(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Text(
              value != null ? _fmtDate(value!) : 'Any',
              style: TextStyle(fontSize: 13.5, color: value != null ? AppColors.ink : AppColors.inkFaint, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({
    required this.records,
    required this.meta,
    required this.hasActiveFilters,
    required this.exporting,
    required this.onRefresh,
    required this.onOpenFilters,
    required this.onExport,
  });

  final List<AttendanceRecord> records;
  final AttendanceMeta? meta;
  final bool hasActiveFilters;
  final bool exporting;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenFilters;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (meta != null)
            Row(
              children: [
                Expanded(child: _kpiTile('Today', '${meta!.today}', AppColors.primary500)),
                const SizedBox(width: 10),
                Expanded(child: _kpiTile('Total', '${meta!.total}', AppColors.info)),
                const SizedBox(width: 10),
                Expanded(child: _kpiTile('Filtered', '${meta!.filtered}', AppColors.accent500)),
              ],
            ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenFilters,
                  icon: Icon(Icons.filter_list_rounded, size: 18, color: hasActiveFilters ? AppColors.primary600 : null),
                  label: Text(hasActiveFilters ? 'Filters · Active' : 'Filters'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: exporting ? null : onExport,
                  icon: exporting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Export'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: Text('No attendance records yet.', style: TextStyle(color: AppColors.inkFaint))),
            )
          else
            ...records.map((r) => _RecordTile(record: r)),
        ],
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final statusColor = record.isLate ? AppColors.warning : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary50,
            backgroundImage: record.photoUrl != null ? NetworkImage(record.photoUrl!) : null,
            child: record.photoUrl == null ? const Icon(Icons.person_rounded, color: AppColors.primary500) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.secretary ?? '—', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  '${record.unionCouncil ?? ''} · ${record.attendanceDate ?? ''}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge(label: record.isLate ? 'Late' : 'Present', color: statusColor),
              const SizedBox(height: 4),
              Text(
                formatTime12h(record.checkInTime),
                style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A real OpenStreetMap-tiled live tracking view — secretary dots colored by
/// freshness + geofence status (see [LiveMapView]), each UC's geofence drawn
/// as a circle, and a short in-memory movement trail per secretary.
class _LiveMapTab extends StatelessWidget {
  const _LiveMapTab({required this.locations, required this.unionCouncils, required this.onRefresh});

  final List<LiveLocation> locations;
  final List<UnionCouncil> unionCouncils;
  final Future<void> Function() onRefresh;

  void _showDetails(BuildContext context, LiveLocation loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(loc.unionCouncil ?? '', style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(loc.fresh ? Icons.circle : Icons.circle_outlined, size: 10, color: loc.fresh ? AppColors.primary500 : AppColors.inkFaint),
                const SizedBox(width: 8),
                Text(
                  loc.fresh ? 'Live (<5 min ago)' : _minutesAgoLabel(loc.lastSeenAt),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${loc.lat.toStringAsFixed(5)}, ${loc.lng.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.inkFaint)),
            if (loc.accuracyMeters != null) ...[
              const SizedBox(height: 4),
              Text('±${loc.accuracyMeters!.round()}m accuracy', style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
            ],
          ],
        ),
      ),
    );
  }

  String _minutesAgoLabel(DateTime? lastSeen) {
    if (lastSeen == null) return 'Last seen unknown';
    return detailedTimeAgo(lastSeen);
  }

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Icon(Icons.location_off_rounded, size: 40, color: AppColors.inkFaint),
            SizedBox(height: 14),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'No live locations yet. Secretaries share their location automatically during working hours (Mon–Sat, 9AM–5PM).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkFaint, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final freshLocations = locations.where((l) => l.fresh).toList();
    final freshOutsideCount = freshLocations.where(_isOutside).length;
    final freshInsideCount = freshLocations.length - freshOutsideCount;
    final staleCount = locations.length - freshLocations.length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _legendDot(AppColors.primary500, 'Live, in UC: $freshInsideCount'),
                _legendDot(AppColors.danger, 'Live, outside UC: $freshOutsideCount'),
                _legendDot(AppColors.inkFaint, 'Older: $staleCount'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LiveMapView(
                  locations: locations,
                  unionCouncils: unionCouncils,
                  onTapLocation: (loc) => _showDetails(context, loc),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  bool _isOutside(LiveLocation loc) {
    UnionCouncil? uc;
    for (final u in unionCouncils) {
      if (u.id == loc.unionCouncilId) {
        uc = u;
        break;
      }
    }
    if (uc == null || !uc.hasGeofence) return false;
    return distanceMeters(loc.lat, loc.lng, uc.lat!, uc.lng!) > uc.geofenceRadius;
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MovementTab extends StatelessWidget {
  const _MovementTab({required this.logs, required this.exporting, required this.onRefresh, required this.onExport});

  final List<MovementLog> logs;
  final bool exporting;
  final Future<void> Function() onRefresh;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: exporting ? null : onExport,
              icon: exporting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Export'),
            ),
          ),
          const SizedBox(height: 14),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: Text('No movement logs yet.', style: TextStyle(color: AppColors.inkFaint))),
            )
          else
            ...logs.map((log) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: AppColors.accent100, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.directions_walk_rounded, color: AppColors.accent600, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${log.secretary ?? '—'} · ${log.reason}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            if (log.details != null && log.details!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(log.details!, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              log.unionCouncil ?? '',
                              style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
