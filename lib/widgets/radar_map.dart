import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:wild_forager/models/occurrence.dart';
import 'package:wild_forager/models/plant.dart';
import 'package:wild_forager/models/plant_local_stats.dart';

enum MapTileStyle {
  osmStandard,
  bwLight,
  dark,
}

class RadarMap extends StatefulWidget {
  final LatLng user;
  final List<Plant> plants;
  final Map<String, Color> plantColors;
  final Plant? focusedPlant;
  final Map<String, PlantLocalStats> localStats;
  final VoidCallback onLocate;

  const RadarMap({
    super.key,
    required this.user,
    required this.plants,
    required this.plantColors,
    required this.focusedPlant,
    required this.localStats,
    required this.onLocate,
  });

  @override
  State<RadarMap> createState() => _RadarMapState();
}

class _RadarMapState extends State<RadarMap> {
  final MapController _mapController = MapController();
  Occurrence? _selectedOccurrence;
  MapTileStyle _tileStyle = MapTileStyle.osmStandard;
  _MapTooltipData? _tooltip;
  static const _fallbackPalette = [
    Color(0xFF1A8F3F),
    Color(0xFFB56B00),
    Color(0xFF3B5DC9),
    Color(0xFFC73434),
    Color(0xFF6C3BC9),
    Color(0xFF1294A0),
    Color(0xFF9B870C),
    Color(0xFF0F7A8A),
  ];

  @override
  void didUpdateWidget(covariant RadarMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      try {
        _mapController.move(widget.user, _mapController.camera.zoom);
      } catch (_) {
        // MapController not ready yet.
      }
    }
  }

  ({Plant plant, Occurrence occ, double distMeters})? _hitTestOccurrence(
    LatLng tap,
    List<Plant> plants,
    double radiusMeters,
  ) {
    final dist = const Distance();
    Plant? bestPlant;
    Occurrence? bestOcc;
    var best = double.infinity;

    for (final p in plants) {
      for (final o in p.occurrences) {
        final d = dist.as(LengthUnit.Meter, tap, LatLng(o.lat, o.lon));
        if (d < best) {
          best = d;
          bestPlant = p;
          bestOcc = o;
        }
      }
    }

    if (bestPlant == null || bestOcc == null) return null;
    if (best > radiusMeters) return null;
    return (plant: bestPlant, occ: bestOcc, distMeters: best);
  }

  TileLayer _buildTileLayer() {
    const cartoSubdomains = ['a', 'b', 'c', 'd'];

    switch (_tileStyle) {
      case MapTileStyle.osmStandard:
        return TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: "wild_forager",
        );
      case MapTileStyle.bwLight:
        return TileLayer(
          urlTemplate:
              "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png",
          subdomains: cartoSubdomains,
          userAgentPackageName: "wild_forager",
        );
      case MapTileStyle.dark:
        return TileLayer(
          urlTemplate:
              "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png",
          subdomains: cartoSubdomains,
          userAgentPackageName: "wild_forager",
        );
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return "—";
    return dt.toIso8601String().split('T').first;
  }

  void _setTooltip(TapPosition tapPos, _MapTooltipData? next) {
    final anchor = tapPos.relative ?? tapPos.global;
    setState(() {
      _tooltip = (next == null) ? null : next.copyWith(anchor: anchor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final circles = <CircleMarker>[];
    if (widget.plants.isNotEmpty) {
      const maxCircles = 1400;
      final perPlantCap =
          (maxCircles / widget.plants.length).ceil().clamp(50, 300);

      for (var i = 0; i < widget.plants.length; i++) {
        final plant = widget.plants[i];
        if (plant.occurrences.isEmpty) continue;
        final color = widget.plantColors[plant.id] ??
            _fallbackPalette[i % _fallbackPalette.length];
        for (final o in plant.occurrences.take(perPlantCap)) {
          circles.add(
            CircleMarker(
              point: LatLng(o.lat, o.lon),
              radius: 7,
              color: color.withOpacity(0.95),
              borderStrokeWidth: 1.5,
              borderColor: color.withOpacity(0.95),
            ),
          );
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tooltip = _tooltip;
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          Offset tooltipPos = const Offset(0, 0);
          if (tooltip != null) {
            final maxX = (w - 300).clamp(10.0, w);
            final maxY = (h - 160).clamp(10.0, h);
            final x = (tooltip.anchor.dx - 150).clamp(10.0, maxX);
            final y = (tooltip.anchor.dy - 120).clamp(10.0, maxY);
            tooltipPos = Offset(x, y);
          }

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: widget.user,
                  initialZoom: 12,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.scrollWheelZoom,
                  ),
                  onPositionChanged: (_, __) {
                    if (_tooltip != null) {
                      setState(() => _tooltip = null);
                    }
                  },
                  onTap: (tapPos, latLng) {
                    final hit = _hitTestOccurrence(latLng, widget.plants, 70);
                    if (hit == null) {
                      setState(() {
                        _selectedOccurrence = null;
                        _tooltip = null;
                      });
                      return;
                    }

                    setState(() {
                      _selectedOccurrence = hit.occ;
                    });

                    _setTooltip(
                      tapPos,
                      _MapTooltipData(
                        anchor: const Offset(0, 0),
                        title: hit.plant.commonName.isNotEmpty
                            ? hit.plant.commonName
                            : hit.plant.scientificName,
                        lines: [
                          hit.plant.scientificName,
                          "This obs: ${_fmtDate(hit.occ.eventDate)}",
                        ],
                      ),
                    );
                  },
                ),
                mapController: _mapController,
                children: [
                  _buildTileLayer(),
                  if (circles.isNotEmpty) CircleLayer(circles: circles),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.user,
                        width: 40,
                        height: 40,
                        alignment: Alignment.bottomCenter,
                        child: Icon(
                          Icons.location_on,
                          size: 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    ],
                  ),
                  if (_selectedOccurrence != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(_selectedOccurrence!.lat,
                              _selectedOccurrence!.lon),
                          radius: 9,
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.14),
                          borderStrokeWidth: 2,
                          borderColor: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.9),
                        )
                      ],
                    ),
                ],
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _HudBox(
                  title: "Radar",
                  body: "${circles.length} points",
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _HudBox(
                  title: "${widget.plants.length} plants",
                  body: circles.isEmpty ? "No markers" : "Tap markers for details",
                  alignRight: true,
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: _MapTypeButton(
                  value: _tileStyle,
                  onChanged: (v) => setState(() => _tileStyle = v),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onLocate();
                    try {
                      _mapController.move(widget.user, 14);
                    } catch (_) {
                      // Map not ready; ignore.
                    }
                  },
                  child: const Text("Locate"),
                ),
              ),
              if (tooltip != null)
                Positioned(
                  left: tooltipPos.dx,
                  top: tooltipPos.dy,
                  child: _MapTooltip(data: tooltip),
                ),
            ],
          );
        },
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

class _MapTypeButton extends StatelessWidget {
  final MapTileStyle value;
  final ValueChanged<MapTileStyle> onChanged;

  const _MapTypeButton({required this.value, required this.onChanged});

  String _label(MapTileStyle v) {
    switch (v) {
      case MapTileStyle.osmStandard:
        return "Standard";
      case MapTileStyle.bwLight:
        return "B/W";
      case MapTileStyle.dark:
        return "Dark";
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MapTileStyle>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem(
            value: MapTileStyle.osmStandard,
            child: Text(_label(MapTileStyle.osmStandard))),
        PopupMenuItem(
            value: MapTileStyle.bwLight,
            child: Text(_label(MapTileStyle.bwLight))),
        PopupMenuItem(
            value: MapTileStyle.dark, child: Text(_label(MapTileStyle.dark))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.70),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers, size: 18),
            const SizedBox(width: 8),
            Text(_label(value), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MapTooltipData {
  final Offset anchor;
  final String title;
  final List<String> lines;

  const _MapTooltipData({
    required this.anchor,
    required this.title,
    required this.lines,
  });

  _MapTooltipData copyWith({Offset? anchor, String? title, List<String>? lines}) {
    return _MapTooltipData(
      anchor: anchor ?? this.anchor,
      title: title ?? this.title,
      lines: lines ?? this.lines,
    );
  }
}

class _MapTooltip extends StatelessWidget {
  final _MapTooltipData data;
  const _MapTooltip({required this.data});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.12),
            )
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Theme.of(context).colorScheme.onSurface),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 6),
              for (final line in data.lines.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(line)),
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
