// BANAAG Illuminance Grid & Fixture Placement Engine
// Follows IESNA Symmetrical Spacing (d/2 from wall, d between luminaires)
// and point-by-point lux contour / maintained illuminance calculation.

import 'dart:math' as math;
import 'lighting_engine.dart';

class FixturePlacement {
  final int index;
  final double xMeters;
  final double yMeters;
  final String label;

  const FixturePlacement({
    required this.index,
    required this.xMeters,
    required this.yMeters,
    required this.label,
  });
}

class IlluminanceLayoutResult {
  final double lengthMeters;
  final double widthMeters;
  final double ceilingHeightMeters;
  final RoomType roomType;
  final int targetLux;
  final int totalFixtures;
  final int rows;
  final int columns;
  final double spacingXMeters;
  final double spacingYMeters;
  final double wallDistanceXMeters;
  final double wallDistanceYMeters;
  final double maintainedAverageLux;
  final double minLux;
  final double maxLux;
  final double uniformityRatio; // U0 = Min / Avg (target >= 0.60)
  final String fixtureModelName;
  final int lumensPerFixture;
  final int wattagePerFixture;
  final List<FixturePlacement> fixtures;

  const IlluminanceLayoutResult({
    required this.lengthMeters,
    required this.widthMeters,
    required this.ceilingHeightMeters,
    required this.roomType,
    required this.targetLux,
    required this.totalFixtures,
    required this.rows,
    required this.columns,
    required this.spacingXMeters,
    required this.spacingYMeters,
    required this.wallDistanceXMeters,
    required this.wallDistanceYMeters,
    required this.maintainedAverageLux,
    required this.minLux,
    required this.maxLux,
    required this.uniformityRatio,
    required this.fixtureModelName,
    required this.lumensPerFixture,
    required this.wattagePerFixture,
    required this.fixtures,
  });
}

class IlluminanceGridEngine {
  IlluminanceGridEngine._();

  /// Computes optimal IESNA d/2 grid layout and point-by-point illuminance
  static IlluminanceLayoutResult computeLayout({
    required double lengthMeters,
    required double widthMeters,
    double ceilingHeightMeters = 2.7,
    RoomType roomType = RoomType.bedroom,
    LightingTier tier = LightingTier.standard,
  }) {
    final double safeLength = lengthMeters <= 0.5 ? 4.0 : lengthMeters;
    final double safeWidth = widthMeters <= 0.5 ? 3.0 : widthMeters;
    final double areaSqm = safeLength * safeWidth;

    // Use base recommendation
    final rec = LightingEngine.calculate(
      roomType: roomType,
      areaSqm: areaSqm,
      ceilingHeightMeters: ceilingHeightMeters,
      tier: tier,
    );

    int count = rec.fixtureCount;
    if (count <= 0) count = 1;

    // Determine grid rows and columns based on aspect ratio L/W
    int cols = 1;
    int rows = 1;

    if (count == 1) {
      cols = 1;
      rows = 1;
    } else if (count == 2) {
      if (safeLength >= safeWidth) {
        cols = 2;
        rows = 1;
      } else {
        cols = 1;
        rows = 2;
      }
    } else if (count == 3) {
      if (safeLength >= safeWidth * 1.4) {
        cols = 3;
        rows = 1;
      } else {
        cols = 3;
        rows = 1;
      }
    } else if (count == 4) {
      cols = 2;
      rows = 2;
    } else if (count <= 6) {
      if (safeLength >= safeWidth) {
        cols = 3;
        rows = 2;
      } else {
        cols = 2;
        rows = 3;
      }
      count = 6;
    } else {
      // 8 or more fixtures
      if (safeLength >= safeWidth) {
        cols = 4;
        rows = 2;
      } else {
        cols = 2;
        rows = 4;
      }
      count = 8;
    }

    // IESNA d/2 Spacing Rule:
    // Distance between fixtures: Sx = L / cols, Sy = W / rows
    // Distance from wall: dx = Sx / 2, dy = Sy / 2
    final double spacingX = safeLength / cols;
    final double spacingY = safeWidth / rows;
    final double wallDistX = spacingX / 2.0;
    final double wallDistY = spacingY / 2.0;

    final List<FixturePlacement> placements = [];
    int idx = 1;
    for (int r = 0; r < rows; r++) {
      final double yPos = wallDistY + (r * spacingY);
      for (int c = 0; c < cols; c++) {
        final double xPos = wallDistX + (c * spacingX);
        placements.add(FixturePlacement(
          index: idx,
          xMeters: xPos,
          yMeters: yPos,
          label: 'L$idx',
        ));
        idx++;
      }
    }

    // Point-by-point lux sampling (5x5 grid) to compute average, min, max, and uniformity
    final double workplaneHeight = 0.75; // Standard 0.75m desk/counter height
    final double mountingHeight = math.max(1.0, ceilingHeightMeters - workplaneHeight);
    final double lumenPerFixture = rec.lumensPerFixture.toDouble();

    final List<double> luxSamples = [];
    const int sampleSteps = 6;
    for (int i = 0; i <= sampleSteps; i++) {
      final double sx = (safeLength * i) / sampleSteps;
      for (int j = 0; j <= sampleSteps; j++) {
        final double sy = (safeWidth * j) / sampleSteps;

        // Sum contributions from all fixtures using Inverse Square Law with cosine correction
        double ptLux = 0.0;
        for (final fix in placements) {
          final double dx = sx - fix.xMeters;
          final double dy = sy - fix.yMeters;
          final double dHorizontalSq = (dx * dx) + (dy * dy);
          final double distanceSq = dHorizontalSq + (mountingHeight * mountingHeight);
          final double distance = math.sqrt(distanceSq);

          // cos(theta) = mountingHeight / distance
          final double cosTheta = mountingHeight / distance;
          // Approximate candela I0 = Lumens / pi for Lambertian LED luminaire
          final double intensityCandela = lumenPerFixture / math.pi;
          // E = (I * cos^3(theta)) / h^2 = (I * cos(theta)) / d^2
          final double luxContrib = (intensityCandela * cosTheta) / distanceSq;
          ptLux += luxContrib;
        }

        // Add 20% room inter-reflection contribution for light colored walls
        ptLux *= 1.25;
        luxSamples.add(ptLux);
      }
    }

    luxSamples.sort();
    final double minLux = luxSamples.first;
    final double maxLux = luxSamples.last;
    final double avgLux = luxSamples.reduce((a, b) => a + b) / luxSamples.length;
    final double uniformity = (avgLux > 0) ? (minLux / avgLux).clamp(0.0, 1.0) : 0.0;

    return IlluminanceLayoutResult(
      lengthMeters: safeLength,
      widthMeters: safeWidth,
      ceilingHeightMeters: ceilingHeightMeters,
      roomType: roomType,
      targetLux: roomType.recommendedLux,
      totalFixtures: placements.length,
      rows: rows,
      columns: cols,
      spacingXMeters: spacingX,
      spacingYMeters: spacingY,
      wallDistanceXMeters: wallDistX,
      wallDistanceYMeters: wallDistY,
      maintainedAverageLux: avgLux,
      minLux: minLux,
      maxLux: maxLux,
      uniformityRatio: uniformity,
      fixtureModelName: rec.primaryFixtureName,
      lumensPerFixture: rec.lumensPerFixture,
      wattagePerFixture: rec.recommendedWattagePerFixture,
      fixtures: placements,
    );
  }
}
