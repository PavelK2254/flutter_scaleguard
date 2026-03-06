/// Metrics about finding concentration in hotspots (for debug output).
class HotspotMetrics {
  const HotspotMetrics({
    required this.totalFindings,
    required this.concentration,
    required this.top3Share,
    this.largestHotspot,
  });

  final int totalFindings;
  final double concentration;
  final double top3Share;
  final LargestHotspot? largestHotspot;
}

/// Path and finding count for the single largest hotspot.
class LargestHotspot {
  const LargestHotspot({required this.path, required this.findings});

  final String path;
  final int findings;
}
