import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PlantNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Widget fallback;

  const PlantNetworkImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  static final Map<String, Future<Uint8List>> _bytesCache = {};

  static Future<Uint8List> _fetchBytes(String url) async {
    final headers = <String, String>{
      'User-Agent': 'wild_forager/1.0 (Flutter)',
      'Accept': 'image/*,*/*;q=0.8',
    };

    Uri current = Uri.parse(url);
    for (var i = 0; i < 8; i++) {
      final res = await http.get(current, headers: headers);
      final code = res.statusCode;
      if (code >= 200 && code < 300) return res.bodyBytes;

      if (code >= 300 && code < 400) {
        final loc = res.headers['location'];
        if (loc == null || loc.trim().isEmpty) {
          throw Exception('Redirect without location ($code) for $current');
        }
        current = current.resolve(loc);
        continue;
      }

      throw Exception('HTTP $code for $current');
    }

    throw Exception('Too many redirects for $url');
  }

  @override
  Widget build(BuildContext context) {
    final src = url?.trim();
    if (src == null || src.isEmpty) return fallback;

    // On web, prefer the browser's <img> pipeline to avoid CORS/redirect/header
    // restrictions of `fetch` (which `package:http` uses under the hood).
    if (kIsWeb) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    final future = _bytesCache.putIfAbsent(src, () => _fetchBytes(src));
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          );
        }
        if (snap.hasError) {
          debugPrint('PlantNetworkImage failed for $src: ${snap.error}');
          return fallback;
        }
        final bytes = snap.data;
        if (bytes == null) return fallback;

        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }
}
