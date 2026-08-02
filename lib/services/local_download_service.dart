import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Saves an already-downloaded file (Excel export, PDF notesheet, etc.) into
/// the device's shared Downloads folder — visible in the file manager, same
/// as a normal browser download — via a small native MediaStore handler
/// (see android/app MainActivity.kt). Android only; other platforms keep
/// using the OS share sheet, which already offers "Save to Files" there.
class LocalDownloadService {
  LocalDownloadService._();

  static const _channel = MethodChannel('patadlg/downloads');

  static String _mimeTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'pdf':
        return 'application/pdf';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> _invoke(String fileName, List<int> bytes, String mimeType) {
    return _channel.invokeMethod('saveToDownloads', {
      'fileName': fileName,
      'bytes': bytes,
      'mimeType': mimeType,
    });
  }

  static Future<bool> saveToDownloads(File file) async {
    if (!Platform.isAndroid) return false;

    final fileName = file.path.split(Platform.pathSeparator).last;
    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeFor(fileName);

    try {
      await _invoke(fileName, bytes, mimeType);
      return true;
    } on PlatformException {
      // Most likely a pre-Android-10 device missing WRITE_EXTERNAL_STORAGE
      // (API 29+ never needs it) — ask once and retry.
      final status = await Permission.storage.request();
      if (!status.isGranted) return false;
      try {
        await _invoke(fileName, bytes, mimeType);
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}
