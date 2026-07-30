import 'package:flutter/material.dart';

import '../../models/directory_user.dart';
import '../../models/union_council.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';

/// ADLG-only — assign/remove "additional UC charges": a secretary covering
/// more than one Union Council beyond their primary assignment. When they
/// mark attendance at their primary UC, a covering remark is automatically
/// logged for each additional-charge UC too (server-side behavior).
class ChargesSheet extends StatefulWidget {
  const ChargesSheet({super.key, required this.secretary});

  final DirectoryUser secretary;

  @override
  State<ChargesSheet> createState() => _ChargesSheetState();
}

class _ChargesSheetState extends State<ChargesSheet> {
  bool _loadingUcs = true;
  List<UnionCouncil> _ucs = [];
  late List<UcCharge> _charges = List.of(widget.secretary.secretaryProfile?.additionalCharges ?? const []);
  int? _selectedUcId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUcs();
  }

  Future<void> _loadUcs() async {
    try {
      final ucs = await DirectoryService.instance.unionCouncilsForAdlg();
      if (!mounted) return;
      setState(() {
        _ucs = ucs..sort((a, b) => a.name.compareTo(b.name));
        _loadingUcs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUcs = false);
    }
  }

  List<UnionCouncil> get _assignableUcs {
    final primaryUcId = widget.secretary.secretaryProfile?.unionCouncilId;
    final chargedIds = _charges.map((c) => c.unionCouncilId).toSet();
    return _ucs.where((u) => u.id != primaryUcId && !chargedIds.contains(u.id)).toList();
  }

  Future<void> _assign() async {
    if (_selectedUcId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await DirectoryService.instance.assignCharge(secretaryId: widget.secretary.id, unionCouncilId: _selectedUcId!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isSuccess) {
      setState(() {
        _charges = List.of(result.data?.secretaryProfile?.additionalCharges ?? _charges);
        _selectedUcId = null;
      });
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  Future<void> _remove(UcCharge charge) async {
    setState(() => _busy = true);
    final ok = await DirectoryService.instance.removeCharge(secretaryId: widget.secretary.id, unionCouncilId: charge.unionCouncilId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _charges.removeWhere((c) => c.unionCouncilId == charge.unionCouncilId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Text('Additional UC Charges', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('For ${widget.secretary.name}', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
            const SizedBox(height: 6),
            const Text(
              "When this secretary marks attendance at their primary UC, a covering remark is automatically logged for each additional-charge UC too.",
              style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint, height: 1.4),
            ),
            const SizedBox(height: 18),
            const Text('Current Charges', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            if (_charges.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('No additional charges.', style: TextStyle(color: AppColors.inkFaint, fontSize: 12.5)))
            else
              ..._charges.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(child: Text(c.unionCouncil, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink))),
                        TextButton(onPressed: _busy ? null : () => _remove(c), child: const Text('Remove', style: TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  )),
            const SizedBox(height: 18),
            const Text('Assign New Charge', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            _loadingUcs
                ? const LinearProgressIndicator()
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedUcId,
                          isExpanded: true,
                          hint: const Text('Select union council'),
                          items: _assignableUcs.map((u) {
                            final suffix = u.secretary != null ? ' (covered by ${u.secretary})' : ' (vacant)';
                            return DropdownMenuItem(value: u.id, child: Text('${u.name}$suffix', overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedUcId = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (_busy || _selectedUcId == null) ? null : _assign,
                        child: _busy
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Assign'),
                      ),
                    ],
                  ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}
