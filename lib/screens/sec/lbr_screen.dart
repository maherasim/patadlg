import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/lbr_case.dart';
import '../../services/lbr_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../lbr_detail_screen.dart';
import 'lbr_wizard_screen.dart';

const Map<String, Color> _kStatusTone = {
  'FORWARDED': AppColors.info,
  'PENDING_DDLG_APPROVAL': AppColors.info,
  'APPROVED': AppColors.success,
  'REJECTED': AppColors.danger,
  'RETURNED': AppColors.warning,
  'REGISTERED': AppColors.success,
};

class SecLbrScreen extends StatefulWidget {
  const SecLbrScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<SecLbrScreen> createState() => _SecLbrScreenState();
}

class _SecLbrScreenState extends State<SecLbrScreen> {
  bool _loading = true;
  String? _error;
  List<LbrCase> _cases = [];
  String _search = '';

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
      final cases = await LbrService.instance.indexForSecretary();
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load birth registration cases.";
        _loading = false;
      });
    }
  }

  List<LbrCase> get _filtered {
    if (_search.trim().isEmpty) return _cases;
    final q = _search.toLowerCase();
    return _cases.where((c) => c.lbrId.toLowerCase().contains(q) || c.childName.toLowerCase().contains(q) || c.applicantName.toLowerCase().contains(q)).toList();
  }

  Future<void> _openDetail(LbrCase c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LbrDetailScreen(role: 'sec', caseId: c.id, user: widget.user)));
    _load();
  }

  Future<void> _openNewCaseChooser() async {
    final category = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewCaseChooserSheet(),
    );
    if (category == null || !mounted) return;
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LbrWizardScreen(category: category)));
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Birth Registration'), actions: const [NotificationBell(), LogoutAction()]),
      drawer: AppDrawer(role: 'sec', currentKey: 'lbr', user: widget.user),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewCaseChooser,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Application'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                    children: [
                      Text('${_cases.length} applications from your UC', style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search LBR-ID, child, applicant…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No applications yet.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map((c) => _LbrTile(lbrCase: c, onTap: () => _openDetail(c))),
                    ],
                  ),
                ),
    );
  }
}

class _NewCaseChooserSheet extends StatelessWidget {
  const _NewCaseChooserSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          const Text('New Birth Registration', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text('Choose the delay category for this application.', style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
          const SizedBox(height: 18),
          _choice(context, '1-7', '1–7 Years', 'Reviewed and decided directly by ADLG.'),
          const SizedBox(height: 10),
          _choice(context, '7+', 'Over 7 Years', "ADLG reviews and forwards to DDLG for final approval."),
        ],
      ),
    );
  }

  Widget _choice(BuildContext context, String value, String title, String subtitle) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).pop(value),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.child_friendly_rounded, color: AppColors.primary500, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _LbrTile extends StatelessWidget {
  const _LbrTile({required this.lbrCase, required this.onTap});

  final LbrCase lbrCase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _kStatusTone[lbrCase.status] ?? AppColors.inkMuted;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary500.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('👶', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lbrCase.lbrId, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(lbrCase.childName, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(lbrCase.categoryLabel, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(lbrCase.statusLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
