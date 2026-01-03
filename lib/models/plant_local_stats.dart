class PlantLocalStats {
  final int localCount10km;
  final double nearestDistanceKm;
  final DateTime? lastObserved;

  const PlantLocalStats({
    required this.localCount10km,
    required this.nearestDistanceKm,
    required this.lastObserved,
  });
}
