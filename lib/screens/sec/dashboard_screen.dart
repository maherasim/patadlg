import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import 'attendance_screen.dart';
import 'biometric_enrollment_screen.dart';
import 'reports_screen.dart';

class SecDashboardScreen extends StatefulWidget {
  const SecDashboardScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<SecDashboardScreen> createState() => _SecDashboardScreenState();
}

class _SecDashboardScreenState extends State<SecDashboardScreen> {
  bool _loading = true;
  String? _error;
  SecDashboardSummary? _summary;

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
      final summary = await DashboardService.instance.secSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
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
    final name = (widget.user['name'] as String?)?.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Dashboard'), actions: const [NotificationBell(), LogoutAction()]),
      drawer: AppDrawer(role: 'sec', currentKey: 'dashboard', user: widget.user),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 220), Center(child: CircularProgressIndicator(strokeWidth: 2.4))])
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 100),
                    Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted))),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      if (name != null)
                        Text('Welcome back, $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink))
                            .animate()
                            .fadeIn(duration: 300.ms),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          _KpiTile(
                            icon: Icons.fingerprint_rounded,
                            label: "Today's Attendance",
                            value: _summary!.attendedToday ? 'Marked' : 'Pending',
                            tone: _summary!.attendedToday ? AppColors.success : AppColors.danger,
                          ),
                          _KpiTile(
                            icon: Icons.assignment_outlined,
                            label: "Today's Report",
                            value: _summary!.reportedToday ? 'Submitted' : 'Pending',
                            tone: _summary!.reportedToday ? AppColors.success : AppColors.accent500,
                          ),
                          _KpiTile(
                            icon: Icons.gavel_rounded,
                            label: 'Active Cases',
                            value: '${_summary!.activeCases}',
                            tone: AppColors.info,
                          ),
                          _KpiTile(
                            icon: Icons.hourglass_bottom_rounded,
                            label: 'Ready for Arbitration',
                            value: '${_summary!.readyForArbitration}',
                            sub: 'Notice issued',
                            tone: _summary!.readyForArbitration > 0 ? AppColors.accent500 : AppColors.primary500,
                          ),
                        ],
                      ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
                      const SizedBox(height: 22),
                      if (!_summary!.attendedToday)
                        _ActionCard(
                          icon: Icons.fingerprint_rounded,
                          title: "Mark today's attendance",
                          subtitle: 'Tap to check in with geofence verification',
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => SecAttendanceScreen(user: widget.user)),
                          ),
                        ),
                      if (!_summary!.reportedToday) ...[
                        const SizedBox(height: 12),
                        _ActionCard(
                          icon: Icons.assignment_outlined,
                          title: "Submit today's report",
                          subtitle: 'Daily remarks and activity counters',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SecReportsScreen(user: widget.user)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _ActionCard(
                        icon: Icons.fingerprint_rounded,
                        title: 'Re-register fingerprint',
                        subtitle: 'Switched phones, or need to register again? Tap here.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => BiometricEnrollmentScreen(user: widget.user)),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
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
          if (sub != null) Text(sub!, style: const TextStyle(fontSize: 10, color: AppColors.inkFaint)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary500, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
