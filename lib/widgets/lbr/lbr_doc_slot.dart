import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

bool _isImagePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
}

/// One fixed LBR document slot (CNIC copy, Form A, photo, etc.) — a single
/// file, optionally already-uploaded (shown as a chip with a link) with a
/// pick/replace/clear affordance. Mirrors the web wizard's per-slot upload
/// row for [kLbrDocSlots].
class LbrDocSlotTile extends StatelessWidget {
  const LbrDocSlotTile({
    super.key,
    required this.label,
    required this.required,
    required this.allowedExtensions,
    required this.file,
    required this.onChanged,
    this.existingUrl,
  });

  final String label;
  final bool required;
  final List<String> allowedExtensions;
  final File? file;
  final ValueChanged<File?> onChanged;

  /// URL of a file already on record (resubmit flow) — satisfies the
  /// required check even without picking a new file.
  final String? existingUrl;

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: allowedExtensions);
    final path = (result != null && result.files.isNotEmpty) ? result.files.first.path : null;
    if (path != null) onChanged(File(path));
  }

  @override
  Widget build(BuildContext context) {
    final satisfied = file != null || existingUrl != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: satisfied ? AppColors.primary400 : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            file != null
                ? (_isImagePath(file!.path) ? Icons.image_rounded : Icons.picture_as_pdf_outlined)
                : (satisfied ? Icons.check_circle_rounded : Icons.upload_file_outlined),
            size: 20,
            color: satisfied ? AppColors.primary500 : AppColors.inkFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    ),
                    if (required)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('Required', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  file != null ? file!.path.split(Platform.pathSeparator).last : (existingUrl != null ? 'Already on file' : 'Not attached'),
                  style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (file != null)
            IconButton(onPressed: () => onChanged(null), icon: const Icon(Icons.close_rounded, size: 18), color: AppColors.inkFaint)
          else
            TextButton(onPressed: _pick, child: const Text('Choose')),
        ],
      ),
    );
  }
}
