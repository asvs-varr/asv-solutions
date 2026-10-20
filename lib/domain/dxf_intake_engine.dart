// BANAAG DXF & Floor Plan Ingestion Engine
// Handles messy single-layer CAD files (e.g., student drawings where everything is on "Layer 0"),
// extracts electrical blocks/text labels, and converts non-compliant geometry into a vector underlay.

import 'dart:math' as math;
import 'models.dart';
import 'pec_auto_placement_engine.dart';

enum DxfComplianceGrade {
  fullyLayeredCompliant, // Standard E-LITE, E-POWR, A-WALL layers
  semiCompliantWithText, // Blocks and text tags present, but layer names non-standard
  messySingleLayerGeometry, // Everything dumped onto Layer 0 / no electrical symbols
}

class DxfEntity {
  final String type; // LINE, LWPOLYLINE, CIRCLE, TEXT, MTEXT, INSERT
  final String layer;
  final Map<String, dynamic> properties;

  const DxfEntity({
    required this.type,
    required this.layer,
    required this.properties,
  });
}

class DxfParseResult {
  final DxfComplianceGrade grade;
  final String fileName;
  final int totalEntities;
  final List<String> detectedLayers;
  final List<CanvasPoint> extractedElectricalPoints;
  final List<ConduitRoute> extractedConduitRoutes;
  final List<DxfEntity> underlayGeometry;
  final double boundingWidthMeters;
  final double boundingHeightMeters;
  final String diagnosticMessage;

  const DxfParseResult({
    required this.grade,
    required this.fileName,
    required this.totalEntities,
    required this.detectedLayers,
    required this.extractedElectricalPoints,
    required this.extractedConduitRoutes,
    required this.underlayGeometry,
    required this.boundingWidthMeters,
    required this.boundingHeightMeters,
    required this.diagnosticMessage,
  });
}

class DxfIntakeEngine {
  /// Hybrid Smart Filter: Parses raw DXF text content
  static DxfParseResult parseDxfContent(String content, {String fileName = 'drawing.dxf'}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final List<DxfEntity> entities = [];
    final Set<String> layers = {};

    int i = 0;
    while (i < lines.length - 1) {
      final code = lines[i].trim();
      final val = lines[i + 1].trim();

      if (code == '0' && val != 'SECTION' && val != 'ENDSEC' && val != 'EOF' && val != 'TABLE' && val != 'ENDTAB') {
        final entityType = val;
        i += 2;
        String currentLayer = '0';
        final Map<String, dynamic> props = {};

        while (i < lines.length - 1) {
          final pCode = lines[i].trim();
          final pVal = lines[i + 1].trim();
          if (pCode == '0') break; // Next entity starts

          if (pCode == '8') {
            currentLayer = pVal;
            layers.add(pVal);
          } else if (pCode == '10') {
            props['x1'] = double.tryParse(pVal) ?? 0.0;
          } else if (pCode == '20') {
            props['y1'] = double.tryParse(pVal) ?? 0.0;
          } else if (pCode == '11') {
            props['x2'] = double.tryParse(pVal) ?? 0.0;
          } else if (pCode == '21') {
            props['y2'] = double.tryParse(pVal) ?? 0.0;
          } else if (pCode == '40') {
            props['radius'] = double.tryParse(pVal) ?? 1.0;
          } else if (pCode == '1' || pCode == '3') {
            props['text'] = pVal;
          } else if (pCode == '2') {
            props['blockName'] = pVal;
          }
          i += 2;
        }

        entities.add(DxfEntity(
          type: entityType,
          layer: currentLayer,
          properties: props,
        ));
        continue;
      }
      i++;
    }

    // Determine Bounding Box
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final e in entities) {
      if (e.properties.containsKey('x1')) {
        final x = e.properties['x1'] as double;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
      }
      if (e.properties.containsKey('y1')) {
        final y = e.properties['y1'] as double;
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
      if (e.properties.containsKey('x2')) {
        final x = e.properties['x2'] as double;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
      }
      if (e.properties.containsKey('y2')) {
        final y = e.properties['y2'] as double;
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }

    final double width = (maxX > minX && minX != double.infinity) ? (maxX - minX) : 10.0;
    final double height = (maxY > minY && minY != double.infinity) ? (maxY - minY) : 8.0;

    // Check for Standard Electrical Layers
    final bool hasLiteLayer = layers.any((l) => l.toUpperCase().contains('LITE') || l.toUpperCase().contains('LIGHT'));
    final bool hasPowrLayer = layers.any((l) => l.toUpperCase().contains('POWR') || l.toUpperCase().contains('OUTLET') || l.toUpperCase().contains('CO'));

    final List<CanvasPoint> points = [];
    final List<ConduitRoute> routes = [];

    // Scan for Electrical Entities via Text/Blocks
    int ptIndex = 1;
    for (final e in entities) {
      final text = (e.properties['text'] ?? '').toString().toUpperCase();
      final block = (e.properties['blockName'] ?? '').toString().toUpperCase();
      final x = (e.properties['x1'] as num?)?.toDouble() ?? 100.0;
      final y = (e.properties['y1'] as num?)?.toDouble() ?? 100.0;

      if (text.contains('PANEL') || text.contains('LP') || text.contains('MDP') || block.contains('PANEL')) {
        points.add(CanvasPoint(id: 'pt-dxf-${ptIndex++}', type: 'PANEL', label: text.isNotEmpty ? text : 'Panel LP-1', x: x, y: y));
      } else if (text.contains('ACU') || text.contains('AIRCON') || block.contains('ACU')) {
        points.add(CanvasPoint(id: 'pt-dxf-${ptIndex++}', type: 'ACU', label: text.isNotEmpty ? text : 'ACU Unit', x: x, y: y));
      } else if (text.contains('OUTLET') || text.contains('DUPLEX') || text.contains('CO') || block.contains('OUTLET')) {
        points.add(CanvasPoint(id: 'pt-dxf-${ptIndex++}', type: 'OUTLET_DUPLEX', label: text.isNotEmpty ? text : 'Duplex Outlet', x: x, y: y));
      } else if (text.startsWith('S1') || text.startsWith('S2') || text.startsWith('S3') || text == 'SW' || block.contains('SWITCH')) {
        points.add(CanvasPoint(id: 'pt-dxf-${ptIndex++}', type: 'SWITCH_1G', label: text.isNotEmpty ? text : 'Switch', x: x, y: y));
      } else if (text.contains('LIGHT') || text.contains('LAMP') || text.contains('LED') || block.contains('LIGHT')) {
        points.add(CanvasPoint(id: 'pt-dxf-${ptIndex++}', type: 'LIGHT', label: text.isNotEmpty ? text : 'Luminaire', x: x, y: y));
      }
    }

    if (hasLiteLayer && hasPowrLayer && points.isNotEmpty) {
      return DxfParseResult(
        grade: DxfComplianceGrade.fullyLayeredCompliant,
        fileName: fileName,
        totalEntities: entities.length,
        detectedLayers: layers.toList(),
        extractedElectricalPoints: points,
        extractedConduitRoutes: routes,
        underlayGeometry: entities,
        boundingWidthMeters: width,
        boundingHeightMeters: height,
        diagnosticMessage: '✅ Fully Compliant: Natukoy ang standard electrical layers (${layers.join(", ")}). Lahat ng ${points.length} electrical symbols ay parsed nang maayos.',
      );
    } else if (points.isNotEmpty) {
      return DxfParseResult(
        grade: DxfComplianceGrade.semiCompliantWithText,
        fileName: fileName,
        totalEntities: entities.length,
        detectedLayers: layers.toList(),
        extractedElectricalPoints: points,
        extractedConduitRoutes: routes,
        underlayGeometry: entities,
        boundingWidthMeters: width,
        boundingHeightMeters: height,
        diagnosticMessage: '⚠️ Semi-Compliant: Walang standard layers, ngunit may ${points.length} electrical text tags/blocks na matagumpay na na-extract mula sa CAD file.',
      );
    } else {
      // Student Messy File: Everything on Layer 0 with only architectural lines/shapes
      // Fallback: Use all entities as vector underlay and run PEC Auto-Placement Engine
      final autoResult = PecAutoPlacementEngine.generateLayout(
        lengthMeters: width > 0 ? width.clamp(4.0, 30.0) : 8.0,
        widthMeters: height > 0 ? height.clamp(3.0, 25.0) : 6.0,
      );

      return DxfParseResult(
        grade: DxfComplianceGrade.messySingleLayerGeometry,
        fileName: fileName,
        totalEntities: entities.length,
        detectedLayers: layers.toList(),
        extractedElectricalPoints: autoResult.points,
        extractedConduitRoutes: autoResult.routes,
        underlayGeometry: entities,
        boundingWidthMeters: width,
        boundingHeightMeters: height,
        diagnosticMessage: '💡 Single-Layer (Layer 0) CAD Detected: Dahil puro architectural lines lang ang laman ng drawing, ginawa itong vector underlay at awtomatikong inilatag ang PEC Smart Electrical Plan (${autoResult.totalLights} lights, ${autoResult.totalOutlets} outlets).',
      );
    }
  }
}
