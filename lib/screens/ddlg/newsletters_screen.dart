import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/newsletter.dart';
import '../../services/newsletter_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/case/document_preview.dart' show openDocument;
import '../../widgets/logout_action.dart';
import '../../widgets/newsletter/respond_sheet.dart';
import '../../widgets/notification_bell.dart';

Map<String, ({String label, Color dot, Color border, Color chipBg, Color chipText})> get _kPriority => {
      'urgent': (label: 'Urgent', dot: AppColors.danger, border: AppColors.danger, chipBg: AppColors.danger.withValues(alpha: 0.08), chipText: AppColors.danger),
      'normal': (label: 'General', dot: AppColors.primary500, border: AppColors.primary500, chipBg: AppColors.primary50, chipText: AppColors.primary700),
      'info': (label: 'Info', dot: AppColors.info, border: AppColors.info, chipBg: AppColors.info.withValues(alpha: 0.08), chipText: AppColors.info),
    };

/// Directives & Newsletters — official circulars published by the Super
/// Admin, mirrors ddlg/Newsletters.jsx.
class DdlgNewslettersScreen extends StatefulWidget {
  const DdlgNewslettersScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DdlgNewslettersScreen> createState() => _DdlgNewslettersScreenState();
}

class _DdlgNewslettersScreenState extends State<DdlgNewslettersScreen> {
  bool _loading = true;
  String? _error;
  List<Newsletter> _newsletters = [];

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
      final newsletters = await NewsletterService.instance.indexForDdlg();
      if (!mounted) return;
      setState(() {
        _newsletters = newsletters;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load newsletters.";
        _loading = false;
      });
    }
  }

  Future<void> _openRespond(Newsletter n) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewsletterRespondSheet(role: 'ddlg', newsletter: n),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _newsletters.where((n) => !n.responded).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Directives & Newsletters'),
        actions: [const NotificationBell(), const LogoutAction()],
      ),
      drawer: AppDrawer(role: 'ddlg', currentKey: 'newsletters', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Official circulars published by the Super Admin', style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted))),
                          if (pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
                              child: Text('$pendingCount awaiting response', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_newsletters.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Text('📰', style: TextStyle(fontSize: 32)),
                                SizedBox(height: 10),
                                Text('No newsletters yet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                                SizedBox(height: 4),
                                Text('Directives published by the Super Admin will appear here.', style: TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._newsletters.map((n) => _NewsletterCard(n: n, onRespond: () => _openRespond(n))),
                    ],
                  ),
                ),
    );
  }
}

class _NewsletterCard extends StatelessWidget {
  const _NewsletterCard({required this.n, required this.onRespond});

  final Newsletter n;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final p = _kPriority[n.priority] ?? _kPriority['normal']!;
    final respondedOption = n.responded ? n.options.where((o) => o.id == n.myResponse!.optionId).firstOrNull : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: p.border),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(color: p.dot, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: p.chipBg, borderRadius: BorderRadius.circular(20)),
                                      child: Text(p.label.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: p.chipText, letterSpacing: 0.4)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(n.subject, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                                const SizedBox(height: 3),
                                Text('Office of the Super Admin · ${_fmtDate(n.publishedAt)}', style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: n.responded ? AppColors.primary50 : AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: n.responded ? AppColors.primary100 : AppColors.danger.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(n.responded ? Icons.check_circle_rounded : Icons.schedule_rounded, size: 12, color: n.responded ? AppColors.primary700 : AppColors.danger),
                                const SizedBox(width: 3),
                                Text(n.responded ? 'Responded' : 'Action Needed', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: n.responded ? AppColors.primary700 : AppColors.danger)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(12)),
                        child: Text(n.body, style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.ink)),
                      ),
                      if (n.attachmentUrl != null) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => openDocument(context, n.attachmentUrl!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.info.withValues(alpha: 0.25))),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download_rounded, size: 13, color: AppColors.info),
                                SizedBox(width: 5),
                                Text('Download Attachment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.info)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(color: AppColors.surfaceSubtle, border: Border(top: BorderSide(color: AppColors.border))),
                  child: n.responded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YOUR RESPONSE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary600, letterSpacing: 0.4)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                                  child: Text(respondedOption?.label ?? '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.info)),
                                ),
                                if (n.myResponse?.respondedAt != null) Text(_fmtDate(n.myResponse!.respondedAt!), style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                              ],
                            ),
                            if ((n.myResponse?.remarks ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('"${n.myResponse!.remarks}"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.inkMuted)),
                            ],
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(onPressed: onRespond, child: const Text('Respond to this Directive')),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $hour12:${d.minute.toString().padLeft(2, '0')} $ampm';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
