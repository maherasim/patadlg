import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

bool _isImageFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
}

/// Multi-file picker for images OR documents (PDF/Word) — the mobile
/// equivalent of the web app's PhotoGalleryInput with allowPdf=true, used
/// for Khula's "Court Decree" upload. Unlike [PhotoGalleryPicker] (gallery
/// photos only), this opens the system file picker so PDFs are selectable
/// too.
class DocumentGalleryPicker extends StatelessWidget {
  const DocumentGalleryPicker({
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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
    onChanged([...files, ...picked]);
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
              final isImage = _isImageFile(file.path);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    clipBehavior: Clip.hardEdge,
                    child: isImage
                        ? Image.file(file, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.surfaceSubtle,
                            alignment: Alignment.center,
                            child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary500, size: 26),
                          ),
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
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary500, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
