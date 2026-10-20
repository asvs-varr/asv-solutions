import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/models.dart';
import 'package:banaag/data/project_repository.dart';
import 'package:banaag/presentation/screens/single_line_diagram_screen.dart';

void main() {
  testWidgets('SingleLineDiagramScreen renders correctly in 360x800', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    final project = Project(
      id: 'test_proj',
      title: 'Laniton First Electrical',
      clientName: 'Juan Dela Cruz',
      clientContact: '09123456789',
      siteAddress: 'Manila',
      contractAmount: 150000.0,
      createdAt: DateTime.now(),
      phases: ProjectRepository.instance.createDefaultPhases(),
      applianceLoads: [
        ApplianceItem(
          id: 'app_1',
          name: 'LED Lighting Fixtures',
          roomCategory: 'General',
          ratingVA: 500,
          quantity: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SingleLineDiagramScreen(project: project),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('⚡ Single-Line Diagram Engine'), findsOneWidget);
    expect(find.text('Single-Line Schematic'), findsOneWidget);
    expect(find.text('Schedule of Loads'), findsOneWidget);
    expect(find.textContaining('Main MCB:'), findsOneWidget);
  });
}
