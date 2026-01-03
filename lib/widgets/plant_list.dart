import 'package:flutter/material.dart';
import 'package:wild_forager/models/plant.dart';
import 'package:wild_forager/models/plant_local_stats.dart';
import 'plant_network_image.dart';

class PlantList extends StatefulWidget {
  final List<Plant> plants;
  final Map<String, PlantLocalStats> localStats;
  final Set<String> selectedIds;
  final void Function(Plant plant, bool selected) onToggle;
  final void Function(bool selectAll) onToggleAll;
  final void Function(Plant plant) onInfo;
  final ValueChanged<Plant>? onFocus;

  const PlantList({
    super.key,
    required this.plants,
    required this.localStats,
    required this.selectedIds,
    required this.onToggle,
    required this.onToggleAll,
    required this.onInfo,
    this.onFocus,
  });

  @override
  State<PlantList> createState() => _PlantListState();
}

class _PlantListState extends State<PlantList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.65),
      ),
      child: Column(
        children: [
          _Header(
            selectedCount: widget.selectedIds.length,
            total: widget.plants.length,
            onSelectAll: () => widget.onToggleAll(true),
            onDeselectAll: () => widget.onToggleAll(false),
          ),
          Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.35)),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              controller: _controller,
              child: ListView.separated(
                controller: _controller,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.plants.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                ),
                itemBuilder: (context, i) {
                  final p = widget.plants[i];
                  final stats = widget.localStats[p.id];
                  final selected = widget.selectedIds.contains(p.id);
                  return InkWell(
                    onTap: () => widget.onFocus?.call(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: _PlantRow(
                        plant: p,
                        stats: stats,
                        selected: selected,
                        onToggle: (v) => widget.onToggle(p, v),
                        onInfo: () => widget.onInfo(p),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int selectedCount;
  final int total;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  const _Header({
    required this.selectedCount,
    required this.total,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Nearby plants",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  "Sorted by distance to you",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          Text(
            "$selectedCount/$total selected",
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onSelectAll, child: const Text("Select all")),
          TextButton(onPressed: onDeselectAll, child: const Text("Clear")),
        ],
      ),
    );
  }
}

class _PlantRow extends StatelessWidget {
  final Plant plant;
  final PlantLocalStats? stats;
  final bool selected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onInfo;

  const _PlantRow({
    required this.plant,
    required this.stats,
    required this.selected,
    required this.onToggle,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final near = stats?.localCount10km ?? 0;
    final total = plant.total > 0 ? plant.total : plant.sampleCount;
    final last = stats?.lastObserved;
    final distance = stats?.nearestDistanceKm ?? double.infinity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 64,
            height: 64,
            child: PlantNetworkImage(
              url: plant.image?.url,
              fit: BoxFit.cover,
              fallback: Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Icon(Icons.local_florist,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.7)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plant.commonName.isNotEmpty
                    ? plant.commonName
                    : plant.scientificName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              if ((plant.altCommonName ?? "").trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    plant.altCommonName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.65),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  plant.scientificName,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.65),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Metric(label: "Near you", value: "$near"),
                  _Metric(label: "Total", value: "$total"),
                  if (distance.isFinite)
                    _Metric(
                        label: "Nearest",
                        value: "${distance.toStringAsFixed(1)} km"),
                  _Badge(
                      text: _badgeText(plant.rarity),
                      tone: _badgeTone(plant.rarity)),
                  TextButton(
                    onPressed: onInfo,
                    child: const Text("Info →"),
                  ),
                ],
              ),
              if (last != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    "Last observed: ${last.toIso8601String().split('T').first}",
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.65)),
                  ),
                ),
            ],
          ),
        ),
        Checkbox(
          value: selected,
          onChanged: (v) => onToggle(v ?? false),
        ),
      ],
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

String _badgeText(PlantRarity rarity) {
  switch (rarity) {
    case PlantRarity.rare:
      return "Rare";
    case PlantRarity.medium:
      return "Medium";
    case PlantRarity.common:
      return "Common";
  }
}

Color _badgeTone(PlantRarity rarity) {
  switch (rarity) {
    case PlantRarity.rare:
      return const Color(0xFFC73434);
    case PlantRarity.medium:
      return const Color(0xFFB56B00);
    case PlantRarity.common:
      return const Color(0xFF1A8F3F);
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
