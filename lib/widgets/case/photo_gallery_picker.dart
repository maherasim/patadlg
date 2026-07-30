import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';

/// Multi-image picker with thumbnail previews + per-item remove — the mobile
/// equivalent of the web app's PhotoGalleryInput. Images only (no PDF
/// support here, unlike the web version's Khula "allowPdf" mode) since that
/// would need a separate file-picker package.
class PhotoGalleryPicker extends StatelessWidget {
  const PhotoGalleryPicker({
    super.key,
    required this.label,
    required this.hint,
    required this.files,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final List<File> files;
  final ValueChanged<List<File>> onChanged;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    onChanged([...files, ...picked.map((x) => File(x.path))]);
  }

  void _remove(int index) {
    final updated = [...files]..removeAt(index);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...files.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    clipBehavior: Clip.hardEdge,
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: () => _remove(index),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
            GestureDetector(
              onTap: _pick,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary500, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
