import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/occurrence.dart';
import 'dart:math' as math;

class GbifService {
  static Future<int?> resolveTaxonKey(String scientificName) async {
    final uri = Uri.parse('https://api.gbif.org/v1/species/match')
        .replace(queryParameters: {
      'name': scientificName,
      'strict': 'true',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final matchType = data['matchType']?.toString();

    if (matchType != 'EXACT' && matchType != 'FUZZY') return null;

    final key = data['usageKey'];
    return (key is num) ? key.toInt() : null;
  }

  static Future<Map<int, List<Occurrence>>> fetchOccurrencesByTaxa({
    required double lat,
    required double lon,
    required List<int> taxonKeys,
    double radiusKm = 10,
    int limit = 300,
  }) async {
    final latDeg = radiusKm / 111;
    final lonDeg = radiusKm / (111 * math.cos(lat * math.pi / 180));

    final minLat = lat - latDeg;
    final maxLat = lat + latDeg;
    final minLon = lon - lonDeg;
    final maxLon = lon + lonDeg;

    final qp = <String, dynamic>{
      'hasCoordinate': 'true',
      'hasGeospatialIssue': 'false',
      'occurrenceStatus': 'PRESENT',
      'decimalLatitude': '$minLat,$maxLat',
      'decimalLongitude': '$minLon,$maxLon',
      'limit': '$limit',
      'offset': '0',
    };

    final uri = Uri.parse('https://api.gbif.org/v1/occurrence/search')
        .replace(queryParameters: qp)
        .replace(queryParameters: {
      ...qp.map((k, v) => MapEntry(k, v.toString())),
      // taxonKey must appear multiple times
    });

    // Build query with repeated taxonKey params
    final taxonParams = taxonKeys.map((k) => 'taxonKey=$k').join('&');
    final finalUri = Uri.parse(uri.toString() + '&' + taxonParams);

    final res = await http.get(finalUri);
    if (res.statusCode != 200) {
      throw Exception('GBIF occurrence search failed: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>();

    final out = <int, List<Occurrence>>{};
    for (final k in taxonKeys) {
      out[k] = [];
    }

    for (final r in results) {
      final k = r['taxonKey'];
      if (k is! num) continue;
      final key = k.toInt();
      out.putIfAbsent(key, () => []);
      if (r['decimalLatitude'] == null || r['decimalLongitude'] == null)
        continue;
      out[key]!.add(Occurrence.fromGbif(r));
    }

    return out;
  }
}

class MathUtils {
  static double cosDeg(double deg) => (deg * 3.141592653589793 / 180).cos();
}

// Tiny extension so we can use .cos() without importing dart:math everywhere
extension _Cos on double {
  double cos() {
    // minimal; you can replace with dart:math if you prefer clarity
    // but let's not pretend this is elegant. it works.
    // In real code: import 'dart:math' as math; return math.cos(this);
    return _cosTaylor(this);
  }
}

// Low-accuracy cosine approximation (good enough for bbox scaling, MVP only).
double _cosTaylor(double x) {
  final x2 = x * x;
  return 1 - (x2 / 2) + (x2 * x2 / 24);
}
