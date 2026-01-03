import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'hotspot_service.dart';
import 'write_bytes.dart';

class OccurrenceDb {
  static const _assetPath = 'assets/data/plants_bins.sqlite';
  static const _dbFileName = 'plants_bins.sqlite';

  final Database _db;
  OccurrenceDb._(this._db);

  static Future<OccurrenceDb?> openBundled() async {
    try {
      if (kIsWeb) return null;
      final bytes = await _loadAssetBytes(_assetPath);
      if (bytes == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/$_dbFileName';

      // Copy only if missing or size mismatch.
      final exists = await databaseExists(dbPath);
      if (!exists) await writeBytes(dbPath, bytes);

      final db = await openDatabase(dbPath, readOnly: true);
      return OccurrenceDb._(db);
    } catch (_) {
      return null;
    }
  }

  Future<List<HotspotCell>> queryHotspots({
    required LatLngBounds bounds,
    required int zoom,
    required DateTime start,
    required DateTime end,
    List<int>? speciesKeys,
    int limit = 800,
  }) async {
    final minX = _lonToTileX(bounds.west, zoom);
    final maxX = _lonToTileX(bounds.east, zoom);
    final minY = _latToTileY(bounds.north, zoom);
    final maxY = _latToTileY(bounds.south, zoom);

    final startYm = start.year * 100 + start.month;
    final endYm = end.year * 100 + end.month;

    final where = StringBuffer(
        "z = ? AND x BETWEEN ? AND ? AND tileY BETWEEN ? AND ? AND (y * 100 + m) BETWEEN ? AND ?");
    final args = [
      zoom,
      math.min(minX, maxX),
      math.max(minX, maxX),
      math.min(minY, maxY),
      math.max(minY, maxY),
      math.min(startYm, endYm),
      math.max(startYm, endYm),
    ];

    if (speciesKeys != null && speciesKeys.isNotEmpty) {
      final placeholders = List.filled(speciesKeys.length, '?').join(',');
      where.write(" AND speciesKey IN ($placeholders)");
      args.addAll(speciesKeys);
    }

    final sql = """
      SELECT x, tileY, SUM(c) as count
      FROM bins
      WHERE ${where.toString()}
      GROUP BY x, tileY
      ORDER BY count DESC
      LIMIT $limit
    """;

    final rows = await _db.rawQuery(sql, args);
    final out = <HotspotCell>[];

    for (final r in rows) {
      final x = (r['x'] as num).toInt();
      final y = (r['tileY'] as num).toInt();
      final count = (r['count'] as num).toInt();
      final center = _tileToLatLngCenter(x, y, zoom);
      out.add(HotspotCell(lat: center.latitude, lon: center.longitude, count: count));
    }
    return out;
  }

  Future<List<HotspotCell>> queryHotspotsGlobal({
    required int zoom,
    required DateTime start,
    required DateTime end,
    List<int>? speciesKeys,
    int limit = 800,
  }) async {
    final startYm = start.year * 100 + start.month;
    final endYm = end.year * 100 + end.month;

    final where = StringBuffer(
        "z = ? AND (y * 100 + m) BETWEEN ? AND ?");
    final args = [
      zoom,
      math.min(startYm, endYm),
      math.max(startYm, endYm),
    ];

    if (speciesKeys != null && speciesKeys.isNotEmpty) {
      final placeholders = List.filled(speciesKeys.length, '?').join(',');
      where.write(" AND speciesKey IN ($placeholders)");
      args.addAll(speciesKeys);
    }

    final sql = """
      SELECT x, tileY, SUM(c) as count
      FROM bins
      WHERE ${where.toString()}
      GROUP BY x, tileY
      ORDER BY count DESC
      LIMIT $limit
    """;

    final rows = await _db.rawQuery(sql, args);
    final out = <HotspotCell>[];

    for (final r in rows) {
      final x = (r['x'] as num).toInt();
      final y = (r['tileY'] as num).toInt();
      final count = (r['count'] as num).toInt();
      final center = _tileToLatLngCenter(x, y, zoom);
      out.add(HotspotCell(lat: center.latitude, lon: center.longitude, count: count));
    }
    return out;
  }

  Future<Set<int>> querySpeciesKeys() async {
    final rows = await _db.rawQuery("SELECT speciesKey FROM species");
    return rows
        .map((r) => (r['speciesKey'] as num).toInt())
        .toSet();
  }

  Future<List<Map<String, dynamic>>> querySpeciesList() async {
    return _db.rawQuery(
      "SELECT speciesKey, scientificName, canonicalName, rank FROM species",
    );
  }

  Future<Map<int, int>> querySpeciesTotals({
    required LatLngBounds bounds,
    required int zoom,
    required DateTime start,
    required DateTime end,
  }) async {
    final minX = _lonToTileX(bounds.west, zoom);
    final maxX = _lonToTileX(bounds.east, zoom);
    final minY = _latToTileY(bounds.north, zoom);
    final maxY = _latToTileY(bounds.south, zoom);

    final startYm = start.year * 100 + start.month;
    final endYm = end.year * 100 + end.month;

    final sql = """
      SELECT speciesKey, SUM(c) as count
      FROM bins
      WHERE z = ?
        AND x BETWEEN ? AND ?
        AND tileY BETWEEN ? AND ?
        AND (y * 100 + m) BETWEEN ? AND ?
      GROUP BY speciesKey
    """;

    final rows = await _db.rawQuery(sql, [
      zoom,
      math.min(minX, maxX),
      math.max(minX, maxX),
      math.min(minY, maxY),
      math.max(minY, maxY),
      math.min(startYm, endYm),
      math.max(startYm, endYm),
    ]);

    final out = <int, int>{};
    for (final r in rows) {
      final key = (r['speciesKey'] as num).toInt();
      final count = (r['count'] as num).toInt();
      out[key] = count;
    }
    return out;
  }

  Future<Map<int, DateTime>> querySpeciesLastObserved({
    required LatLngBounds bounds,
    required int zoom,
    required DateTime start,
    required DateTime end,
  }) async {
    final minX = _lonToTileX(bounds.west, zoom);
    final maxX = _lonToTileX(bounds.east, zoom);
    final minY = _latToTileY(bounds.north, zoom);
    final maxY = _latToTileY(bounds.south, zoom);

    final startYm = start.year * 100 + start.month;
    final endYm = end.year * 100 + end.month;

    final sql = """
      SELECT speciesKey, MAX(y * 100 + m) as ym
      FROM bins
      WHERE z = ?
        AND x BETWEEN ? AND ?
        AND tileY BETWEEN ? AND ?
        AND (y * 100 + m) BETWEEN ? AND ?
      GROUP BY speciesKey
    """;

    final rows = await _db.rawQuery(sql, [
      zoom,
      math.min(minX, maxX),
      math.max(minX, maxX),
      math.min(minY, maxY),
      math.max(minY, maxY),
      math.min(startYm, endYm),
      math.max(startYm, endYm),
    ]);

    final out = <int, DateTime>{};
    for (final r in rows) {
      final key = (r['speciesKey'] as num).toInt();
      final ym = (r['ym'] as num?)?.toInt();
      if (ym == null) continue;
      final y = ym ~/ 100;
      final m = ym % 100;
      out[key] = DateTime(y, m, 1);
    }
    return out;
  }

  Future<void> close() async {
    await _db.close();
  }
}

Future<Uint8List?> _loadAssetBytes(String path) async {
  try {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

int _lonToTileX(double lon, int z) {
  final n = 1 << z;
  final x = ((lon + 180.0) / 360.0 * n).floor();
  return x.clamp(0, n - 1);
}

int _latToTileY(double lat, int z) {
  final n = 1 << z;
  final clamped = lat.clamp(-85.05112878, 85.05112878);
  final latRad = clamped * math.pi / 180.0;
  final y =
      ((1.0 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) /
              2.0 *
              n)
          .floor();
  return y.clamp(0, n - 1);
}

LatLng _tileToLatLngCenter(int x, int y, int z) {
  final n = 1 << z;
  final lon = (x + 0.5) / n * 360.0 - 180.0;
  final latRad = math.atan(_sinh(math.pi * (1 - 2 * (y + 0.5) / n)));
  final lat = latRad * 180.0 / math.pi;
  return LatLng(lat, lon);
}

double _sinh(double x) {
  // Avoid relying on math.sinh for older SDKs.
  return (math.exp(x) - math.exp(-x)) / 2.0;
}
