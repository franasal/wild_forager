import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/plant.dart';
import '../../../services/plant_repo.dart';
import '../../../services/location_service.dart';
import '../../../services/gbif_service.dart';
import '../../../services/hotspot_service.dart';
import '../../widgets/radar_map.dart';
import '../../widgets/plant_deck.dart';
import '../../widgets/specimen_sheet.dart';

enum MapMode { hotspots, allPoints }

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  const HomeScreen(
      {super.key, required this.onToggleTheme, required this.themeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Plant> plants = [];
  LatLng user = const LatLng(51.3397, 12.3731);
  String regionName = "Loading…";
  String hudMode = "Loading…";
  MapMode mode = MapMode.hotspots;

  Plant? selected;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      loading = true;
      hudMode = "Loading plant metadata…";
    });

    final repo = await PlantRepo.loadBundledPlants();
    plants = repo.plants;
    regionName = repo.region?['name']?.toString() ?? "Local Starter Pack";

    // Resolve missing taxonKeys (optional but useful)
    hudMode = "Resolving GBIF taxa…";
    setState(() {});
    for (final p in plants) {
      if (p.taxonKey != null) continue;
      final key = await GbifService.resolveTaxonKey(p.scientificName);
      if (key != null) p.taxonKey = key;
    }

    // Get GPS
    hudMode = "Getting location…";
    setState(() {});
    final pos = await LocationService.getPosition();
    if (pos != null) {
      user = LatLng(pos.latitude, pos.longitude);
    }

    // Fetch occurrences
    final keys = plants
        .where((p) => p.taxonKey != null)
        .map((p) => p.taxonKey!)
        .toList();
    if (keys.isNotEmpty) {
      hudMode = "Fetching GBIF observations…";
      setState(() {});
      try {
        final byKey = await GbifService.fetchOccurrencesByTaxa(
          lat: user.latitude,
          lon: user.longitude,
          taxonKeys: keys,
          radiusKm: 10,
          limit: 300,
        );
        for (final p in plants) {
          final k = p.taxonKey;
          if (k == null) continue;
          p.occurrences = byKey[k] ?? [];
        }
        hudMode =
            "GBIF loaded: ${plants.fold<int>(0, (s, p) => s + p.occurrences.length)} points";
      } catch (_) {
        hudMode = "GBIF failed, using offline metadata";
      }
    } else {
      hudMode = "No taxon keys resolved (metadata only)";
    }

    setState(() {
      loading = false;
    });
  }

  void _openPlant(Plant p) async {
    setState(() {
      selected = p;
    });
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpecimenSheet(plant: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allOccurrences = plants.expand((p) => p.occurrences).toList();
    final hotspots = HotspotService.aggregate(allOccurrences, gridKm: 1);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _TopBar(
                regionName: regionName,
                hudMode: hudMode,
                onToggleTheme: widget.onToggleTheme,
                themeMode: widget.themeMode,
                onMode: (m) => setState(() => mode = m),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.36,
                      child: RadarMap(
                        user: user,
                        mode: mode,
                        plants: plants,
                        hotspots: hotspots,
                        onLocate: _boot,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PlantDeck(
                        plants: plants,
                        onSelect: _openPlant,
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String regionName;
  final String hudMode;
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final ValueChanged<MapMode> onMode;

  const _TopBar({
    required this.regionName,
    required this.hudMode,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onMode,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = themeMode == ThemeMode.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context)
            .colorScheme
            .surface
            .withOpacity(isLight ? 0.85 : 0.55),
      ),
      child: Row(
        children: [
          const _Brand(),
          const Spacer(),
          _Pill(text: "Region: $regionName"),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onToggleTheme,
            child: Text(isLight ? "Dark" : "Bright"),
          ),
          PopupMenuButton<MapMode>(
            onSelected: onMode,
            itemBuilder: (_) => const [
              PopupMenuItem(value: MapMode.hotspots, child: Text("Hotspots")),
              PopupMenuItem(
                  value: MapMode.allPoints, child: Text("All points")),
            ],
            child: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("Wild Forager",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 2),
        Text("Foraging MVP (Local Edition)",
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.55),
      ),
      child: Text(text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
    );
  }
}
