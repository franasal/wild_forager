import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/plant.dart';

class PlantRepoResult {
  final Map<String, dynamic>? region;
  final List<Plant> plants;
  PlantRepoResult({required this.region, required this.plants});
}

class PlantRepo {
  static Future<PlantRepoResult> loadBundledPlants() async {
    final raw = await rootBundle.loadString('assets/data/plants.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final region = data['region'] as Map<String, dynamic>?;
    final list = (data['plants'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Plant.fromJson)
        .toList();
    return PlantRepoResult(region: region, plants: list);
  }
}
