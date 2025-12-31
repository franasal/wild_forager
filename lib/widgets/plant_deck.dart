import 'package:flutter/material.dart';
import '../../models/plant.dart';
import 'plant_network_image.dart';

class PlantDeck extends StatelessWidget {
  final List<Plant> plants;
  final ValueChanged<Plant> onSelect;

  const PlantDeck({
    super.key,
    required this.plants,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...plants]
      ..sort((a, b) => b.frequency.compareTo(a.frequency));

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
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              children: [
                for (final p in sorted)
                  _PlantMiniCard(plant: p, onTap: () => onSelect(p)),
              ],
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
          "Sorted by nearby observations (MVP)",
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
  final VoidCallback onTap;

  const _PlantMiniCard({required this.plant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge = _badgeForFrequency(plant.frequency);

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
                    Text(
                      "Observations:",
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.65)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${plant.frequency}",
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800),
                    ),
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

_BadgeTone _badgeForFrequency(int n) {
  if (n >= 60) return _BadgeTone("Common", const Color(0xFF1A8F3F));
  if (n >= 15) return _BadgeTone("Medium", const Color(0xFFB56B00));
  return _BadgeTone("Rare", const Color(0xFFC73434));
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
