import 'occurrence.dart';

class PlantImage {
  final String url;
  final String? creditUrl;
  final String? creditText;
  PlantImage({required this.url, this.creditUrl, this.creditText});

  factory PlantImage.fromJson(Map<String, dynamic> j) {
    final url = (j['url'] ?? j['filePath']) as String?;
    final creditUrl = (j['creditUrl'] ?? j['filePage']) as String?;
    final creditText = (j['creditText'] ?? j['credit']) as String?;

    return PlantImage(
      url: url ?? "", // never crash
      creditUrl: creditUrl,
      creditText: creditText,
    );
  }
}

enum PlantRarity { rare, medium, common }

class PlantRecipe {
  final String prep;
  final String simple;
  final String pairing;

  PlantRecipe(
      {required this.prep, required this.simple, required this.pairing});

  factory PlantRecipe.fromJson(Map<String, dynamic>? j) {
    if (j == null) {
      return PlantRecipe(
        prep: "Wash thoroughly. Remove tough stems if needed.",
        simple: "Quick sauté: olive oil, garlic, greens, salt. 3–5 minutes.",
        pairing: "Goes well with garlic, lemon, nuts, and grains.",
      );
    }
    return PlantRecipe(
      prep: (j['prep'] ?? "").toString().trim().isEmpty
          ? "Wash thoroughly. Remove tough stems if needed."
          : j['prep'],
      simple: (j['simple'] ?? "").toString().trim().isEmpty
          ? "Quick sauté: olive oil, garlic, greens, salt. 3–5 minutes."
          : j['simple'],
      pairing: (j['pairing'] ?? "").toString().trim().isEmpty
          ? "Goes well with garlic, lemon, nuts, and grains."
          : j['pairing'],
    );
  }
}

class Plant {
  final String id;
  final String commonName;
  final String scientificName;
  int? taxonKey;
  final PlantImage? image;
  final String idMarkers;
  final String? lookalikeWarning;
  final String? altCommonName;
  final PlantRecipe recipe;
  final int total;
  final Map<int, int> yearCounts;
  final List<int> monthCountsAll;
  PlantRarity rarity;

  List<Occurrence> occurrences;

  Plant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.idMarkers,
    required this.recipe,
    this.lookalikeWarning,
    this.altCommonName,
    this.taxonKey,
    this.image,
    this.occurrences = const [],
    this.total = 0,
    Map<int, int>? yearCounts,
    List<int>? monthCountsAll,
    this.rarity = PlantRarity.medium,
  })  : yearCounts = Map<int, int>.unmodifiable(yearCounts ?? const {}),
        monthCountsAll =
            List<int>.unmodifiable(monthCountsAll ?? List<int>.filled(12, 0));

  int get sampleCount => occurrences.length;

  int get frequency => occurrences.length;

  factory Plant.fromJson(Map<String, dynamic> j) {
    final sci = (j['scientificName'] ?? "").toString();
    final taxonKey =
        (j['taxonKey'] is num) ? (j['taxonKey'] as num).toInt() : null;
    final id = (j['id'] ?? "").toString().trim().isNotEmpty
        ? j['id'].toString()
        : _fallbackId(scientificName: sci, taxonKey: taxonKey);

    final occs = ((j['demo'] as Map<String, dynamic>?)?['occurrences']
                as List<dynamic>? ??
            const [])
        .whereType<Map<String, dynamic>>()
        .map(Occurrence.fromDemo)
        .toList()
      ..sort((a, b) {
        final ad = a.eventDate;
        final bd = b.eventDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

    return Plant(
      id: id,
      commonName: (j['commonName'] ?? "").toString(),
      scientificName: sci,
      taxonKey: taxonKey,
      altCommonName: (j['commonName2'] ?? j['commonNameAlt'])?.toString(),
      image: (j['image'] is Map<String, dynamic>)
          ? PlantImage.fromJson(j['image'])
          : null,
      idMarkers: (j['idMarkers'] ?? "").toString(),
      lookalikeWarning: j['lookalikeWarning']?.toString(),
      recipe: PlantRecipe.fromJson(j['recipe'] as Map<String, dynamic>?),
      total: (j['total'] is num)
          ? (j['total'] as num).toInt()
          : (j['frequency'] is num)
              ? (j['frequency'] as num).toInt()
              : 0,
      yearCounts: (j['year_counts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(int.tryParse(k.toString()) ?? 0,
              (v is num) ? v.toInt() : 0)),
      occurrences: occs,
      monthCountsAll: _histogramByMonth(occs),
      rarity: PlantRarity.medium,
    );
  }

  factory Plant.fromCompact({
    required String scientificName,
    required Map<String, dynamic> data,
    PlantImage? image,
  }) {
    final taxonKey =
        (data['taxonKey'] is num) ? (data['taxonKey'] as num).toInt() : null;
    final id = _fallbackId(scientificName: scientificName, taxonKey: taxonKey);
    final pts = (data['points'] as List<dynamic>? ?? const [])
        .whereType<List<dynamic>>()
        .map((p) => Occurrence.fromCompactPoint(p))
        .toList();

    final totals = (data['year_counts'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(int.tryParse(k.toString()) ?? 0,
            (v is num) ? v.toInt() : 0));

    return Plant(
      id: id,
      commonName: (data['de'] ?? data['commonName'] ?? "").toString(),
      altCommonName:
          (data['commonName2'] ?? data['commonNameAlt'])?.toString(),
      scientificName: scientificName,
      taxonKey: taxonKey,
      image: image,
      idMarkers: (data['idMarkers'] ?? "").toString(),
      lookalikeWarning: data['lookalikeWarning']?.toString(),
      recipe: PlantRecipe.fromJson(data['recipe'] as Map<String, dynamic>?),
      total: (data['total'] is num) ? (data['total'] as num).toInt() : 0,
      yearCounts: totals,
      occurrences: pts,
      monthCountsAll: _histogramByMonth(pts),
      rarity: PlantRarity.medium,
    );
  }

  Plant copyWith({
    String? id,
    String? commonName,
    String? scientificName,
    int? taxonKey,
    PlantImage? image,
    String? idMarkers,
    String? lookalikeWarning,
    String? altCommonName,
    PlantRecipe? recipe,
    List<Occurrence>? occurrences,
    int? total,
    Map<int, int>? yearCounts,
    List<int>? monthCountsAll,
    PlantRarity? rarity,
  }) {
    return Plant(
      id: id ?? this.id,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      taxonKey: taxonKey ?? this.taxonKey,
      image: image ?? this.image,
      idMarkers: idMarkers ?? this.idMarkers,
      lookalikeWarning: lookalikeWarning ?? this.lookalikeWarning,
      altCommonName: altCommonName ?? this.altCommonName,
      recipe: recipe ?? this.recipe,
      occurrences: occurrences ?? this.occurrences,
      total: total ?? this.total,
      yearCounts: yearCounts ?? this.yearCounts,
      monthCountsAll: monthCountsAll ?? this.monthCountsAll,
      rarity: rarity ?? this.rarity,
    );
  }
}

String _fallbackId({required String scientificName, required int? taxonKey}) {
  if (taxonKey != null) return 'taxon_$taxonKey';
  final parts = scientificName.trim().split(RegExp(r'\\s+'));
  if (parts.length >= 2) {
    return '${parts[0].toLowerCase()}_${parts[1].toLowerCase()}';
  }
  return scientificName.trim().isEmpty ? 'plant' : scientificName.trim();
}

List<int> _histogramByMonth(List<Occurrence> occ) {
  final out = List<int>.filled(12, 0);
  for (final o in occ) {
    final dt = o.eventDate;
    if (dt == null) continue;
    out[dt.month - 1] += o.count;
  }
  return out;
}
