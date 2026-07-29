import 'dart:io';

import 'package:image_picker/image_picker.dart';

class CameraService {
  CameraService._();

  static final CameraService instance = CameraService._();

  final ImagePicker _picker = ImagePicker();

  /// Front-camera selfie for the attendance mark-in photo — mirrors the web
  /// app's requirement of a photo taken at the moment of check-in (no gallery
  /// picks), compressed to keep uploads fast on mobile data.
  Future<File?> captureSelfie() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (photo == null) return null;
    return File(photo.path);
  }
}
