import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/local_download_service.dart';

/// Saves an already-downloaded export/template file to the device's local
/// Downloads folder and confirms via a SnackBar — the client explicitly
/// asked for a plain local download here, not the OS share sheet (WhatsApp
/// etc.). Falls back to the share sheet on non-Android platforms, where
/// "Save to Files" already gives the same local-download outcome.
Future<void> saveExportedFile(BuildContext context, File file) async {
  final fileName = file.path.split(Platform.pathSeparator).last;

  if (Platform.isAndroid) {
    final saved = await LocalDownloadService.saveToDownloads(file);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saved ? 'Saved to Downloads: $fileName' : "Couldn't save to Downloads. Please try again.")),
    );
    return;
  }

  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: fileName));
}
