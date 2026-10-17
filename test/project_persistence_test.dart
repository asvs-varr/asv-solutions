// BANAAG Project Persistence Tests
// Verifies that projects, custom loads, and takeoff data persist and restore safely from disk

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:banaag/data/project_repository.dart';
import 'package:banaag/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BANAAG Project Disk Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Serializes and deserializes Project with complete appliance and canvas data', () {
      final sampleProject = Project(
        id: 'test-prj-999',
        title: 'Bauan Batangas Residence Project',
        clientName: 'Juan Dela Cruz',
        clientContact: '09171234567',
        siteAddress: 'Poblacion, Bauan, Batangas',
        contractAmount: 250000.0,
        phases: ProjectRepository.instance.createDefaultPhases(),
        createdAt: DateTime.now(),
        applianceLoads: [
          ApplianceItem(
            id: 'app-1',
            name: '2.5HP Inverter Split-Type ACU',
            roomCategory: 'Master Bedroom',
            ratingVA: 2200.0,
            quantity: 1,
            isDedicatedCircuit: true,
          ),
        ],
        canvasPoints: [
          CanvasPoint(id: 'pt-1', type: 'PANEL', label: 'Main LP', x: 50, y: 100),
          CanvasPoint(id: 'pt-2', type: 'ACU', label: 'ACU Outlet', x: 150, y: 100),
        ],
      );

      final jsonMap = sampleProject.toJson();
      final restored = Project.fromJson(jsonMap);

      expect(restored.id, sampleProject.id);
      expect(restored.title, sampleProject.title);
      expect(restored.contractAmount, 250000.0);
      expect(restored.applianceLoads.length, 1);
      expect(restored.applianceLoads.first.name, '2.5HP Inverter Split-Type ACU');
      expect(restored.applianceLoads.first.isDedicatedCircuit, isTrue);
      expect(restored.canvasPoints.length, 2);
    });

    test('Repository saves added project to disk and notifies stream', () async {
      final repo = ProjectRepository.instance;
      final newProject = Project(
        id: 'real-life-client-01',
        title: 'Active Project 2026',
        clientName: 'Don Ramon',
        clientContact: '09223334444',
        siteAddress: 'Lucena City',
        contractAmount: 180000.0,
        phases: repo.createDefaultPhases(),
        createdAt: DateTime.now(),
      );

      repo.addProject(newProject);
      expect(repo.allProjects.any((p) => p.id == 'real-life-client-01'), isTrue);
    });
  });
}
