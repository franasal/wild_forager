import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:wild_forager/models/plant.dart';
import 'package:wild_forager/models/plant_local_stats.dart';
import 'package:wild_forager/services/location_service.dart';
import 'package:wild_forager/services/plant_repo.dart';
import 'package:wild_forager/widgets/plant_list.dart';
import 'package:wild_forager/widgets/radar_map.dart';
import 'package:wild_forager/widgets/specimen_sheet.dart';

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
  List<Plant> sortedPlants = [];
  Set<String> selectedIds = {};
  Map<String, PlantLocalStats> localStats = {};
  LatLng? _lastStatsLocation;
  LatLng user = const LatLng(51.3397, 12.3731);
  String regionName = "Loading…";
  String hudMode = "Loading dataset…";
  Plant? focusedPlant;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      hudMode = "Loading offline dataset…";
      plants = [];
      sortedPlants = [];
      selectedIds = {};
      localStats = {};
    });

    final repo = await PlantRepo.loadBundledPlants();
    plants = repo.plants;
    selectedIds = plants.map((p) => p.id).toSet();
    regionName = repo.region?['name']?.toString() ?? "Offline dataset";

    final center = repo.region?['center'] as Map<String, dynamic>?;
    if (center != null &&
        center['lat'] is num &&
        center['lon'] is num) {
      user = LatLng(
        (center['lat'] as num).toDouble(),
        (center['lon'] as num).toDouble(),
      );
    }

    await _recomputeLocalStats(location: user, force: true);
    _recomputeSelection();
    await _locateUser();

    setState(() {
      hudMode = hudMode.isEmpty ? "Offline dataset ready" : hudMode;
    });
  }

  Future<void> _locateUser() async {
    hudMode = "Getting location…";
    setState(() {});
    final pos = await LocationService.getPosition();
    if (pos == null) {
      hudMode = "Using region center";
      setState(() {});
      return;
    }
    final next = LatLng(pos.latitude, pos.longitude);
    user = next;
    hudMode = "Using device location";
    await _recomputeLocalStats(location: next);
    _recomputeSelection();
    setState(() {});
  }

  Future<void> _recomputeLocalStats({
    required LatLng location,
    bool force = false,
  }) async {
    if (!force &&
        _lastStatsLocation != null &&
        _distanceKm(_lastStatsLocation!, location) < 1) {
      return;
    }

    final stats = <String, PlantLocalStats>{};
    for (final p in plants) {
      stats[p.id] = _calcStatsForPlant(p, location, 10);
    }
    _lastStatsLocation = location;
    localStats = stats;
  }

  void _recomputeSelection() {
    sortedPlants = [...plants];
    sortedPlants.sort((a, b) {
      final aStat = localStats[a.id];
      final bStat = localStats[b.id];
      final aNearest = aStat?.nearestDistanceKm ?? double.infinity;
      final bNearest = bStat?.nearestDistanceKm ?? double.infinity;
      if (aNearest != bNearest) return aNearest.compareTo(bNearest);
      final aLocal = aStat?.localCount10km ?? 0;
      final bLocal = bStat?.localCount10km ?? 0;
      if (aLocal != bLocal) return bLocal.compareTo(aLocal);
      if (a.total != b.total) return b.total.compareTo(a.total);
      return (a.commonName.isNotEmpty ? a.commonName : a.scientificName)
          .compareTo(
              b.commonName.isNotEmpty ? b.commonName : b.scientificName);
    });

    if (sortedPlants.isEmpty) {
      focusedPlant = null;
    } else {
      focusedPlant = sortedPlants.firstWhere(
        (p) => selectedIds.contains(p.id),
        orElse: () => sortedPlants.first,
      );
    }
    setState(() {});
  }

  void _togglePlantSelection(Plant plant, bool selected) {
    setState(() {
      if (selected) {
        selectedIds.add(plant.id);
      } else {
        selectedIds.remove(plant.id);
      }
      if (sortedPlants.isEmpty) {
        focusedPlant = null;
      } else {
        focusedPlant = sortedPlants.firstWhere(
          (p) => selectedIds.contains(p.id),
          orElse: () => sortedPlants.first,
        );
      }
    });
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        selectedIds = plants.map((p) => p.id).toSet();
      } else {
        selectedIds.clear();
      }
      if (sortedPlants.isEmpty) {
        focusedPlant = null;
      } else {
        focusedPlant = sortedPlants.firstWhere(
          (p) => selectedIds.contains(p.id),
          orElse: () => sortedPlants.first,
        );
      }
    });
  }

  void _openPlant(Plant p) async {
    final stats = localStats[p.id];
    final debugInfo = {
      "Local (10km)": stats != null ? "${stats.localCount10km}" : "0",
      "Last obs": _fmtDate(stats?.lastObserved),
      "Nearest": (stats?.nearestDistanceKm.isFinite == true)
          ? "${stats!.nearestDistanceKm.toStringAsFixed(1)} km"
          : "—",
      "Total (country)": "${p.total}",
    };

    setState(() {
      focusedPlant = p;
    });
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpecimenSheet(
        plant: p,
        debugInfo: debugInfo,
        stats: stats,
      ),
    );
  }

  PlantLocalStats _calcStatsForPlant(
      Plant plant, LatLng location, double radiusKm) {
    final dist = const Distance();
    var count = 0;
    var nearest = double.infinity;
    DateTime? last;

    for (final o in plant.occurrences) {
      final d = dist.as(LengthUnit.Kilometer, location, LatLng(o.lat, o.lon));
      if (d < nearest) nearest = d;
      if (d <= radiusKm) count += o.count;
      final dt = o.eventDate;
      if (dt != null && (last == null || dt.isAfter(last))) {
        last = dt;
      }
    }

    return PlantLocalStats(
      localCount10km: count,
      nearestDistanceKm: nearest.isFinite ? nearest : double.infinity,
      lastObserved: last,
    );
  }

  double _distanceKm(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Kilometer, a, b);
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return "—";
    return dt.toIso8601String().split('T').first;
  }

  Map<String, Color> _colorMapFor(List<Plant> plants) {
    const palette = [
      Color(0xFF1A8F3F),
      Color(0xFFB56B00),
      Color(0xFF3B5DC9),
      Color(0xFFC73434),
      Color(0xFF6C3BC9),
      Color(0xFF1294A0),
      Color(0xFF9B870C),
      Color(0xFF0F7A8A),
    ];
    final map = <String, Color>{};
    for (var i = 0; i < plants.length; i++) {
      map[plants[i].id] = palette[i % palette.length];
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final displayPlants = selectedIds.isEmpty
        ? <Plant>[]
        : plants.where((p) => selectedIds.contains(p.id)).toList();
    final markerColors = _colorMapFor(displayPlants);

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
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.36,
                      child: RadarMap(
                        user: user,
                        plants: displayPlants,
                        plantColors: markerColors,
                        focusedPlant: focusedPlant,
                        localStats: localStats,
                        onLocate: _locateUser,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: PlantList(
                        plants: sortedPlants,
                        localStats: localStats,
                        selectedIds: selectedIds,
                        onToggle: _togglePlantSelection,
                        onToggleAll: _toggleAll,
                        onInfo: _openPlant,
                        onFocus: (p) => setState(() => focusedPlant = p),
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

  const _TopBar({
    required this.regionName,
    required this.hudMode,
    required this.onToggleTheme,
    required this.themeMode,
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
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const _Brand(),
          _Pill(text: "Region: $regionName"),
          _Pill(text: hudMode),
          TextButton(
            onPressed: onToggleTheme,
            child: Text(isLight ? "Dark" : "Bright"),
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
