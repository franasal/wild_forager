import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show MissingPluginException;

class LocationService {
  static Future<Position?> getPosition() async {
    if (kIsWeb) {
      // Geolocator web implementation exists, but MissingPluginException happens
      // if you call native channel methods. So avoid those on web.
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        return null;
      }
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } on MissingPluginException {
      // Common on desktop targets where a platform implementation isn't wired.
      return null;
    } catch (_) {
      return null;
    }
  }
}
