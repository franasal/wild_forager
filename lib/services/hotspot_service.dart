import '../models/occurrence.dart';
import 'dart:math' as math;

class HotspotCell {
  final double lat;
  final double lon;
  int count;
  final List<int> monthCounts;

  HotspotCell({required this.lat, required this.lon, required this.count})
      : monthCounts = List<int>.filled(12, 0);
}

class HotspotService {
  static List<HotspotCell> aggregate(List<Occurrence> occ,
      {double gridKm = 1, DateTime? start, DateTime? end}) {
    final cells = <String, HotspotCell>{};

    final latStep = gridKm / 111;

    for (final o in occ) {
      final d = o.eventDate;
      if (start != null && d != null && d.isBefore(start)) continue;
      if (end != null && d != null && d.isAfter(end)) continue;

      final lonStep = gridKm / (111 * _cosDeg(o.lat));

      final latCell = (o.lat / latStep).round() * latStep;
      final lonCell = (o.lon / lonStep).round() * lonStep;

      final key = '${latCell.toStringAsFixed(6)},${lonCell.toStringAsFixed(6)}';
      final cell = cells.putIfAbsent(
          key, () => HotspotCell(lat: latCell, lon: lonCell, count: 0));

      cell.count += o.count;
      if (d != null) cell.monthCounts[d.month - 1] += o.count;
    }

    final out = cells.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  static double _cosDeg(double deg) {
    // Replace with dart:math for accuracy if you want.
    final rad = deg * 3.141592653589793 / 180;
    final x2 = rad * rad;
    return 1 - (x2 / 2) + (x2 * x2 / 24);
  }
}
