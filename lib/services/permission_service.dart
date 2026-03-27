import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request storage/media permission depending on Android version
  static Future<bool> requestImagePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ uses READ_MEDIA_IMAGES
    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted) return true;

    // Android 12 and below uses READ_EXTERNAL_STORAGE
    final storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) return true;

    // If permanently denied, open settings
    if (photosStatus.isPermanentlyDenied ||
        storageStatus.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }
}