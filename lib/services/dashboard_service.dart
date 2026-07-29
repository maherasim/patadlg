import 'package:dio/dio.dart';

import 'api_client.dart';

class SecDashboardSummary {
  SecDashboardSummary({
    required this.attendedToday,
    required this.reportedToday,
    required this.activeCases,
    required this.readyForArbitration,
  });

  final bool attendedToday;
  final bool reportedToday;
  final int activeCases;
  final int readyForArbitration;
}

class AttendanceTrendPoint {
  AttendanceTrendPoint({required this.date, required this.rate});

  factory AttendanceTrendPoint.fromJson(Map<String, dynamic> json) => AttendanceTrendPoint(
        date: json['date'] as String? ?? '',
        rate: (json['rate'] as num?)?.toInt() ?? 0,
      );

  final String date;
  final int rate;
}

class CasePipelineStage {
  CasePipelineStage({required this.key, required this.label, required this.count});

  factory CasePipelineStage.fromJson(Map<String, dynamic> json) => CasePipelineStage(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  final String key;
  final String label;
  final int count;
}

class DashboardActivity {
  DashboardActivity({required this.action, this.note, required this.createdAt});

  factory DashboardActivity.fromJson(Map<String, dynamic> json) => DashboardActivity(
        action: json['action'] as String? ?? '',
        note: json['note'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );

  final String action;
  final String? note;
  final String createdAt;
}

class AdlgDashboardData {
  AdlgDashboardData({
    required this.activeCases,
    required this.totalCases,
    required this.urgentCases,
    required this.vacantUcs,
    required this.pendingNewsletters,
    required this.todayMarked,
    required this.todayTotal,
    required this.todayRate,
    required this.attendanceTrend,
    required this.casePipeline,
    required this.recentActivity,
  });

  factory AdlgDashboardData.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    final todayAttendance = json['today_attendance'] as Map<String, dynamic>? ?? {};

    return AdlgDashboardData(
      activeCases: (kpis['active_cases'] as num?)?.toInt() ?? 0,
      totalCases: (kpis['total_cases'] as num?)?.toInt() ?? 0,
      urgentCases: (kpis['urgent_cases'] as num?)?.toInt() ?? 0,
      vacantUcs: (kpis['vacant_ucs'] as num?)?.toInt() ?? 0,
      pendingNewsletters: (kpis['pending_newsletters'] as num?)?.toInt() ?? 0,
      todayMarked: (todayAttendance['marked'] as num?)?.toInt() ?? 0,
      todayTotal: (todayAttendance['total'] as num?)?.toInt() ?? 0,
      todayRate: (todayAttendance['rate'] as num?)?.toInt() ?? 0,
      attendanceTrend: ((json['attendance_trend'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(AttendanceTrendPoint.fromJson)
          .toList(),
      casePipeline: ((json['case_pipeline'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(CasePipelineStage.fromJson)
          .toList(),
      recentActivity: ((json['recent_audit'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(DashboardActivity.fromJson)
          .toList(),
    );
  }

  final int activeCases;
  final int totalCases;
  final int urgentCases;
  final int vacantUcs;
  final int pendingNewsletters;
  final int todayMarked;
  final int todayTotal;
  final int todayRate;
  final List<AttendanceTrendPoint> attendanceTrend;
  final List<CasePipelineStage> casePipeline;
  final List<DashboardActivity> recentActivity;
}

/// Powers the mobile Dashboard tab for both roles — the Secretary summary is
/// computed client-side from the same three endpoints the web dashboard reads
/// (attendance/reports/cases), while ADLG has a dedicated aggregate endpoint.
class DashboardService {
  DashboardService._();

  static final DashboardService instance = DashboardService._();

  Dio get _dio => ApiClient.instance.dio;

  static const _closedCaseStatuses = ['DISPOSED_RECONCILED', 'DISPOSED_EFFECTIVE', 'FILED_NON_RESPONSE'];

  /// Each source is fetched and parsed independently — one section having bad
  /// data (or a transient failure) shouldn't blank the whole dashboard when
  /// the other two are perfectly fine. Only truly missing data reads as 0/false.
  Future<SecDashboardSummary> secSummary() async {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    var attendedToday = false;
    var reportedToday = false;
    var activeCases = 0;
    var readyForArbitration = 0;
    var allFailed = true;

    try {
      final response = await _dio.get('/api/sec/attendance');
      final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
      attendedToday = list.any((r) => r['attendance_date'] == todayStr);
      allFailed = false;
    } catch (_) {
      // Leave attendedToday at its default; other sections still load.
    }

    try {
      final response = await _dio.get('/api/sec/reports');
      final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
      reportedToday = list.any((r) => r['report_date'] == todayStr);
      allFailed = false;
    } catch (_) {
      // Leave reportedToday at its default; other sections still load.
    }

    try {
      final response = await _dio.get('/api/sec/cases');
      final list = (response.data['data'] as List).cast<Map<String, dynamic>>();
      activeCases = list.where((c) => !_closedCaseStatuses.contains(c['status'])).length;
      readyForArbitration = list.where((c) => c['status'] == 'NOTICE_ISSUED').length;
      allFailed = false;
    } catch (_) {
      // Leave case counts at their default; other sections still load.
    }

    if (allFailed) {
      throw DioException(requestOptions: RequestOptions(path: '/api/sec/dashboard-summary'));
    }

    return SecDashboardSummary(
      attendedToday: attendedToday,
      reportedToday: reportedToday,
      activeCases: activeCases,
      readyForArbitration: readyForArbitration,
    );
  }

  Future<AdlgDashboardData> adlgDashboard() async {
    final response = await _dio.get('/api/adlg/dashboard');
    return AdlgDashboardData.fromJson(response.data as Map<String, dynamic>);
  }
}
