import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:wild_forager/models/plant.dart';
import 'package:wild_forager/models/plant_local_stats.dart';
import 'plant_network_image.dart';

class PlantDeck extends StatefulWidget {
  final List<Plant> plants;
  final Map<String, PlantLocalStats> localStats;
  final ValueChanged<Plant>? onFocus;
  final ValueChanged<Plant> onSelect;

  const PlantDeck({
    super.key,
    required this.plants,
    this.localStats = const {},
    this.onFocus,
    required this.onSelect,
  });

  @override
  State<PlantDeck> createState() => _PlantDeckState();
}

class _PlantDeckState extends State<PlantDeck> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  List<String> _lastIds = const [];
  bool _dragging = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = widget.plants;

    final ids = sorted.map((p) => p.id).toList();
    if (ids.isNotEmpty && ids.toString() != _lastIds.toString()) {
      _lastIds = ids;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onFocus?.call(sorted.first);
      });
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.65),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: _DeckTitle(),
                ),
                Text(
                  "${sorted.length} cards",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.35)),
          Expanded(
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              child: Listener(
                onPointerSignal: (event) {
                  if (event is! PointerScrollEvent) return;
                  if (!_controller.hasClients) return;
                  if (_dragging) return;

                  final delta = event.scrollDelta.dy;
                  final target = (_controller.offset + delta)
                      .clamp(0.0, _controller.position.maxScrollExtent);
                  _controller.jumpTo(target);
                },
                onPointerDown: (_) => _dragging = true,
                onPointerUp: (_) => _dragging = false,
                onPointerCancel: (_) => _dragging = false,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: sorted.length,
                  padEnds: false,
                  onPageChanged: (i) {
                    if (i < 0 || i >= sorted.length) return;
                    widget.onFocus?.call(sorted[i]);
                  },
                  itemBuilder: (context, i) {
                    final p = sorted[i];
                    final stats = widget.localStats[p.id];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _PlantMiniCard(
                        plant: p,
                        stats: stats,
                        onTap: () => widget.onSelect(p),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckTitle extends StatelessWidget {
  const _DeckTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("The Deck",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(
          "Top plants near you (≈10 km)",
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
          ),
        ),
      ],
    );
  }
}

class _PlantMiniCard extends StatelessWidget {
  final Plant plant;
  final PlantLocalStats? stats;
  final VoidCallback onTap;

  const _PlantMiniCard({
    required this.plant,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _badgeForRarity(plant.rarity);
    final localCount = stats?.localCount10km ?? 0;
    final total = plant.total > 0 ? plant.total : plant.sampleCount;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.35)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface.withOpacity(0.95),
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.70),
              ],
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 26,
                offset: const Offset(0, 10),
                color: Colors.black.withOpacity(
                    Theme.of(context).brightness == Brightness.dark
                        ? 0.35
                        : 0.12),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _NameBlock(
                        common: plant.commonName,
                        sci: plant.scientificName,
                      ),
                    ),
                    _Badge(text: badge.label, tone: badge.tone),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.35)),
                      bottom: BorderSide(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.35)),
                    ),
                  ),
                  child: PlantNetworkImage(
                    url: plant.image?.url,
                    fit: BoxFit.cover,
                    fallback: _FallbackVisual(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    _Metric(label: "Near you", value: "$localCount"),
                    const SizedBox(width: 10),
                    _Metric(label: "Total", value: "$total"),
                    const Spacer(),
                    Text(
                      "Tap →",
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.65)),
                    ),
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

class _NameBlock extends StatelessWidget {
  final String common;
  final String sci;
  const _NameBlock({required this.common, required this.sci});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(common,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          sci,
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FallbackVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.local_florist,
        size: 54,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
      ),
    );
  }
}

class _BadgeTone {
  final String label;
  final Color tone;
  _BadgeTone(this.label, this.tone);
}

_BadgeTone _badgeForRarity(PlantRarity rarity) {
  switch (rarity) {
    case PlantRarity.rare:
      return _BadgeTone("Rare", const Color(0xFFC73434));
    case PlantRarity.medium:
      return _BadgeTone("Medium", const Color(0xFFB56B00));
    case PlantRarity.common:
      return _BadgeTone("Common", const Color(0xFF1A8F3F));
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color tone;
  const _Badge({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.35)),
        color: tone.withOpacity(0.08),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "$label:",
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.65)),
        ),
        const SizedBox(width: 4),
        Text(value,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
