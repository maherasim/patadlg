import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/daily_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';

String _todayStr() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class SecReportsScreen extends StatefulWidget {
  const SecReportsScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<SecReportsScreen> createState() => _SecReportsScreenState();
}

class _SecReportsScreenState extends State<SecReportsScreen> {
  bool _loading = true;
  String? _loadError;
  List<DailyReport> _history = [];
  List<ReportFieldDefinition> _adlgFields = [];

  final _remarksController = TextEditingController();
  int _nikah = 0;
  int _birth = 0;
  int _death = 0;
  int _complaint = 0;
  final Map<int, TextEditingController> _fieldControllers = {};
  final List<CustomFieldInput> _customFields = [];
  XFile? _attachment;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _submittedToday => _history.any((r) => r.reportDate == _todayStr());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ReportService.instance.myHistory(),
        ReportService.instance.fieldsForSecretary(),
      ]);
      if (!mounted) return;
      final fields = results[1] as List<ReportFieldDefinition>;
      for (final field in fields) {
        _fieldControllers.putIfAbsent(field.id, () => TextEditingController());
      }
      setState(() {
        _history = results[0] as List<DailyReport>;
        _adlgFields = fields;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = "Couldn't load your reports.";
        _loading = false;
      });
    }
  }

  Future<void> _pickAttachment() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _attachment = file);
  }

  Future<void> _submit() async {
    if (_remarksController.text.trim().isEmpty) {
      setState(() => _submitError = "Please add today's remarks.");
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final fieldResponses = <int, String>{
      for (final field in _adlgFields) field.id: _fieldControllers[field.id]?.text ?? '',
    };

    final result = await ReportService.instance.submit(
      remarks: _remarksController.text.trim(),
      nikahCount: _nikah,
      birthCount: _birth,
      deathCount: _death,
      complaintCount: _complaint,
      fieldResponses: fieldResponses,
      customFields: _customFields,
      attachment: _attachment != null ? File(_attachment!.path) : null,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _submitError = result.errorMessage;
      });
      return;
    }

    setState(() {
      _submitting = false;
      _history = [result.data!, ..._history];
      _remarksController.clear();
      _nikah = 0;
      _birth = 0;
      _death = 0;
      _complaint = 0;
      for (final c in _fieldControllers.values) {
        c.clear();
      }
      _customFields.clear();
      _attachment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: const Text('Reports'), actions: const [NotificationBell(), LogoutAction()]),
      drawer: AppDrawer(role: 'sec', currentKey: 'reports', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _loadError != null
              ? Center(child: Text(_loadError!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      if (_submittedToday)
                        _AlreadySubmittedCard(report: _history.firstWhere((r) => r.reportDate == _todayStr()))
                      else
                        _buildForm(),
                      const SizedBox(height: 28),
                      const Text('Report History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('No reports submitted yet.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._history.map((r) => _ReportHistoryTile(report: r)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Daily Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 14),
          const Text('Daily Remarks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          TextField(
            controller: _remarksController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: "Today's activities…"),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _CounterField(label: 'Nikah Reg.', value: _nikah, onChanged: (v) => setState(() => _nikah = v))),
              const SizedBox(width: 10),
              Expanded(child: _CounterField(label: 'Birth Certs', value: _birth, onChanged: (v) => setState(() => _birth = v))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CounterField(label: 'Death Certs', value: _death, onChanged: (v) => setState(() => _death = v))),
              const SizedBox(width: 10),
              Expanded(child: _CounterField(label: 'Complaints', value: _complaint, onChanged: (v) => setState(() => _complaint = v))),
            ],
          ),
          if (_adlgFields.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Required by ADLG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary600)),
            const SizedBox(height: 8),
            ..._adlgFields.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _fieldControllers[field.id],
                    decoration: InputDecoration(labelText: field.label),
                  ),
                )),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Additional Fields (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _customFields.add(CustomFieldInput())),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Field'),
              ),
            ],
          ),
          ..._customFields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(hintText: 'Field name'),
                      onChanged: (v) => field.label = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(hintText: 'Value'),
                      onChanged: (v) => field.value = v,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _customFields.removeAt(index)),
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkFaint),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(_attachment == null ? 'Attach File' : 'Change Attachment'),
              ),
              if (_attachment != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _attachment!.name,
                    style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _attachment = null),
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkFaint),
                ),
              ],
            ],
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 10),
            Text(_submitError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Submit Report'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _CounterField extends StatelessWidget {
  const _CounterField({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepButton(Icons.remove_rounded, () => onChanged(value > 0 ? value - 1 : 0)),
              Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
              _stepButton(Icons.add_rounded, () => onChanged(value + 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.primary600),
      ),
    );
  }
}

class _AlreadySubmittedCard extends StatelessWidget {
  const _AlreadySubmittedCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's report already submitted", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(
                  report.reviewed ? 'Reviewed by your ADLG' : 'Awaiting review',
                  style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportHistoryTile extends StatelessWidget {
  const _ReportHistoryTile({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(report.reportDate, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (report.reviewed ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  report.reviewed ? 'Reviewed' : 'Pending',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: report.reviewed ? AppColors.success : AppColors.warning),
                ),
              ),
            ],
          ),
          if (report.remarks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(report.remarks, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
          ],
          if (report.customFields.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.customFields.map((f) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: f.isAdlgRequired ? AppColors.primary50 : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${f.label}: ${f.value.isEmpty ? '—' : f.value}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: f.isAdlgRequired ? AppColors.primary700 : AppColors.inkMuted),
                  ),
                );
              }).toList(),
            ),
          ],
          if (report.attachmentUrl != null) ...[
            const SizedBox(height: 6),
            const Text('📎 Attachment', style: TextStyle(fontSize: 11.5, color: AppColors.primary600, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
