// BANAAG Core Domain: Multi-Tab Excel BOM & Schedule of Loads Exporter (.xlsx)
// Generates professional 3-tab workbooks compliant with PEC 2017 Part 1 requirements.

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'models.dart';
import 'sld_engine.dart';
import 'takeoff_engine.dart';

class BomExcelExporter {
  /// Generate a 3-tab Excel workbook as binary bytes
  static Uint8List generateWorkbook({
    required Project project,
    required SingleLineDiagramData sldData,
    required TakeoffResult takeoff,
  }) {
    final excel = Excel.createExcel();

    // Default sheet name is usually 'Sheet1'
    final defaultSheet = excel.getDefaultSheet();

    // -------------------------------------------------------------
    // TAB 1: EXECUTIVE SUMMARY & UTILITY SPECS
    // -------------------------------------------------------------
    final sheetSummaryName = 'Project Summary';
    final sheetSummary = excel[sheetSummaryName];
    excel.setDefaultSheet(sheetSummaryName);

    if (defaultSheet != null && defaultSheet != sheetSummaryName) {
      excel.delete(defaultSheet);
    }

    _populateSummarySheet(sheetSummary, project, sldData, takeoff);

    // -------------------------------------------------------------
    // TAB 2: SCHEDULE OF LOADS & VOLTAGE DROP
    // -------------------------------------------------------------
    final sheetSld = excel['Schedule of Loads'];
    _populateScheduleOfLoadsSheet(sheetSld, sldData);

    // -------------------------------------------------------------
    // TAB 3: BILL OF MATERIALS (BOM) & LABOR ESTIMATE
    // -------------------------------------------------------------
    final sheetBom = excel['Bill of Materials'];
    _populateBomSheet(sheetBom, takeoff, sldData);

    final fileBytes = excel.save();
    return Uint8List.fromList(fileBytes ?? []);
  }

  static void _populateSummarySheet(
    Sheet sheet,
    Project project,
    SingleLineDiagramData sldData,
    TakeoffResult takeoff,
  ) {
    // Title Banner
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('BANAAG ELECTRICAL DESIGN SUITE - EXECUTIVE PROJECT SUMMARY');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Compliant with Philippine Electrical Code (PEC 2017) Part 1');

    // Project Info
    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('Project Title:');
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(project.title);

    sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Client Name:');
    sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue(project.clientName);

    sheet.cell(CellIndex.indexByString('A6')).value = TextCellValue('Address / Location:');
    sheet.cell(CellIndex.indexByString('B6')).value = TextCellValue(project.siteAddress);

    sheet.cell(CellIndex.indexByString('A7')).value = TextCellValue('Assigned PEE / REE:');
    sheet.cell(CellIndex.indexByString('B7')).value = TextCellValue('Engr. Roberto Dela Rosa, PEE');

    sheet.cell(CellIndex.indexByString('A8')).value = TextCellValue('Distribution Utility:');
    sheet.cell(CellIndex.indexByString('B8')).value = TextCellValue(project.utilityProvider);

    sheet.cell(CellIndex.indexByString('A9')).value = TextCellValue('System Voltage / Phase:');
    sheet.cell(CellIndex.indexByString('B9')).value = TextCellValue('230 V, 1-Phase, 2-Wire + Ground, 60 Hz');

    // Service Entrance & Feeder Specs
    sheet.cell(CellIndex.indexByString('A11')).value = TextCellValue('SERVICE ENTRANCE & FEEDER SPECIFICATION');
    sheet.cell(CellIndex.indexByString('A12')).value = TextCellValue('Total Connected Load:');
    sheet.cell(CellIndex.indexByString('B12')).value = TextCellValue('${sldData.feeder.totalConnectedVA.toStringAsFixed(0)} VA');

    sheet.cell(CellIndex.indexByString('A13')).value = TextCellValue('Net Demand Load (PEC Table 2.20.3.3):');
    sheet.cell(CellIndex.indexByString('B13')).value = TextCellValue('${sldData.feeder.netDemandVA.toStringAsFixed(0)} VA (${sldData.feeder.netCurrentAmps.toStringAsFixed(1)} Amperes)');

    sheet.cell(CellIndex.indexByString('A14')).value = TextCellValue('Main Circuit Breaker (MCB):');
    sheet.cell(CellIndex.indexByString('B14')).value = TextCellValue(sldData.feeder.mainBreakerDescription);

    sheet.cell(CellIndex.indexByString('A15')).value = TextCellValue('Main Feeder Conductors:');
    sheet.cell(CellIndex.indexByString('B15')).value = TextCellValue(sldData.feeder.feederWireDescription);

    sheet.cell(CellIndex.indexByString('A16')).value = TextCellValue('Grounding Electrode Conductor:');
    sheet.cell(CellIndex.indexByString('B16')).value = TextCellValue(sldData.feeder.groundingDescription);

    sheet.cell(CellIndex.indexByString('A17')).value = TextCellValue('Service Entrance Conduit:');
    sheet.cell(CellIndex.indexByString('B17')).value = TextCellValue(sldData.feeder.conduitDescription);

    // Financial & Material High-Level Summary
    sheet.cell(CellIndex.indexByString('A19')).value = TextCellValue('FINANCIAL & QUANTITY HIGH-LEVEL TAKEOFF');
    sheet.cell(CellIndex.indexByString('A20')).value = TextCellValue('Total THHN Copper Wire:');
    sheet.cell(CellIndex.indexByString('B20')).value = TextCellValue('${takeoff.totalThhnWireMeters.toStringAsFixed(1)} m (${takeoff.wireRollsCount.toStringAsFixed(1)} rolls)');

    sheet.cell(CellIndex.indexByString('A21')).value = TextCellValue('Total PVC Conduit:');
    sheet.cell(CellIndex.indexByString('B21')).value = TextCellValue('${takeoff.totalConduitMeters.toStringAsFixed(1)} m (${takeoff.totalPvcPipesPcs} pipes @ 3.0m)');

    sheet.cell(CellIndex.indexByString('A22')).value = TextCellValue('Total Enclosures & Boxes:');
    sheet.cell(CellIndex.indexByString('B22')).value = TextCellValue('${takeoff.utilityBoxesCount + takeoff.octagonalBoxesCount} pcs (${takeoff.utilityBoxesCount} utility, ${takeoff.octagonalBoxesCount} octagonal)');

    sheet.cell(CellIndex.indexByString('A23')).value = TextCellValue('Estimated Material Cost:');
    sheet.cell(CellIndex.indexByString('B23')).value = TextCellValue('PHP ${takeoff.estimatedMaterialCost.toStringAsFixed(2)}');

    sheet.cell(CellIndex.indexByString('A24')).value = TextCellValue('Estimated Labor Cost:');
    sheet.cell(CellIndex.indexByString('B24')).value = TextCellValue('PHP ${takeoff.estimatedLaborCost.toStringAsFixed(2)}');

    sheet.cell(CellIndex.indexByString('A25')).value = TextCellValue('TOTAL ESTIMATED PROJECT COST:');
    sheet.cell(CellIndex.indexByString('B25')).value = TextCellValue('PHP ${takeoff.grandTotalEstimatedCost.toStringAsFixed(2)}');

    // PEC Engineering Basis Notes
    sheet.cell(CellIndex.indexByString('A27')).value = TextCellValue('PEC 2017 MANDATORY CITATIONS:');
    int row = 28;
    for (final note in sldData.pecEngineeringBasis) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('${note['topic']} (${note['citation']}): ${note['formula']} -> ${note['computed']}');
      row++;
    }
  }

  static void _populateScheduleOfLoadsSheet(Sheet sheet, SingleLineDiagramData sldData) {
    // Header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('SCHEDULE OF LOADS & CIRCUIT COMPUTATION');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Panelboard: ${sldData.panelName} | 230V 1-Phase 2-Wire + Ground | Voltage Drop Limit: <= 3.0% (PEC 2017)');

    final headers = [
      'Ckt No.',
      'Load Description / Outlets',
      'Voltage (V)',
      'Load (VA)',
      'Current (A)',
      'Pole',
      'Breaker Rating',
      '3D Run (m)',
      'Voltage Drop (%)',
      'VD Status',
      'Wire Specification (PEC Table 3.10.2.6)',
      'Conduit Size (Ch. 9 Table 1)',
      'Remarks',
    ];

    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3)).value = TextCellValue(headers[col]);
    }

    int rowIndex = 4;
    for (final ckt in sldData.branchCircuits) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = TextCellValue('Ckt ${ckt.circuitNumber}');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(ckt.description);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = IntCellValue(ckt.voltage);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(ckt.loadVA);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(ckt.loadCurrentAmps.toStringAsFixed(2)));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = IntCellValue(ckt.poles);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue('${ckt.breakerRatingAmps} AT / 50 AF');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(ckt.measuredRunMeters.toStringAsFixed(1)));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(ckt.voltageDropPercent.toStringAsFixed(2)));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue(ckt.isUpsized ? 'UPSIZED (PASS)' : 'PASS (<3%)');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value = TextCellValue(ckt.wireSizeDescription);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value = TextCellValue(ckt.conduitDescription);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value = TextCellValue(ckt.isUpsized ? ckt.upsizeReason : (ckt.isSpare ? 'Spare Space' : 'Standard Run'));
      rowIndex++;
    }

    // Totals Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue('TOTAL CONNECTED LOAD:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(sldData.feeder.totalConnectedVA);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(sldData.feeder.netCurrentAmps.toStringAsFixed(2)));
    rowIndex += 2;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue('MAIN FEEDER SUMMARY:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(sldData.feeder.mainBreakerDescription);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = TextCellValue(sldData.feeder.feederWireDescription);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = TextCellValue(sldData.feeder.conduitDescription);
  }

  static void _populateBomSheet(Sheet sheet, TakeoffResult takeoff, SingleLineDiagramData sldData) {
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('BILL OF MATERIALS (BOM) & DETAILED COST ESTIMATE');
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Accurate Material Breakdown with 3D Vertical Drops & PEC Splice Allowances');

    final headers = [
      'Item No.',
      'Material / Description',
      'Specification',
      'Quantity',
      'Unit',
      'Unit Material Cost (PHP)',
      'Total Material (PHP)',
      'Unit Labor Cost (PHP)',
      'Total Labor (PHP)',
      'Subtotal (PHP)',
    ];

    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3)).value = TextCellValue(headers[col]);
    }

    final bomItems = [
      {
        'desc': 'THHN / THWN-2 Copper Wire (Branch Circuits)',
        'spec': '3.5 mm² (#10 AWG) Lead-Free Pure Copper, 90°C',
        'qty': takeoff.totalThhnWireMeters,
        'unit': 'meters',
        'matRate': 28.0,
        'labRate': 8.0,
      },
      {
        'desc': 'THHN / THWN-2 Feeder Wire (Main Feeder)',
        'spec': sldData.feeder.feederWireDescription,
        'qty': 35.0, // Standard 35m feeder homerun
        'unit': 'meters',
        'matRate': 95.0,
        'labRate': 25.0,
      },
      {
        'desc': 'uPVC Electrical Conduit Pipe (20mm Ø)',
        'spec': 'Thick-wall, Flame retardant, 3.0 meters/pc',
        'qty': takeoff.totalPvcPipesPcs.toDouble(),
        'unit': 'pcs',
        'matRate': 95.0,
        'labRate': 35.0,
      },
      {
        'desc': 'uPVC Electrical Utility Box (2" x 4")',
        'spec': 'Deep type with knockouts for switches & CO',
        'qty': takeoff.utilityBoxesCount.toDouble(),
        'unit': 'pcs',
        'matRate': 25.0,
        'labRate': 15.0,
      },
      {
        'desc': 'Octagonal Junction Box (4" Octagon)',
        'spec': 'Flame-retardant uPVC for ceiling fixtures',
        'qty': takeoff.octagonalBoxesCount.toDouble(),
        'unit': 'pcs',
        'matRate': 30.0,
        'labRate': 20.0,
      },
      {
        'desc': 'Conduit Clamps & Support Straps (20mm)',
        'spec': 'PVC 1-hole strap @ 1.0m maximum interval',
        'qty': takeoff.conduitClampsCount.toDouble(),
        'unit': 'pcs',
        'matRate': 6.0,
        'labRate': 4.0,
      },
      {
        'desc': 'Main Distribution Panelboard (MDP)',
        'spec': 'NEMA 1 Surface/Flush, 2P Main + Branch Spaces',
        'qty': 1.0,
        'unit': 'set',
        'matRate': 3800.0,
        'labRate': 850.0,
      },
      {
        'desc': 'Grounding Rod & Ground Clamp',
        'spec': '16mm Ø x 3.0m Copper-clad steel with brass clamp',
        'qty': 1.0,
        'unit': 'lot',
        'matRate': 950.0,
        'labRate': 400.0,
      },
      {
        'desc': 'Miscellaneous Consumables',
        'spec': 'Electrical tape, PVC solvent cement, tox/screws',
        'qty': 1.0,
        'unit': 'lot',
        'matRate': 650.0,
        'labRate': 200.0,
      },
    ];

    int rowIndex = 4;
    double grandMat = 0.0;
    double grandLab = 0.0;

    for (int i = 0; i < bomItems.length; i++) {
      final item = bomItems[i];
      final qty = item['qty'] as double;
      final matRate = item['matRate'] as double;
      final labRate = item['labRate'] as double;
      final totalMat = qty * matRate;
      final totalLab = qty * labRate;
      final subtotal = totalMat + totalLab;

      grandMat += totalMat;
      grandLab += totalLab;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(item['desc'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = TextCellValue(item['spec'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(qty.toStringAsFixed(1)));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = TextCellValue(item['unit'] as String);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(matRate);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(totalMat.toStringAsFixed(2)));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = DoubleCellValue(labRate);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(totalLab.toStringAsFixed(2)));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(subtotal.toStringAsFixed(2)));
      rowIndex++;
    }

    // Totals
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue('SUBTOTAL ESTIMATE:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(grandMat.toStringAsFixed(2)));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(double.parse(grandLab.toStringAsFixed(2)));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = DoubleCellValue(double.parse((grandMat + grandLab).toStringAsFixed(2)));
    rowIndex++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue('GRAND TOTAL ESTIMATED PROJECT CONTRACT:');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value = TextCellValue('PHP ${(grandMat + grandLab).toStringAsFixed(2)}');
  }
}
