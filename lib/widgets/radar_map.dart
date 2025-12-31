import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/plant.dart';
import '../../services/hotspot_service.dart';
import '../ui/screens/home_screen.dart';

class RadarMap extends StatelessWidget {
  final LatLng user;
  final MapMode mode;
  final List<Plant> plants;
  final List<HotspotCell> hotspots;
  final VoidCallback onLocate;

  const RadarMap({
    super.key,
    required this.user,
    required this.mode,
    required this.plants,
    required this.hotspots,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    final allOcc = plants.expand((p) => p.occurrences).toList();
    final max = hotspots.isEmpty
        ? 1
        : hotspots.map((c) => c.count).reduce((a, b) => a > b ? a : b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: user,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "wild_forager",
              ),
              // Hotspots
              if (mode == MapMode.hotspots)
                CircleLayer(
                  circles: hotspots.take(250).map((c) {
                    final intensity = (c.count / max).clamp(0.0, 1.0);
                    final radiusMeters = 60 + (240 * intensity); // simple scale
                    return CircleMarker(
                      point: LatLng(c.lat, c.lon),
                      radius: radiusMeters,
                      useRadiusInMeter: true,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.18 + 0.45 * intensity),
                      borderStrokeWidth: 1,
                      borderColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.35),
                    );
                  }).toList(),
                ),

              // Points
              if (mode == MapMode.allPoints)
                CircleLayer(
                  circles: allOcc.take(600).map((o) {
                    return CircleMarker(
                      point: LatLng(o.lat, o.lon),
                      radius: 4,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.55),
                      borderStrokeWidth: 1,
                      borderColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.65),
                    );
                  }).toList(),
                ),

              // User
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: user,
                    radius: 8,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.25),
                    borderStrokeWidth: 2,
                    borderColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  )
                ],
              ),
            ],
          ),

          // HUD overlay
          Positioned(
            left: 12,
            top: 12,
            child: _HudBox(
              title: "Radar",
              body: mode == MapMode.hotspots ? "Hotspots" : "All points",
            ),
          ),

          Positioned(
            right: 12,
            top: 12,
            child: _HudBox(
              title: "${plants.length} cards",
              body: "${allOcc.length} points",
              alignRight: true,
            ),
          ),

          Positioned(
            right: 12,
            bottom: 12,
            child: ElevatedButton(
              onPressed: onLocate,
              child: const Text("Locate"),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudBox extends StatelessWidget {
  final String title;
  final String body;
  final bool alignRight;

  const _HudBox(
      {required this.title, required this.body, this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.70),
      ),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
