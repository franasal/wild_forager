class Occurrence {
  final double lat;
  final double lon;
  final DateTime? eventDate;
  final int count;
  final int? gbifId;

  Occurrence({
    required this.lat,
    required this.lon,
    required this.count,
    this.eventDate,
    this.gbifId,
  });

  factory Occurrence.fromGbif(Map<String, dynamic> r) {
    DateTime? dt;
    final raw = r['eventDate'];
    if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    return Occurrence(
      lat: (r['decimalLatitude'] as num).toDouble(),
      lon: (r['decimalLongitude'] as num).toDouble(),
      count: 1,
      gbifId: (r['gbifID'] as num?)?.toInt(),
      eventDate: dt,
    );
  }

  factory Occurrence.fromDemo(Map<String, dynamic> r) {
    DateTime? dt;
    final raw = r['date'];
    if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    final countRaw = r['gbif_occurrence_count'] ?? r['count'];
    final count = (countRaw is num) ? countRaw.toInt() : 1;

    return Occurrence(
      lat: (r['lat'] as num).toDouble(),
      lon: (r['lon'] as num).toDouble(),
      count: count,
      eventDate: dt,
      gbifId: null,
    );
  }
}
