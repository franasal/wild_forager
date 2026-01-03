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

  factory Occurrence.fromCompactPoint(List<dynamic> raw) {
    // Expected order: [lat, lon, year, month]
    double lat = 0;
    double lon = 0;
    int? year;
    int? month;

    if (raw.isNotEmpty && raw[0] is num) lat = (raw[0] as num).toDouble();
    if (raw.length > 1 && raw[1] is num) lon = (raw[1] as num).toDouble();
    if (raw.length > 2 && raw[2] is num) year = (raw[2] as num).toInt();
    if (raw.length > 3 && raw[3] is num) month = (raw[3] as num).toInt();

    DateTime? dt;
    if (year != null && month != null && month >= 1 && month <= 12) {
      dt = DateTime(year, month, 1);
    } else if (year != null) {
      dt = DateTime(year, 1, 1);
    }

    return Occurrence(
      lat: lat,
      lon: lon,
      count: 1,
      eventDate: dt,
      gbifId: null,
    );
  }
}
