import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show FlutterError;
import '../models/plant.dart';
import '../models/occurrence.dart';

class PlantRepoResult {
  final Map<String, dynamic>? region;
  final List<Plant> plants;
  PlantRepoResult({required this.region, required this.plants});
}

class PlantRepo {
  static const _compactPath = 'assets/data/occurrences_compact.json';
  static const _imagesPath = 'assets/data/plants_wikipedia_images.json';
  static const _germanNamesPath = 'assets/data/plants_de.json';

  static Future<PlantRepoResult> loadBundledPlants() async {
    final compact = await _loadCompactDataset();
    if (compact != null) return compact;
    return _loadLegacy();
  }

  static Future<PlantRepoResult?> _loadCompactDataset() async {
    try {
      final raw = await rootBundle.loadString(_compactPath);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final region = data['region'] as Map<String, dynamic>?;
      final plantsRaw = data['plants'] as Map<String, dynamic>? ?? {};

      final images = await _loadImages();
      List<Plant> plants = [];
      final germanNames = await _loadGermanNames();
      plantsRaw.forEach((sci, value) {
        if (value is! Map<String, dynamic>) return;
        final sciStr = sci.toString();
        final normalized = _normalizeSciName(sciStr);
        final img = images[normalized];
        final plant = Plant.fromCompact(
          scientificName: sciStr,
          data: value,
          image: img,
        );

        final german = germanNames[sciStr] ?? germanNames[normalized];
        if (german != null && german.trim().isNotEmpty) {
          plants.add(plant.copyWith(
            altCommonName:
                plant.commonName.isNotEmpty ? plant.commonName : plant.altCommonName,
            commonName: german,
          ));
        } else if (plant.commonName.isEmpty &&
            (value['de'] as String? ?? '').isNotEmpty) {
          // Use compact 'de' if provided and no germanNames match
          plants.add(plant.copyWith(commonName: value['de'].toString()));
        } else {
          plants.add(plant);
        }
      });

      final metaPlants = await _loadMetaPlants();
      if (metaPlants.isNotEmpty) {
        plants = _mergeMeta(plants, metaPlants);
      }

      // Apply German names again for merged/meta entries
      _applyGermanNames(plants, await _loadGermanNames());
      _applyRarity(plants);
      return PlantRepoResult(region: region, plants: plants);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, PlantImage>> _loadImages() async {
    try {
      final raw = await rootBundle.loadString(_imagesPath);
      final data = jsonDecode(raw);
      if (data is! Map) return {};
      final out = <String, PlantImage>{};
      data.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          out[_normalizeSciName(k.toString())] = PlantImage.fromJson(v);
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<List<Plant>> _loadMetaPlants() async {
    try {
      final metaRaw =
          await rootBundle.loadString('assets/data/plants_meta.json');
      final meta = jsonDecode(metaRaw) as Map<String, dynamic>;

      final metaPlants = (meta['plants'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Plant.fromJson)
          .toList();
      return metaPlants;
    } catch (_) {
      return const [];
    }
  }

  static Future<PlantRepoResult> _loadLegacy() async {
    Map<String, dynamic> data = const {};
    final raw = await _tryLoadString('assets/data/plants.json');
    if (raw != null) {
      try {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        data = const {};
      }
    }
    Map<String, dynamic>? region = data['region'] as Map<String, dynamic>?;
    var list = (data['plants'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Plant.fromJson)
        .toList();

    // Curated metadata overlay (generated from a curated CSV/TSV):
    // merges names/images/recipes/markers without touching occurrences.
    try {
      final metaRaw =
          await rootBundle.loadString('assets/data/plants_meta.json');
      final meta = jsonDecode(metaRaw) as Map<String, dynamic>;
      region ??= meta['region'] as Map<String, dynamic>?;

          final metaPlants = (meta['plants'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(Plant.fromJson)
              .toList();

      if (list.isEmpty && metaPlants.isNotEmpty) {
        // If base list is empty, use meta list as the source of truth.
        list = metaPlants;
      } else {
        list = _mergeMeta(list, metaPlants);
      }
    } catch (_) {
      // Missing/invalid file is fine.
    }

    // Optional offline GBIF dataset (generated from CSV/TSV).
    // If present, use it to populate occurrences/taxonKeys/region without any network.
    try {
      final gbifRaw = await rootBundle.loadString('assets/data/plants_gbif.json');
      final gbif = jsonDecode(gbifRaw) as Map<String, dynamic>;
      region ??= gbif['region'] as Map<String, dynamic>?;

      final plantsGbif = (gbif['plants'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>();

      final byTaxonKey = <int, List<Occurrence>>{};
      final nameToTaxonKey = <String, int>{};

      for (final p in plantsGbif) {
        final tk = (p['taxonKey'] is num) ? (p['taxonKey'] as num).toInt() : null;
        if (tk == null) continue;

        final sci = (p['scientificName'] ?? p['species'] ?? '').toString().trim();
        if (sci.isNotEmpty) {
          nameToTaxonKey[_normalizeSciName(sci)] = tk;
        }

        final occs = (p['occurrences'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Occurrence.fromDemo)
            .toList();

        byTaxonKey[tk] = occs;
      }

      for (final plant in list) {
        plant.taxonKey ??= nameToTaxonKey[_normalizeSciName(plant.scientificName)];
        final tk = plant.taxonKey;
        if (tk == null) continue;
        final gbifOcc = byTaxonKey[tk];
        if (gbifOcc == null || gbifOcc.isEmpty) continue;
        plant.occurrences = gbifOcc;
      }
    } catch (_) {
      // Missing/invalid file is fine; keep bundled demo occurrences.
    }

    _applyGermanNames(list, await _loadGermanNames());
    _applyRarity(list);
    return PlantRepoResult(region: region, plants: list);
  }
}

String _normalizeSciName(String s) {
  // Strip author abbreviations and normalize whitespace, e.g. "Urtica dioica L." -> "urtica dioica"
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0]} ${parts[1]}'.toLowerCase();
  }
  return s.trim().toLowerCase();
}

List<Plant> _mergeMeta(List<Plant> base, List<Plant> meta) {
  final metaByTaxon = <int, Plant>{};
  final metaBySci = <String, Plant>{};
  final metaById = <String, Plant>{};

  for (final p in meta) {
    final tk = p.taxonKey;
    if (tk != null) metaByTaxon[tk] = p;
    metaBySci[_normalizeSciName(p.scientificName)] = p;
    metaById[p.id] = p;
  }

  return base.map((p) {
    Plant? m;
    final tk = p.taxonKey;
    if (tk != null) m = metaByTaxon[tk];
    m ??= metaBySci[_normalizeSciName(p.scientificName)];
    m ??= metaById[p.id];
    if (m == null) return p;

    return p.copyWith(
      // Keep base occurrences, but enrich display fields.
      taxonKey: p.taxonKey ?? m.taxonKey,
      commonName: m.commonName.trim().isNotEmpty ? m.commonName : p.commonName,
      scientificName:
          m.scientificName.trim().isNotEmpty ? m.scientificName : p.scientificName,
      image: m.image ?? p.image,
      idMarkers: m.idMarkers.trim().isNotEmpty ? m.idMarkers : p.idMarkers,
      lookalikeWarning: (m.lookalikeWarning ?? '').trim().isNotEmpty
          ? m.lookalikeWarning
          : p.lookalikeWarning,
      recipe: m.recipe,
      occurrences: p.occurrences,
      total: p.total,
      yearCounts: p.yearCounts,
      monthCountsAll: p.monthCountsAll,
    );
  }).toList();
}

void _applyRarity(List<Plant> plants) {
  if (plants.isEmpty) return;
  final totals = plants.map((p) => p.total).toList()..sort();
  final rareIdx = (totals.length * 0.25).floor().clamp(0, totals.length - 1);
  final commonIdx =
      (totals.length * 0.75).floor().clamp(0, totals.length - 1);
  final rareMax = totals[rareIdx];
  final commonMin = totals[commonIdx];

  for (final p in plants) {
    if (p.total <= rareMax) {
      p.rarity = PlantRarity.rare;
    } else if (p.total >= commonMin) {
      p.rarity = PlantRarity.common;
    } else {
      p.rarity = PlantRarity.medium;
    }
  }
}

Future<Map<String, String>> _loadGermanNames() async {
  try {
    final raw = await rootBundle.loadString(PlantRepo._germanNamesPath);
    final data = jsonDecode(raw);
    if (data is! Map) return {};
    final out = <String, String>{};
    data.forEach((k, v) {
      final keyStr = k.toString();
      final valStr = v.toString();
      out[keyStr] = valStr;
      out[_normalizeSciName(keyStr)] = valStr; // normalized (lower, author-stripped)
    });
    return out;
  } catch (_) {
    return {};
  }
}

void _applyGermanNames(List<Plant> plants, Map<String, String> names) {
  if (names.isEmpty) return;
  for (var i = 0; i < plants.length; i++) {
    final p = plants[i];
    final german = names[p.scientificName] ??
        names[_normalizeSciName(p.scientificName)];
    if (german == null || german.trim().isEmpty) continue;

    var common = p.commonName;
    var alt = p.altCommonName;

    // If the compact dataset provided a German name, keep it as alt.
    if (common.trim().isEmpty || common == p.scientificName) {
      common = german;
    } else if (common != german) {
      alt = (alt ?? common).trim().isEmpty ? german : alt;
      common = german;
    }

    plants[i] = p.copyWith(
      commonName: common,
      altCommonName: alt,
    );
  }
}

Future<String?> _tryLoadString(String path) async {
  try {
    return await rootBundle.loadString(path);
  } on FlutterError catch (_) {
    return null;
  } catch (_) {
    return null;
  }
}
