import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/union_council.dart';
import '../../services/directory_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

/// ADLG-only — create or edit a Union Council. [existing] set means edit
/// (tehsil is fixed/immutable, injected server-side either way).
class UnionCouncilFormSheet extends StatefulWidget {
  const UnionCouncilFormSheet({super.key, this.existing});

  final UnionCouncil? existing;

  @override
  State<UnionCouncilFormSheet> createState() => _UnionCouncilFormSheetState();
}

class _UnionCouncilFormSheetState extends State<UnionCouncilFormSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _ucNoController = TextEditingController(text: widget.existing?.ucNo?.toString() ?? '');
  late final _codeController = TextEditingController(text: widget.existing?.code ?? '');
  late final _addressController = TextEditingController(text: widget.existing?.address ?? '');
  late final _latController = TextEditingController(text: widget.existing?.lat?.toStringAsFixed(5) ?? '');
  late final _lngController = TextEditingController(text: widget.existing?.lng?.toStringAsFixed(5) ?? '');
  late final _radiusController = TextEditingController(text: (widget.existing?.geofenceRadius ?? 150).toString());

  bool _locating = false;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _ucNoController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _pinMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final result = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latController.text = result.lat.toStringAsFixed(5);
        _lngController.text = result.lng.toStringAsFixed(5);
        _locating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final ucNo = int.tryParse(_ucNoController.text.trim());
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());

    final result = _isEdit
        ? await DirectoryService.instance.updateUnionCouncil(
            id: widget.existing!.id,
            name: _nameController.text.trim(),
            ucNo: ucNo,
            code: _codeController.text.trim(),
            address: _addressController.text.trim(),
            lat: lat,
            lng: lng,
            geofenceRadius: radius,
          )
        : await DirectoryService.instance.createUnionCouncil(
            name: _nameController.text.trim(),
            ucNo: ucNo,
            code: _codeController.text.trim(),
            address: _addressController.text.trim(),
            lat: lat,
            lng: lng,
            geofenceRadius: radius,
          );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage;
      });
      return;
    }

    Navigator.of(context).pop(result.data);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text(_isEdit ? 'Edit Union Council' : 'New Union Council', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 18),
              _label('Name'),
              TextField(controller: _nameController),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_label('UC No.'), TextField(controller: _ucNoController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Code'), TextField(controller: _codeController)]),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label('Address'),
              TextField(controller: _addressController),
              const SizedBox(height: 18),
              Row(
                children: [
                  _label('Geofence Location'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _locating ? null : _pinMyLocation,
                    icon: _locating
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 15),
                    label: const Text('Pin my location'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: _latController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(hintText: 'Lat'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _lngController, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(hintText: 'Lng'))),
                ],
              ),
              const SizedBox(height: 14),
              _label('Geofence Radius (meters)'),
              TextField(controller: _radiusController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_isEdit ? 'Save Changes' : 'Create Union Council'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)));
}
