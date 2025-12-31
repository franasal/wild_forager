import 'package:flutter/material.dart';
import '../../models/plant.dart';

class FlipRecipeCard extends StatefulWidget {
  final PlantRecipe recipe;
  const FlipRecipeCard({super.key, required this.recipe});

  @override
  State<FlipRecipeCard> createState() => _FlipRecipeCardState();
}

class _FlipRecipeCardState extends State<FlipRecipeCard> {
  bool flipped = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) {
            final rotate = Tween<double>(begin: 0.98, end: 1.0).animate(anim);
            return ScaleTransition(scale: rotate, child: child);
          },
          child: flipped
              ? _BackFace(
                  key: const ValueKey("back"),
                  recipe: r,
                  onFlipBack: () => setState(() => flipped = false),
                )
              : _FrontFace(
                  key: const ValueKey("front"),
                  onFlip: () => setState(() => flipped = true),
                ),
        ),
      ],
    );
  }
}

class _FrontFace extends StatelessWidget {
  final VoidCallback onFlip;
  const _FrontFace({super.key, required this.onFlip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Kitchen",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            "Tap “Flip card” to see preparation + a simple recipe.",
            style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onFlip,
                  child: const Text("Flip card"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackFace extends StatelessWidget {
  final PlantRecipe recipe;
  final VoidCallback onFlipBack;

  const _BackFace({super.key, required this.recipe, required this.onFlipBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface.withOpacity(0.95),
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.65),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recipe card (MVP)",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 10),
          _Line(label: "Preparation", value: recipe.prep),
          const SizedBox(height: 10),
          _Line(label: "Simple recipe", value: recipe.simple),
          const SizedBox(height: 10),
          _Line(label: "Pairing", value: recipe.pairing),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onFlipBack,
                  child: const Text("Flip back"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.35)),
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.35)),
        ],
      ),
    );
  }
}
