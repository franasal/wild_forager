import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/plant.dart';
import '../../models/occurrence.dart';
import '../../services/hotspot_service.dart';
import '../ui/screens/home_screen.dart';

enum MapTileStyle {
  osmStandard,
  bwLight,
  dark,
}

class RadarMap extends StatefulWidget {
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
  State<RadarMap> createState() => _RadarMapState();
}

class _RadarMapState extends State<RadarMap> {
  final MapController _mapController = MapController();
  HotspotCell? _selectedHotspot;
  Occurrence? _selectedOccurrence;
  MapTileStyle _tileStyle = MapTileStyle.osmStandard;
  _MapTooltipData? _tooltip;

  @override
  void didUpdateWidget(covariant RadarMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode && widget.mode != MapMode.hotspots) {
      _selectedHotspot = null;
    }
    if (widget.mode != oldWidget.mode && widget.mode != MapMode.allPoints) {
      _selectedOccurrence = null;
    }
  }

  ({HotspotCell cell, double radiusMeters})? _hitTestHotspot(
    LatLng tap,
    List<HotspotCell> hotspots,
    int maxCount,
  ) {
    if (hotspots.isEmpty) return null;

    final dist = const Distance();

    HotspotCell? best;
    double bestRatio = 0;
    double bestRadius = 0;

    for (final c in hotspots.take(400)) {
      final intensity = (c.count / (maxCount == 0 ? 1 : maxCount))
          .clamp(0.0, 1.0)
          .toDouble();
      final radiusMeters = 60 + (240 * intensity);
      final d = dist.as(LengthUnit.Meter, tap, LatLng(c.lat, c.lon));
      if (d > radiusMeters) continue;

      final ratio = 1 - (d / radiusMeters);
      if (ratio > bestRatio) {
        best = c;
        bestRatio = ratio;
        bestRadius = radiusMeters;
      }
    }

    if (best == null) return null;
    return (cell: best, radiusMeters: bestRadius);
  }

  ({int count, DateTime? lastObserved}) _countAndLastInRadius(
    Plant plant,
    LatLng center,
    double radiusMeters,
  ) {
    final dist = const Distance();
    var count = 0;
    DateTime? last;

    for (final o in plant.occurrences) {
      final d = dist.as(LengthUnit.Meter, center, LatLng(o.lat, o.lon));
      if (d > radiusMeters) continue;
      count += o.count;
      final dt = o.eventDate;
      if (dt != null && (last == null || dt.isAfter(last))) last = dt;
    }

    return (count: count, lastObserved: last);
  }

  DateTime? _lastObservedOverall(Plant plant) {
    DateTime? last;
    for (final o in plant.occurrences) {
      final dt = o.eventDate;
      if (dt != null && (last == null || dt.isAfter(last))) last = dt;
    }
    return last;
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

  @override
  Widget build(BuildContext context) {
    final allOcc = widget.plants.expand((p) => p.occurrences).toList();
    final max = widget.hotspots.isEmpty
        ? 1
        : widget.hotspots.map((c) => c.count).reduce((a, b) => a > b ? a : b);

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
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.scrollWheelZoom,
                  ),
                  onPositionChanged: (_, __) {
                    if (_tooltip == null) return;
                    setState(() => _tooltip = null);
                  },
                  onTap: (tapPos, latLng) {
                    if (widget.mode == MapMode.hotspots) {
                      final hit = _hitTestHotspot(
                          latLng, widget.hotspots, max);
                      if (hit == null) {
                        setState(() {
                          _selectedHotspot = null;
                          _tooltip = null;
                        });
                        return;
                      }

                      final center = LatLng(hit.cell.lat, hit.cell.lon);
                      final top = <({Plant plant, int count, DateTime? last})>[];
                      for (final p in widget.plants) {
                        final stats = _countAndLastInRadius(
                          p,
                          center,
                          hit.radiusMeters,
                        );
                        if (stats.count <= 0) continue;
                        top.add((
                          plant: p,
                          count: stats.count,
                          last: stats.lastObserved,
                        ));
                      }
                      top.sort((a, b) => b.count.compareTo(a.count));

                      setState(() {
                        _selectedHotspot = hit.cell;
                        _selectedOccurrence = null;
                      });

                      if (top.isEmpty) {
                        _setTooltip(
                          tapPos,
                          _MapTooltipData(
                            anchor: const Offset(0, 0),
                            title: "Hotspot",
                            lines: [
                              "Obs: ${hit.cell.count}",
                              "Center: ${hit.cell.lat.toStringAsFixed(4)}, ${hit.cell.lon.toStringAsFixed(4)}",
                              "Last obs: —",
                            ],
                          ),
                        );
                        return;
                      }

                      final best = top.first;
                      _setTooltip(
                        tapPos,
                        _MapTooltipData(
                          anchor: const Offset(0, 0),
                          title: best.plant.commonName,
                          lines: [
                            best.plant.scientificName,
                            "Nearby obs: ${best.count}",
                            "Last obs: ${_fmtDate(best.last)}",
                          ],
                        ),
                      );
                      return;
                    }

                    if (widget.mode == MapMode.allPoints) {
                      final hit = _hitTestOccurrence(latLng, widget.plants, 70);
                      if (hit == null) {
                        setState(() {
                          _selectedOccurrence = null;
                          _tooltip = null;
                        });
                        return;
                      }

                      setState(() {
                        _selectedHotspot = null;
                        _selectedOccurrence = hit.occ;
                      });

                      _setTooltip(
                        tapPos,
                        _MapTooltipData(
                          anchor: const Offset(0, 0),
                          title: hit.plant.commonName,
                          lines: [
                            hit.plant.scientificName,
                            "This obs: ${_fmtDate(hit.occ.eventDate)}",
                            "Last obs: ${_fmtDate(_lastObservedOverall(hit.plant))}",
                          ],
                        ),
                      );
                    }
                  },
                ),
                mapController: _mapController,
                children: [
                  _buildTileLayer(),
                  // Hotspots
                  if (widget.mode == MapMode.hotspots)
                    CircleLayer(
                      circles: widget.hotspots.take(250).map((c) {
                        final intensity = (c.count / max).clamp(0.0, 1.0);
                        final radiusMeters =
                            60 + (240 * intensity); // simple scale
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
                  if (widget.mode == MapMode.allPoints)
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
                        point: widget.user,
                        radius: 8,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.25),
                        borderStrokeWidth: 2,
                        borderColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.8),
                      )
                    ],
                  ),

                  if (_selectedHotspot != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(
                              _selectedHotspot!.lat, _selectedHotspot!.lon),
                          radius: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.18),
                          borderStrokeWidth: 2,
                          borderColor: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.9),
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

              // HUD overlay
              Positioned(
                left: 12,
                top: 12,
                child: _HudBox(
                  title: "Radar",
                  body: widget.mode == MapMode.hotspots
                      ? "Hotspots"
                      : "All points",
                ),
              ),

              Positioned(
                right: 12,
                top: 12,
                child: _HudBox(
                  title: "${widget.plants.length} cards",
                  body: "${allOcc.length} points",
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
                  onPressed: widget.onLocate,
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
