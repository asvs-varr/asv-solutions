import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/blueprint_pdf_exporter.dart';
import 'package:banaag/domain/models.dart';
import 'package:banaag/domain/sld_engine.dart';

void main() {
  test('Generate blueprint PDF test file', () async {
    final sldData = SingleLineDiagramData(
      panelName: 'LP-1 (MAIN DISTRIBUTION PANEL)',
      utilityProvider: 'MERALCO',
      feeder: SldFeederSpec(
        totalConnectedVA: 11450,
        netDemandVA: 8250,
        netCurrentAmps: 35.87,
        mainBreakerAmps: 60,
        mainBreakerDescription: '60 AT / 100 AF, 2-Pole, 230V, 10 kAIC',
        feederWireDescription: '2 - 14.0 mm² THHN Cu',
        groundingDescription: '1 - 8.0 mm² Bare Copper Wire',
        conduitDescription: '25 mm Ø Schedule 40 PVC',
        serviceDropDescription: 'Overhead Masthead',
      ),
      branchCircuits: [
        SldBranchCircuit(
          circuitNumber: 1,
          description: 'Lighting Outlets (Living, Dining, Kitchen)',
          loadVA: 1200,
          voltage: 230,
          loadCurrentAmps: 5.22,
          breakerRatingAmps: 15,
          poles: 2,
          wireSizeDescription: '2 - 2.0 mm² THHN Cu',
          conduitDescription: '20 mm Ø PVC',
          measuredRunMeters: 14.5,
          voltageDropPercent: 0.82,
        ),
        SldBranchCircuit(
          circuitNumber: 2,
          description: 'Convenience Outlets (Living & Master BR)',
          loadVA: 1800,
          voltage: 230,
          loadCurrentAmps: 7.83,
          breakerRatingAmps: 20,
          poles: 2,
          wireSizeDescription: '2 - 3.5 mm² THHN Cu',
          conduitDescription: '20 mm Ø PVC',
          measuredRunMeters: 22.0,
          voltageDropPercent: 1.45,
        ),
        SldBranchCircuit(
          circuitNumber: 3,
          description: 'Air Conditioning Unit (Master BR - 1.5 HP)',
          loadVA: 2400,
          voltage: 230,
          loadCurrentAmps: 10.43,
          breakerRatingAmps: 30,
          poles: 2,
          wireSizeDescription: '2 - 5.5 mm² THHN Cu',
          conduitDescription: '20 mm Ø PVC',
          measuredRunMeters: 38.5,
          voltageDropPercent: 2.12,
        ),
        SldBranchCircuit(
          circuitNumber: 4,
          description: 'Induction Cooktop / Range (Kitchen)',
          loadVA: 4500,
          voltage: 230,
          loadCurrentAmps: 19.57,
          breakerRatingAmps: 40,
          poles: 2,
          wireSizeDescription: '2 - 8.0 mm² THHN Cu',
          conduitDescription: '25 mm Ø PVC',
          measuredRunMeters: 18.0,
          voltageDropPercent: 1.68,
        ),
        SldBranchCircuit(
          circuitNumber: 5,
          description: 'SPARE CIRCUIT',
          loadVA: 0,
          voltage: 230,
          loadCurrentAmps: 0,
          breakerRatingAmps: 20,
          poles: 2,
          wireSizeDescription: '-',
          conduitDescription: '-',
          measuredRunMeters: 0,
          voltageDropPercent: 0,
          isSpare: true,
        ),
      ],
    );

    final project = Project(
      id: 'proj-001',
      title: 'TWO-STOREY RESIDENTIAL BUILDING',
      clientName: 'ENGR. JUAN DELA CRUZ',
      clientContact: '0917-123-4567',
      siteAddress: 'LOT 12 BLK 4, SAN LORENZO RUIZ, MAKATI CITY',
      utilityProvider: 'Meralco',
      contractAmount: 485000,
      currentPhaseNumber: 2,
      phases: [],
      createdAt: DateTime.now(),
    );

    final pdfBytes = await BlueprintPdfExporter.generateBlueprintPdf(
      project: project,
      sldData: sldData,
    );

    final file = File('test_cad_blueprint_sheet_e1.pdf');
    await file.writeAsBytes(pdfBytes);
    print('SUCCESS: Generated test_cad_blueprint_sheet_e1.pdf (${pdfBytes.length} bytes)');
  });
}
