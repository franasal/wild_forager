import 'package:flutter/material.dart';
import '../../models/plant.dart';
import 'flip_card.dart';
import 'plant_network_image.dart';

class SpecimenSheet extends StatefulWidget {
  final Plant plant;
  const SpecimenSheet({super.key, required this.plant});

  @override
  State<SpecimenSheet> createState() => _SpecimenSheetState();
}

class _SpecimenSheetState extends State<SpecimenSheet> {
  bool showKitchen = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.plant;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.35)),
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                blurRadius: 60,
                offset: const Offset(0, -10),
                color: Colors.black.withOpacity(
                    Theme.of(context).brightness == Brightness.dark
                        ? 0.55
                        : 0.18),
              )
            ],
          ),
          child: Column(
            children: [
              _SheetTopBar(
                sci: p.scientificName,
                common: p.commonName,
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                  children: [
                    _SpecVisual(p: p),
                    const SizedBox(height: 12),
                    _StatsGrid(p: p),
                    const SizedBox(height: 12),
                    _Block(
                      title: "Identification markers",
                      child: Text(p.idMarkers.isEmpty
                          ? "No markers provided."
                          : p.idMarkers),
                    ),
                    if ((p.lookalikeWarning ?? "").trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Block(
                        title: "Lookalike warning",
                        tone: _BlockTone.warning,
                        child: Text(p.lookalikeWarning!.trim()),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ActionTab(
                      text: showKitchen
                          ? "Hide culinary uses"
                          : "View culinary uses →",
                      onTap: () => setState(() => showKitchen = !showKitchen),
                    ),
                    if (showKitchen) ...[
                      const SizedBox(height: 12),
                      FlipRecipeCard(recipe: p.recipe),
                    ],
                    const SizedBox(height: 12),
                    _Block(
                      title: "Safety",
                      tone: _BlockTone.danger,
                      child: const Text(
                        "Never eat anything you cannot identify with high confidence. This app is a starter pack, not a guarantee.",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SheetTopBar extends StatelessWidget {
  final String sci;
  final String common;
  final VoidCallback onClose;

  const _SheetTopBar(
      {required this.sci, required this.common, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.35))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sci,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  common,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.65)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onClose,
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}

class _SpecVisual extends StatelessWidget {
  final Plant p;
  const _SpecVisual({required this.p});

  @override
  Widget build(BuildContext context) {
    final img = p.image?.url;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlantNetworkImage(
            url: img,
            fit: BoxFit.cover,
            fallback: _Fallback(),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.black.withOpacity(0.45),
              ),
              child: Text(
                "${p.frequency} observations",
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.local_florist,
        size: 64,
        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Plant p;
  const _StatsGrid({required this.p});

  @override
  Widget build(BuildContext context) {
    // MVP "Top Trumps" stats: placeholders, can be replaced by real nutrition/season data later.
    final items = <_KV>[
      _KV("Frequency", "${p.frequency}"),
      _KV("Taxon key", p.taxonKey?.toString() ?? "—"),
      _KV("GBIF points", "${p.occurrences.length}"),
      _KV("Mode", "MVP"),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((kv) => _KvCard(kv: kv)).toList(),
    );
  }
}

class _KV {
  final String label;
  final String value;
  _KV(this.label, this.value);
}

class _KvCard extends StatelessWidget {
  final _KV kv;
  const _KvCard({required this.kv});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kv.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.4,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(kv.value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

enum _BlockTone { normal, warning, danger }

class _Block extends StatelessWidget {
  final String title;
  final Widget child;
  final _BlockTone tone;

  const _Block(
      {required this.title,
      required this.child,
      this.tone = _BlockTone.normal});

  @override
  Widget build(BuildContext context) {
    Color border = Theme.of(context).dividerColor.withOpacity(0.35);
    Color bg = Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25);

    if (tone == _BlockTone.warning) {
      border = const Color(0xFFB56B00).withOpacity(0.35);
      bg = const Color(0xFFB56B00).withOpacity(0.08);
    } else if (tone == _BlockTone.danger) {
      border = const Color(0xFFC73434).withOpacity(0.35);
      bg = const Color(0xFFC73434).withOpacity(0.08);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        color: bg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 0.3,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurface),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ActionTab extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _ActionTab({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.30)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.12),
              Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark
                      ? 0.12
                      : 0.03),
            ],
          ),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
