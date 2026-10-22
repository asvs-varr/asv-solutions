import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:banaag/domain/models.dart';
import 'package:banaag/data/project_repository.dart';
import 'package:banaag/presentation/screens/client_needs_analysis_screen.dart';

void main() {
  testWidgets('ClientNeedsAnalysisScreen - tap Apply PEC Standard Pack in Bathroom at 360x800', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // Logical 360x800
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final project = Project(
      id: 'test_proj',
      title: 'Test House',
      clientName: 'Juan Dela Cruz',
      clientContact: '09123456789',
      siteAddress: 'Manila',
      contractAmount: 150000.0,
      createdAt: DateTime.now(),
      phases: ProjectRepository.instance.createDefaultPhases(),
      spaces: [
        RoomSpace(id: 's1', name: 'Bathroom', areaSqm: 5.0, ceilingHeight: 2.7),
      ],
      applianceLoads: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientNeedsAnalysisScreen(project: project),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the center empty state button 'Apply PEC Standard Pack'
    final applyBtn = find.widgetWithText(ElevatedButton, 'Apply PEC Standard Pack');
    expect(applyBtn, findsOneWidget);
    await tester.tap(applyBtn);
    await tester.pumpAndSettle();

    // Check if the modal opened and rendered without ANY paint or layout exceptions
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('PEC Standard Pack: Bathroom'), findsOneWidget);
    expect(find.text('STANDARD'), findsOneWidget);
    expect(find.text('PREMIUM ✨'), findsOneWidget);
    expect(find.text('LUXURY 💎'), findsOneWidget);
    expect(find.text('GFCI Protected Shaver & Mirror Vanity Outlet'), findsOneWidget);

    // Tap close button to dismiss modal
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
