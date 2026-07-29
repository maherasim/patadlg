import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../coming_soon_screen.dart';

class AdlgDashboardScreen extends StatefulWidget {
  const AdlgDashboardScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdlgDashboardScreen> createState() => _AdlgDashboardScreenState();
}

class _AdlgDashboardScreenState extends State<AdlgDashboardScreen> {
  bool _loading = true;
  String? _error;
  AdlgDashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await DashboardService.instance.adlgDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your dashboard.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Dashboard'), actions: const [NotificationBell(), LogoutAction()]),
      drawer: AppDrawer(role: 'adlg', currentKey: 'dashboard', user: widget.user),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator(strokeWidth: 2.4))])
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 100),
                    Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted))),
                  ])
                : _buildContent(context, _data!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AdlgDashboardData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text('Real-time snapshot of your tehsil.', style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
        const SizedBox(height: 14),
        if (data.pendingNewsletters > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: AppColors.accent100,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ComingSoonScreen(
                    role: 'adlg',
                    user: widget.user,
                    currentKey: 'newsletters',
                    title: 'Newsletters',
                    icon: Icons.newspaper_rounded,
                  ),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accent400.withValues(alpha: 0.4))),
                  child: Row(
                    children: [
                      const Icon(Icons.newspaper_rounded, size: 18, color: AppColors.accent600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${data.pendingNewsletters} newsletter${data.pendingNewsletters > 1 ? 's' : ''} awaiting your response',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.accent600),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.accent600),
                    ],
                  ),
                ),
              ),
            ),
          ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _KpiTile(icon: Icons.gavel_rounded, label: 'Active Cases', value: '${data.activeCases}', sub: '${data.totalCases} total filed', tone: AppColors.accent500),
            _KpiTile(
              icon: Icons.local_fire_department_rounded,
              label: 'Urgent Cases',
              value: '${data.urgentCases}',
              sub: '≤ 3 days remaining',
              tone: data.urgentCases > 0 ? AppColors.danger : AppColors.primary500,
            ),
            _KpiTile(
              icon: Icons.warning_amber_rounded,
              label: 'Vacant UCs',
              value: '${data.vacantUcs}',
              sub: 'No secretary assigned',
              tone: data.vacantUcs > 0 ? AppColors.danger : AppColors.primary500,
            ),
            _KpiTile(
              icon: Icons.fingerprint_rounded,
              label: "Today's Attendance",
              value: '${data.todayRate}%',
              sub: '${data.todayMarked} of ${data.todayTotal} secretaries',
              tone: data.todayRate >= 70 ? AppColors.primary500 : (data.todayRate >= 40 ? AppColors.accent500 : AppColors.danger),
            ),
          ],
        ).animate().fadeIn(duration: 350.ms),
        const SizedBox(height: 22),
        _SectionLabel('Case Pipeline'),
        const SizedBox(height: 10),
        _CasePipelineCard(stages: data.casePipeline),
        const SizedBox(height: 22),
        _SectionLabel('Attendance Trend · last 14 days'),
        const SizedBox(height: 10),
        _AttendanceTrendCard(points: data.attendanceTrend, marked: data.todayMarked, total: data.todayTotal, rate: data.todayRate),
        const SizedBox(height: 22),
        _SectionLabel('Quick Actions'),
        const SizedBox(height: 10),
        _QuickActionsCard(user: widget.user),
        const SizedBox(height: 22),
        _SectionLabel('My Recent Activity'),
        const SizedBox(height: 10),
        _RecentActivityCard(activity: data.recentActivity),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink));
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.icon, required this.label, required this.value, required this.tone, this.sub});

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: tone),
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tone)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (sub != null) Text(sub!, style: const TextStyle(fontSize: 9.5, color: AppColors.inkFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _CasePipelineCard extends StatelessWidget {
  const _CasePipelineCard({required this.stages});

  final List<CasePipelineStage> stages;

  @override
  Widget build(BuildContext context) {
    final maxCount = stages.fold<int>(1, (max, s) => s.count > max ? s.count : max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: stages.every((s) => s.count == 0)
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No Divorce/Khula cases filed yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint)),
            )
          : Column(
              children: stages.map((s) {
                final fraction = maxCount == 0 ? 0.0 : s.count / maxCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(s.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink))),
                          Text('${s.count}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary600)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 7,
                          backgroundColor: AppColors.primary50,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _AttendanceTrendCard extends StatelessWidget {
  const _AttendanceTrendCard({required this.points, required this.marked, required this.total, required this.rate});

  final List<AttendanceTrendPoint> points;
  final int marked;
  final int total;
  final int rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Today', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
              const Spacer(),
              Text('$marked / $total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: AppColors.primary50,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
            ),
          ),
          const SizedBox(height: 18),
          if (points.isEmpty)
            const Text('No attendance data yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint))
          else
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((p) {
                  final heightFraction = (p.rate / 100).clamp(0.03, 1.0);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Tooltip(
                        message: '${p.date}: ${p.rate}%',
                        child: FractionallySizedBox(
                          heightFactor: heightFraction,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary400,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.user});

  final Map<String, dynamic> user;

  static const _actions = [
    (navKey: 'cases', label: 'Review Cases', icon: Icons.gavel_rounded),
    (navKey: 'union-councils', label: 'New Union Council', icon: Icons.add_business_rounded),
    (navKey: 'secretaries', label: 'Create Secretary', icon: Icons.person_add_alt_1_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        children: _actions.map((a) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ComingSoonScreen(role: 'adlg', user: user, currentKey: a.navKey, title: a.label, icon: a.icon),
              )),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(a.icon, size: 18, color: AppColors.primary500),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink))),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkFaint),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activity});

  final List<DashboardActivity> activity;

  @override
  Widget build(BuildContext context) {
    final items = activity.take(8).toList();

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No recent activity yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint)),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: i == items.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.7)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(9)),
                          child: const Icon(Icons.history_rounded, size: 15, color: AppColors.primary500),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_actionLabel(items[i].action), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                              if (items[i].note != null && items[i].note!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(items[i].note!, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _actionLabel(String action) {
    return action.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }
}
