// BANAAG Future-Proofing Engineering Engine
// Specialized module for Solar PV Net-Metering, EV Charger Sizing, Smart Home Automation, and Multi-Tenant Sub-Metering.

import 'pec_engine.dart';

class SolarPvSpec {
  final double systemKw;
  final double inverterAcOutputAmps;
  final PecWireSpec recommendedWire;
  final int recommendedBreaker;
  final String rapidShutdownRequirement;
  final String utilityComplianceNote;

  const SolarPvSpec({
    required this.systemKw,
    required this.inverterAcOutputAmps,
    required this.recommendedWire,
    required this.recommendedBreaker,
    required this.rapidShutdownRequirement,
    required this.utilityComplianceNote,
  });
}

class EvChargerSpec {
  final String levelName;
  final double powerKw;
  final double continuousCurrentAmps;
  final PecWireSpec recommendedWire;
  final int recommendedBreaker;
  final String conduitRecommendation;

  const EvChargerSpec({
    required this.levelName,
    required this.powerKw,
    required this.continuousCurrentAmps,
    required this.recommendedWire,
    required this.recommendedBreaker,
    required this.conduitRecommendation,
  });
}

class FutureProofingEngine {
  /// Solar PV Net-Metering Calculator (PEC Article 6.90 & ERC Net-Metering Rules)
  static SolarPvSpec calculateSolarReadiness(double systemKw, {double nominalVoltage = 230.0}) {
    // Inverter AC output current = (P_kW * 1000) / V
    final double ratedCurrent = (systemKw * 1000.0) / nominalVoltage;
    // PEC 6.90 continuous output requirement = 125% factor
    final double continuousCurrent = ratedCurrent * 1.25;

    final wire = PecEngine.sizeWireForCurrent(continuousCurrent, isContinuous: true);
    final breaker = PecEngine.selectBreaker(continuousCurrent, wire.ampacity75C);

    return SolarPvSpec(
      systemKw: systemKw,
      inverterAcOutputAmps: ratedCurrent,
      recommendedWire: wire,
      recommendedBreaker: breaker,
      rapidShutdownRequirement: 'PEC 6.90.1.12: Rapid shutdown switch required within 1.2m of main service disconnect.',
      utilityComplianceNote: 'ERC / Meralco Net-Metering requires Bi-directional meter and Certificate of Final Electrical Inspection (CFEI).',
    );
  }

  /// EV (Electric Vehicle) Charging Station Sizer (PEC Article 6.25)
  /// Level 2 AC chargers in the Philippines are continuous duty (125% rated)
  static EvChargerSpec calculateEvCharger(double powerKw, {double nominalVoltage = 230.0}) {
    final double ratedCurrent = (powerKw * 1000.0) / nominalVoltage;
    final double continuousCurrent = ratedCurrent * 1.25;

    final wire = PecEngine.sizeWireForCurrent(continuousCurrent, isContinuous: true);
    final breaker = PecEngine.selectBreaker(continuousCurrent, wire.ampacity75C);
    final conduit = PecEngine.recommendConduit(wireSpec: wire, conductorCount: 3);

    return EvChargerSpec(
      levelName: 'Level 2 AC (${powerKw.toStringAsFixed(1)} kW Single-Phase 230V)',
      powerKw: powerKw,
      continuousCurrentAmps: continuousCurrent,
      recommendedWire: wire,
      recommendedBreaker: breaker,
      conduitRecommendation: '${conduit.tradeSize} Rigid PVC / EMT Raceway with dedicated ground rod bonding.',
    );
  }

  /// Smart Home Conduit Provisions Audit Checklist
  static List<Map<String, String>> getSmartHomeAudit() {
    return [
      {
        'title': 'Mandatory Neutral in Switch Boxes',
        'desc': 'Pull dedicated Neutral wire (#14 AWG White) to ALL switch boxes for WiFi/Zigbee smart switches.',
        'standard': 'PEC Article 4.0.4.2(C)',
      },
      {
        'title': 'WiFi 6/7 Access Point Ceiling Drops',
        'desc': 'Run 25mm PVC conduit with Cat6 UTP cable directly to ceiling center points for full coverage mesh.',
        'standard': 'TIA-568-D / Smart Home Best Practice',
      },
      {
        'title': 'Smart Metering & IoT CT Sensor Space',
        'desc': 'Ensure 200mm vertical clearance inside panel board around main service busbars for IoT energy monitor split-core CT sensors.',
        'standard': 'Smart Panel Integration standard',
      },
    ];
  }
}
