import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/inquiry.dart';
import '../../services/inquiry_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/case/document_preview.dart' show openDocument;
import '../../widgets/inquiry/submit_inquiry_sheet.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';

/// Inquiry Requests — every inquiry filed by an ADLG in the DDLG's district,
/// plus any the DDLG has filed themselves. Mirrors ddlg/Inquiries.jsx.
class DdlgInquiriesScreen extends StatefulWidget {
  const DdlgInquiriesScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DdlgInquiriesScreen> createState() => _DdlgInquiriesScreenState();
}

class _DdlgInquiriesScreenState extends State<DdlgInquiriesScreen> {
  bool _loading = true;
  String? _error;
  List<Inquiry> _inquiries = [];

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
      final inquiries = await InquiryService.instance.indexForDdlg();
      if (!mounted) return;
      setState(() {
        _inquiries = inquiries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load inquiries.";
        _loading = false;
      });
    }
  }

  Future<void> _openSubmit() async {
    final created = await showModalBottomSheet<Inquiry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SubmitInquirySheet(role: 'ddlg'),
    );
    if (created != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Inquiry Requests'),
        actions: [const NotificationBell(), const LogoutAction()],
      ),
      drawer: AppDrawer(role: 'ddlg', currentKey: 'inquiries', user: widget.user),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openSubmit, icon: const Icon(Icons.add_rounded), label: const Text('New Inquiry')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                    children: [
                      const Text("Every inquiry filed by an ADLG in your district, plus any you've filed yourself.", style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 14),
                      if (_inquiries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Column(
                              children: [
                                Text('📄', style: TextStyle(fontSize: 32)),
                                SizedBox(height: 10),
                                Text('No inquiries yet', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._inquiries.map((i) => _InquiryCard(i: i, showAdlg: true)),
                    ],
                  ),
                ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({required this.i, required this.showAdlg});

  final Inquiry i;
  final bool showAdlg;

  @override
  Widget build(BuildContext context) {
    final meta = [i.ref, i.unionCouncil ?? 'General', if (showAdlg && i.adlg != null) i.adlg!].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
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
                    Text(i.subject, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(meta, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: (i.drafted ? AppColors.success : AppColors.accent500).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(i.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: i.drafted ? AppColors.success : AppColors.accent600)),
              ),
            ],
          ),
          if ((i.remarks ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(i.remarks!, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
          ],
          if (i.fileUrl != null || i.reportFileUrl != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (i.fileUrl != null) _fileChip(context, icon: Icons.attach_file_rounded, label: 'File', url: i.fileUrl!),
                if (i.reportFileUrl != null) _fileChip(context, icon: Icons.download_rounded, label: 'Download Report', url: i.reportFileUrl!),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _fileChip(BuildContext context, {required IconData icon, required String label, required String url}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openDocument(context, url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary600),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary600)),
          ],
        ),
      ),
    );
  }
}
