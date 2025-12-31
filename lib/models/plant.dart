import 'occurrence.dart';

class PlantImage {
  final String url;
  final String? creditUrl;
  PlantImage({required this.url, this.creditUrl});

  factory PlantImage.fromJson(Map<String, dynamic> j) {
    final url = (j['url'] ?? j['filePath']) as String?;
    final creditUrl = (j['creditUrl'] ?? j['filePage']) as String?;

    return PlantImage(
      url: url ?? "", // never crash
      creditUrl: creditUrl,
    );
  }
}

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
  final PlantRecipe recipe;

  List<Occurrence> occurrences;

  Plant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.idMarkers,
    required this.recipe,
    this.lookalikeWarning,
    this.taxonKey,
    this.image,
    this.occurrences = const [],
  });

  int get frequency => occurrences.length;

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        id: j['id'],
        commonName: j['commonName'] ?? "",
        scientificName: j['scientificName'] ?? "",
        taxonKey:
            (j['taxonKey'] is num) ? (j['taxonKey'] as num).toInt() : null,
        image: (j['image'] is Map<String, dynamic>)
            ? PlantImage.fromJson(j['image'])
            : null,
        idMarkers: j['idMarkers'] ?? "",
        lookalikeWarning: j['lookalikeWarning'],
        recipe: PlantRecipe.fromJson(j['recipe']),
        occurrences: const [],
      );
}
