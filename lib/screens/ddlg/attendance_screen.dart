import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/attendance_record.dart';
import '../../models/union_council.dart';
import '../../services/attendance_service.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/export_download.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/status_badge.dart';
import '../../utils/time_format.dart';

String _fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// District-wide attendance — every secretary across every tehsil, view
/// only. No Live Map tab here: DDLG has no live-locations route on the
/// backend, matching ddlg/Attendance.jsx exactly (Attendance + Movement
/// Registry tabs only).
class DdlgAttendanceScreen extends StatefulWidget {
  const DdlgAttendanceScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DdlgAttendanceScreen> createState() => _DdlgAttendanceScreenState();
}

class _DdlgAttendanceScreenState extends State<DdlgAttendanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  List<AttendanceRecord> _records = [];
  AttendanceMeta? _meta;
  List<MovementLog> _movements = [];
  List<UnionCouncil> _unionCouncils = [];

  int? _filterUcId;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  bool _exportingAttendance = false;
  bool _exportingMovement = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AttendanceService.instance.indexForDdlg(
          unionCouncilId: _filterUcId,
          from: _filterFrom != null ? _fmtDate(_filterFrom!) : null,
          to: _filterTo != null ? _fmtDate(_filterTo!) : null,
        ),
        AttendanceService.instance.movementIndexForDdlg(),
        if (_unionCouncils.isEmpty) DirectoryService.instance.unionCouncilsForDdlg(),
      ]);
      if (!mounted) return;
      final (records, meta) = results[0] as (List<AttendanceRecord>, AttendanceMeta);
      setState(() {
        _records = records;
        _meta = meta;
        _movements = results[1] as List<MovementLog>;
        if (results.length > 2) _unionCouncils = results[2] as List<UnionCouncil>;
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
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All UCs')),
                    ..._unionCouncils.map((uc) => DropdownMenuItem(
                          value: uc.id,
                          child: Text(uc.ucNo != null ? '${uc.ucNo} · ${uc.name}' : uc.name, overflow: TextOverflow.ellipsis),
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
      final file = await AttendanceService.instance.exportAttendanceDdlg(
        unionCouncilId: _filterUcId,
        from: _filterFrom != null ? _fmtDate(_filterFrom!) : null,
        to: _filterTo != null ? _fmtDate(_filterTo!) : null,
      );
      if (mounted) await saveExportedFile(context, file);
    } catch (_) {
      if (mounted) _showExportError();
    } finally {
      if (mounted) setState(() => _exportingAttendance = false);
    }
  }

  Future<void> _exportMovementLog() async {
    setState(() => _exportingMovement = true);
    try {
      final file = await AttendanceService.instance.exportMovementLogDdlg();
      if (mounted) await saveExportedFile(context, file);
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
            Tab(text: 'Movement Log'),
          ],
        ),
      ),
      drawer: AppDrawer(role: 'ddlg', currentKey: 'attendance', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : TabBarView(
                  controller: _tabController,
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
          const Text('Every secretary across your district — view only', style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
          const SizedBox(height: 14),
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
