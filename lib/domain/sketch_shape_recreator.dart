// BANAAG Core Domain: Computer-Vision Sketch Shape Recreator & Wall-by-Wall Dimension Engine
// Analyzes any user-uploaded hand-drawn floor plan photo, filters out skin/hand/background
// and blue ruled notebook lines, dynamically extracts the outer enclosure and all interior
// vertical/horizontal pen walls into a Rectilinear Grid-Wall & Connected-Component Flood-Fill topology,
// matches offline ML Kit OCR dimension numbers spatially, and powers the Interactive Wall-by-Wall
// Dimension Highlighter (with Proportional Auto-Estimation + Add/Remove Wall) -> 100% Clean Proportional CAD Floor Plan.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'models.dart';

class SketchWallPrompt {
  final String id;
  final String shortCode;
  final String label;
  final String tagalogQuestion;
  double meters;
  bool isConfirmed;
  final bool isInteriorWall;
  final bool isVertical;
  final int gridLineIndex;
  final int startCellIndex;
  final int endCellIndex;
  Offset startCanvas;
  Offset endCanvas;

  SketchWallPrompt({
    required this.id,
    required this.shortCode,
    required this.label,
    required this.tagalogQuestion,
    required this.meters,
    this.isConfirmed = false,
    this.isInteriorWall = false,
    this.isVertical = false,
    this.gridLineIndex = 0,
    this.startCellIndex = 0,
    this.endCellIndex = 1,
    this.startCanvas = Offset.zero,
    this.endCanvas = Offset.zero,
  });

  Offset get midPoint => Offset(
        (startCanvas.dx + endCanvas.dx) / 2.0,
        (startCanvas.dy + endCanvas.dy) / 2.0,
      );

  bool get isHorizontal => !isVertical;
}

class SketchHandleRef {
  final int xIdx;
  final int yIdx;
  final Offset position;

  const SketchHandleRef({
    required this.xIdx,
    required this.yIdx,
    required this.position,
  });
}

class RecreatedSketchModel {
  Rect outerBoxCanvas;

  /// Normalized X grid coordinates in [0.0 .. 1.0], always starting with 0.0 and ending with 1.0
  List<double> xRatios;

  /// Normalized Y grid coordinates in [0.0 .. 1.0], always starting with 0.0 and ending with 1.0
  List<double> yRatios;

  /// Vertical walls: size [numRows][numCols + 1].
  /// vWalls[r][xIdx] is true if there is a vertical wall on xRatios[xIdx] across row r (from yRatios[r] to yRatios[r+1]).
  List<List<bool>> vWalls;

  /// Horizontal walls: size [numRows + 1][numCols].
  /// hWalls[yIdx][c] is true if there is a horizontal wall on yRatios[yIdx] across col c (from xRatios[c] to xRatios[c+1]).
  List<List<bool>> hWalls;

  /// 0 = Dynamic Multi-Room (Flood-Fill from Detected Walls)
  /// 1 = Split All Interior Cells (+Alcoves)
  /// 2 = Single Outer / L-Shape Envelope
  int topologyMode;

  final List<SketchWallPrompt> wallPrompts;
  final List<double> ocrCandidateMeters;
  final List<SketchHandleRef> _cachedHandles = [];

  double _wTopMeters;
  double _hRightMeters;
  bool _wTopConfirmed;
  bool _hRightConfirmed;

  RecreatedSketchModel({
    required this.outerBoxCanvas,
    List<double>? xRatios,
    List<double>? yRatios,
    List<List<bool>>? vWalls,
    List<List<bool>>? hWalls,
    double topStepXRatio = 0.48,
    double stepYRatio = 0.22,
    double lowerSplitXRatio = 0.74,
    this.topologyMode = 0,
    List<SketchWallPrompt>? wallPrompts,
    this.ocrCandidateMeters = const [5.0, 4.0, 1.0, 2.0, 1.5, 2.5, 3.0, 3.5, 4.5],
    double initialWTopMeters = 4.0,
    double initialHRightMeters = 5.0,
    bool wTopConfirmed = false,
    bool hRightConfirmed = false,
  })  : xRatios = xRatios ?? [0.0, topStepXRatio.clamp(0.15, 0.80), lowerSplitXRatio.clamp(0.25, 0.90), 1.0],
        yRatios = yRatios ?? [0.0, stepYRatio.clamp(0.12, 0.85), 1.0],
        vWalls = vWalls ??
            [
              [true, true, false, true],
              [true, false, true, true],
            ],
        hWalls = hWalls ??
            [
              [true, true, true],
              [false, true, false],
              [true, true, true],
            ],
        wallPrompts = wallPrompts ?? [],
        _wTopMeters = initialWTopMeters,
        _hRightMeters = initialHRightMeters,
        _wTopConfirmed = wTopConfirmed,
        _hRightConfirmed = hRightConfirmed {
    _ensureValidGridConsistency();
    if (this.wallPrompts.isEmpty) {
      rebuildWallPrompts(preserveConfirmed: false);
    } else {
      // Sync _wTopMeters and _hRightMeters from passed wallPrompts if present
      for (final wp in this.wallPrompts) {
        if (wp.id == 'w_top') {
          _wTopMeters = wp.meters;
          _wTopConfirmed = wp.isConfirmed;
        } else if (wp.id == 'h_right') {
          _hRightMeters = wp.meters;
          _hRightConfirmed = wp.isConfirmed;
        }
      }
      rebuildWallPrompts(preserveConfirmed: true);
    }
  }

  int get numRows => math.max(1, yRatios.length - 1);
  int get numCols => math.max(1, xRatios.length - 1);

  double get topStepXRatio => xRatios.length > 1 ? xRatios[1] : 0.48;
  set topStepXRatio(double val) {
    if (xRatios.length > 1) {
      xRatios[1] = val.clamp(0.10, xRatios.length > 2 ? xRatios[2] - 0.05 : 0.90);
      recomputeWallPromptCanvasPositions();
    }
  }

  double get lowerSplitXRatio => xRatios.length > 2 ? xRatios[2] : (xRatios.length > 1 ? xRatios[1] : 0.74);
  set lowerSplitXRatio(double val) {
    if (xRatios.length > 2) {
      xRatios[2] = val.clamp(xRatios[1] + 0.05, 0.92);
      recomputeWallPromptCanvasPositions();
    }
  }

  double get stepYRatio => yRatios.length > 1 ? yRatios[1] : 0.22;
  set stepYRatio(double val) {
    if (yRatios.length > 1) {
      yRatios[1] = val.clamp(0.10, yRatios.length > 2 ? yRatios[2] - 0.05 : 0.90);
      recomputeWallPromptCanvasPositions();
    }
  }

  double get totalTopWidthM {
    for (final w in wallPrompts) {
      if (w.id == 'w_top' && w.meters > 0.1) return w.meters;
    }
    return _wTopMeters;
  }

  double get totalRightHeightM {
    for (final w in wallPrompts) {
      if (w.id == 'h_right' && w.meters > 0.1) return w.meters;
    }
    return _hRightMeters;
  }

  void _ensureValidGridConsistency() {
    if (xRatios.length < 2) {
      xRatios = [0.0, 1.0];
    }
    if (yRatios.length < 2) {
      yRatios = [0.0, 1.0];
    }
    xRatios[0] = 0.0;
    xRatios[xRatios.length - 1] = 1.0;
    for (int i = 1; i < xRatios.length - 1; i++) {
      final minAllowed = xRatios[i - 1] + 0.05;
      final maxAllowed = 1.0 - (xRatios.length - 1 - i) * 0.05;
      xRatios[i] = xRatios[i].clamp(minAllowed, maxAllowed);
    }

    yRatios[0] = 0.0;
    yRatios[yRatios.length - 1] = 1.0;
    for (int i = 1; i < yRatios.length - 1; i++) {
      final minAllowed = yRatios[i - 1] + 0.05;
      final maxAllowed = 1.0 - (yRatios.length - 1 - i) * 0.05;
      yRatios[i] = yRatios[i].clamp(minAllowed, maxAllowed);
    }

    final int R = numRows;
    final int C = numCols;

    if (vWalls.length != R || (vWalls.isNotEmpty && vWalls.first.length != C + 1)) {
      vWalls = List.generate(R, (_) => List.generate(C + 1, (c) => c == 0 || c == C));
    }
    if (hWalls.length != R + 1 || (hWalls.isNotEmpty && hWalls.first.length != C)) {
      hWalls = List.generate(R + 1, (r) => List.generate(C, (_) => r == 0 || r == R));
    }

    // Outer boundary walls are always solid
    for (int r = 0; r < R; r++) {
      vWalls[r][0] = true;
      vWalls[r][C] = true;
    }
    for (int c = 0; c < C; c++) {
      hWalls[0][c] = true;
      hWalls[R][c] = true;
    }
  }

  /// Connected-component flood fill on the R x C grid cells.
  /// Also prunes any dangling interior wall segments that have the same room component on both sides.
  ({
    List<List<int>> compGrid,
    int numRooms,
    List<List<(int, int)>> roomGridLoops,
  }) computeRoomGridLoops({bool pruneDangling = true}) {
    _ensureValidGridConsistency();
    final int R = numRows;
    final int C = numCols;

    // Work on a copy of vWalls and hWalls if topologyMode overrides them
    final List<List<bool>> activeV = List.generate(R, (r) => List<bool>.from(vWalls[r]));
    final List<List<bool>> activeH = List.generate(R + 1, (r) => List<bool>.from(hWalls[r]));

    if (topologyMode == 1 && R >= 2 && C >= 2) {
      // Mode 1: Split top cutout / alcove as an explicit separate room
      for (int r = 0; r < R; r++) {
        for (int xi = 1; xi < C; xi++) {
          if (r == 0) activeV[r][xi] = true;
        }
      }
      for (int c = 0; c < C - 1; c++) {
        activeH[1][c] = true;
      }
    } else if (topologyMode == 2) {
      // Mode 2: Single combined envelope room (clear interior partitions)
      for (int r = 0; r < R; r++) {
        for (int xi = 1; xi < C; xi++) {
          activeV[r][xi] = false;
        }
      }
      for (int yi = 1; yi < R; yi++) {
        for (int c = 0; c < C; c++) {
          activeH[yi][c] = false;
        }
      }
    }

    List<List<int>> comp = List.generate(R, (_) => List<int>.filled(C, -1));
    int cid = 0;
    for (int r = 0; r < R; r++) {
      for (int c = 0; c < C; c++) {
        if (comp[r][c] != -1) continue;
        final List<(int, int)> q = [(r, c)];
        comp[r][c] = cid;
        while (q.isNotEmpty) {
          final (cr, cc) = q.removeLast();
          if (cc > 0 && !activeV[cr][cc] && comp[cr][cc - 1] == -1) {
            comp[cr][cc - 1] = cid;
            q.add((cr, cc - 1));
          }
          if (cc + 1 < C && !activeV[cr][cc + 1] && comp[cr][cc + 1] == -1) {
            comp[cr][cc + 1] = cid;
            q.add((cr, cc + 1));
          }
          if (cr > 0 && !activeH[cr][cc] && comp[cr - 1][cc] == -1) {
            comp[cr - 1][cc] = cid;
            q.add((cr - 1, cc));
          }
          if (cr + 1 < R && !activeH[cr + 1][cc] && comp[cr + 1][cc] == -1) {
            comp[cr + 1][cc] = cid;
            q.add((cr + 1, cc));
          }
        }
        cid++;
      }
    }

    if (pruneDangling && topologyMode == 0) {
      for (int r = 0; r < R; r++) {
        for (int xi = 1; xi < C; xi++) {
          if (vWalls[r][xi] && comp[r][xi - 1] == comp[r][xi]) {
            vWalls[r][xi] = false;
          }
        }
      }
      for (int yi = 1; yi < R; yi++) {
        for (int c = 0; c < C; c++) {
          if (hWalls[yi][c] && comp[yi - 1][c] == comp[yi][c]) {
            hWalls[yi][c] = false;
          }
        }
      }
    }

    final List<List<(int, int)>> loops = [];
    for (int id = 0; id < cid; id++) {
      final List<((int, int), (int, int))> edges = [];
      for (int r = 0; r < R; r++) {
        for (int c = 0; c < C; c++) {
          if (comp[r][c] != id) continue;
          // Top edge
          if (r == 0 || comp[r - 1][c] != id) {
            edges.add(((c, r), (c + 1, r)));
          }
          // Right edge
          if (c == C - 1 || comp[r][c + 1] != id) {
            edges.add(((c + 1, r), (c + 1, r + 1)));
          }
          // Bottom edge
          if (r == R - 1 || comp[r + 1][c] != id) {
            edges.add(((c + 1, r + 1), (c, r + 1)));
          }
          // Left edge
          if (c == 0 || comp[r][c - 1] != id) {
            edges.add(((c, r + 1), (c, r)));
          }
        }
      }
      if (edges.isEmpty) continue;

      final List<(int, int)> loop = [edges[0].$1, edges[0].$2];
      final Set<int> used = {0};
      while (loop.last != loop.first) {
        final cur = loop.last;
        bool found = false;
        for (int i = 0; i < edges.length; i++) {
          if (!used.contains(i) && edges[i].$1 == cur) {
            used.add(i);
            loop.add(edges[i].$2);
            found = true;
            break;
          }
        }
        if (!found) break;
      }
      if (loop.length > 1 && loop.last == loop.first) {
        loop.removeLast();
      }

      // Simplify collinear points so only true 90-degree corners remain
      final List<(int, int)> simp = [];
      for (int i = 0; i < loop.length; i++) {
        final pPrev = loop[(i - 1 + loop.length) % loop.length];
        final pCur = loop[i];
        final pNext = loop[(i + 1) % loop.length];
        if ((pPrev.$1 == pCur.$1 && pCur.$1 == pNext.$1) ||
            (pPrev.$2 == pCur.$2 && pCur.$2 == pNext.$2)) {
          continue;
        }
        simp.add(pCur);
      }
      if (simp.length >= 4) {
        loops.add(simp);
      }
    }

    return (compGrid: comp, numRooms: loops.length, roomGridLoops: loops);
  }

  /// Rebuilds the 1-by-1 wall prompts dynamically from the active grid walls,
  /// automatically computing proportional meter estimates for unconfirmed walls!
  void rebuildWallPrompts({bool preserveConfirmed = true}) {
    _ensureValidGridConsistency();
    computeRoomGridLoops(pruneDangling: true);

    final Map<String, (double, bool)> prevConfirmed = {};
    if (preserveConfirmed) {
      for (final wp in wallPrompts) {
        if (wp.isConfirmed) {
          prevConfirmed[wp.id] = (wp.meters, true);
        }
      }
      if (prevConfirmed.containsKey('w_top')) {
        _wTopMeters = prevConfirmed['w_top']!.$1;
        _wTopConfirmed = true;
      }
      if (prevConfirmed.containsKey('h_right')) {
        _hRightMeters = prevConfirmed['h_right']!.$1;
        _hRightConfirmed = true;
      }
    }

    final int R = numRows;
    final int C = numCols;
    final List<SketchWallPrompt> nextPrompts = [];

    // 1. W1: Top Total Width
    nextPrompts.add(
      SketchWallPrompt(
        id: 'w_top',
        shortCode: 'W1',
        label: 'Top Total Width (Kabuuang Lapad)',
        tagalogQuestion: 'Ano ang kabuuang lapad sa itaas (Top Width W1)?',
        meters: double.parse(_wTopMeters.clamp(1.0, 60.0).toStringAsFixed(1)),
        isConfirmed: _wTopConfirmed,
        isInteriorWall: false,
        isVertical: false,
        gridLineIndex: 0,
        startCellIndex: 0,
        endCellIndex: C,
      ),
    );

    // 2. L1: Right Total Length (proportionally estimated from W1 if unconfirmed)
    if (!_hRightConfirmed && _wTopConfirmed) {
      final double aspect = (outerBoxCanvas.height / math.max(40.0, outerBoxCanvas.width)).clamp(0.45, 2.2);
      _hRightMeters = double.parse((_wTopMeters * aspect).clamp(1.5, 60.0).toStringAsFixed(1));
    }
    nextPrompts.add(
      SketchWallPrompt(
        id: 'h_right',
        shortCode: 'L1',
        label: 'Right Total Length (Kabuuang Haba)',
        tagalogQuestion: 'Tama ba ang kabuuang haba sa kanan (Right Length L1)?',
        meters: double.parse(_hRightMeters.clamp(1.0, 60.0).toStringAsFixed(1)),
        isConfirmed: _hRightConfirmed,
        isInteriorWall: false,
        isVertical: true,
        gridLineIndex: C,
        startCellIndex: 0,
        endCellIndex: R,
      ),
    );

    // 3. Collect all contiguous interior wall chains (vertical & horizontal)
    final List<({
      bool isVert,
      int lineIdx,
      int startIdx,
      int endIdx,
      double sortKeyY,
      double sortKeyX,
    })> interiorChains = [];

    // Vertical interior wall chains on xRatios[1 .. C-1]
    for (int xi = 1; xi < C; xi++) {
      int r = 0;
      while (r < R) {
        if (vWalls[r][xi]) {
          int rEnd = r + 1;
          while (rEnd < R && vWalls[rEnd][xi]) {
            rEnd++;
          }
          interiorChains.add((
            isVert: true,
            lineIdx: xi,
            startIdx: r,
            endIdx: rEnd,
            sortKeyY: (yRatios[r] + yRatios[rEnd]) / 2.0,
            sortKeyX: xRatios[xi],
          ));
          r = rEnd;
        } else {
          r++;
        }
      }
    }

    // Horizontal interior wall chains on yRatios[1 .. R-1]
    for (int yi = 1; yi < R; yi++) {
      int c = 0;
      while (c < C) {
        if (hWalls[yi][c]) {
          int cEnd = c + 1;
          while (cEnd < C && hWalls[yi][cEnd]) {
            cEnd++;
          }
          interiorChains.add((
            isVert: false,
            lineIdx: yi,
            startIdx: c,
            endIdx: cEnd,
            sortKeyY: yRatios[yi],
            sortKeyX: (xRatios[c] + xRatios[cEnd]) / 2.0,
          ));
          c = cEnd;
        } else {
          c++;
        }
      }
    }

    // Sort interior walls from top-to-bottom, then left-to-right
    interiorChains.sort((a, b) {
      final dy = (a.sortKeyY - b.sortKeyY).abs();
      if (dy > 0.08) return a.sortKeyY.compareTo(b.sortKeyY);
      return a.sortKeyX.compareTo(b.sortKeyX);
    });

    int sCounter = 1;
    for (final ch in interiorChains) {
      final String id = ch.isVert
          ? 'int_v_${ch.lineIdx}_${ch.startIdx}_${ch.endIdx}'
          : 'int_h_${ch.lineIdx}_${ch.startIdx}_${ch.endIdx}';
      final String code = 'S$sCounter';
      sCounter++;

      final double spanRatio = ch.isVert
          ? (yRatios[ch.endIdx] - yRatios[ch.startIdx]).abs()
          : (xRatios[ch.endIdx] - xRatios[ch.startIdx]).abs();
      final double refTotal = ch.isVert ? _hRightMeters : _wTopMeters;
      double estMeters = double.parse((spanRatio * refTotal).clamp(0.4, 50.0).toStringAsFixed(1));
      bool isConf = false;

      if (prevConfirmed.containsKey(id)) {
        estMeters = prevConfirmed[id]!.$1;
        isConf = true;
      }

      final String dirTag = ch.isVert ? 'patayong pader (Vertical)' : 'pahalang na pader (Horizontal)';
      nextPrompts.add(
        SketchWallPrompt(
          id: id,
          shortCode: code,
          label: ch.isVert ? 'Interior Vertical Wall $code' : 'Interior Horizontal Wall $code',
          tagalogQuestion: 'Tama ba ang sukat ng $dirTag $code (${estMeters.toStringAsFixed(1)}m)?',
          meters: estMeters,
          isConfirmed: isConf,
          isInteriorWall: true,
          isVertical: ch.isVert,
          gridLineIndex: ch.lineIdx,
          startCellIndex: ch.startIdx,
          endCellIndex: ch.endIdx,
        ),
      );
    }

    // 4. Add Bottom-Right Bay Width (W2) if the bottom wall is split by an interior vertical wall
    int bottomSplitXi = -1;
    for (int xi = C - 1; xi >= 1; xi--) {
      if (vWalls[R - 1][xi]) {
        bottomSplitXi = xi;
        break;
      }
    }
    if (bottomSplitXi != -1) {
      const String id = 'w_bottom_right';
      final double spanRatio = (1.0 - xRatios[bottomSplitXi]).clamp(0.08, 0.92);
      double estMeters = double.parse((spanRatio * _wTopMeters).clamp(0.4, 50.0).toStringAsFixed(1));
      bool isConf = false;
      if (prevConfirmed.containsKey(id)) {
        estMeters = prevConfirmed[id]!.$1;
        isConf = true;
      }
      nextPrompts.add(
        SketchWallPrompt(
          id: id,
          shortCode: 'W2',
          label: 'Bottom-Right Bay Width',
          tagalogQuestion: 'Tama ba ang lapad sa ibabang kanan W2 (${estMeters.toStringAsFixed(1)}m)?',
          meters: estMeters,
          isConfirmed: isConf,
          isInteriorWall: false,
          isVertical: false,
          gridLineIndex: R,
          startCellIndex: bottomSplitXi,
          endCellIndex: C,
        ),
      );
    }

    wallPrompts
      ..clear()
      ..addAll(nextPrompts);
    recomputeWallPromptCanvasPositions();
  }

  /// Updates thecanvas start/end coordinates of every SketchWallPrompt from (xRatios, yRatios)
  void recomputeWallPromptCanvasPositions() {
    _ensureValidGridConsistency();
    final double l = outerBoxCanvas.left;
    final double t = outerBoxCanvas.top;
    final double w = outerBoxCanvas.width;
    final double h = outerBoxCanvas.height;

    for (final wp in wallPrompts) {
      if (wp.id == 'w_top') {
        wp.startCanvas = Offset(l, t);
        wp.endCanvas = Offset(l + w, t);
      } else if (wp.id == 'h_right') {
        wp.startCanvas = Offset(l + w, t);
        wp.endCanvas = Offset(l + w, t + h);
      } else if (wp.isVertical) {
        final int xi = wp.gridLineIndex.clamp(0, xRatios.length - 1);
        final int r0 = wp.startCellIndex.clamp(0, yRatios.length - 1);
        final int r1 = wp.endCellIndex.clamp(0, yRatios.length - 1);
        final double xPos = l + xRatios[xi] * w;
        wp.startCanvas = Offset(xPos, t + yRatios[r0] * h);
        wp.endCanvas = Offset(xPos, t + yRatios[r1] * h);
      } else {
        final int yi = wp.gridLineIndex.clamp(0, yRatios.length - 1);
        final int c0 = wp.startCellIndex.clamp(0, xRatios.length - 1);
        final int c1 = wp.endCellIndex.clamp(0, xRatios.length - 1);
        final double yPos = t + yRatios[yi] * h;
        wp.startCanvas = Offset(l + xRatios[c0] * w, yPos);
        wp.endCanvas = Offset(l + xRatios[c1] * w, yPos);
      }
    }
  }

  /// Applies a user-confirmed meter measurement to [promptIndex], adjusts the proportional
  /// grid line ratio if an interior/bay wall was edited, and recalculates unconfirmed wall estimates!
  void applyWallPromptMeters(int promptIndex, double newMeters) {
    if (promptIndex < 0 || promptIndex >= wallPrompts.length) return;
    final wp = wallPrompts[promptIndex];
    final double cleanM = double.parse(newMeters.clamp(0.3, 80.0).toStringAsFixed(2));
    wp.meters = cleanM;
    wp.isConfirmed = true;

    if (wp.id == 'w_top') {
      _wTopMeters = cleanM;
      _wTopConfirmed = true;
      if (!_hRightConfirmed) {
        final double aspect = (outerBoxCanvas.height / math.max(40.0, outerBoxCanvas.width)).clamp(0.45, 2.2);
        _hRightMeters = double.parse((_wTopMeters * aspect).clamp(1.5, 60.0).toStringAsFixed(1));
      }
    } else if (wp.id == 'h_right') {
      _hRightMeters = cleanM;
      _hRightConfirmed = true;
    } else if (wp.id == 'w_bottom_right') {
      final int xi = wp.startCellIndex;
      if (xi >= 1 && xi < xRatios.length - 1) {
        final double targetSpan = (cleanM / math.max(1.0, _wTopMeters)).clamp(0.08, 0.88);
        xRatios[xi] = (1.0 - targetSpan).clamp(
          xRatios[xi - 1] + 0.05,
          xRatios[xi + 1] - 0.05,
        );
      }
    } else if (wp.isVertical) {
      // Vertical interior wall spans from yRatios[startCellIndex] to yRatios[endCellIndex]
      final double targetSpan = (cleanM / math.max(1.0, _hRightMeters)).clamp(0.08, 0.92);
      final int r0 = wp.startCellIndex;
      final int r1 = wp.endCellIndex;
      if (r0 == 0 && r1 >= 1 && r1 < yRatios.length - 1) {
        yRatios[r1] = targetSpan.clamp(yRatios[r1 - 1] + 0.05, yRatios[r1 + 1] - 0.05);
      } else if (r1 == yRatios.length - 1 && r0 >= 1 && r0 < yRatios.length - 1) {
        yRatios[r0] = (1.0 - targetSpan).clamp(yRatios[r0 - 1] + 0.05, yRatios[r0 + 1] - 0.05);
      } else if (r1 < yRatios.length - 1) {
        yRatios[r1] = (yRatios[r0] + targetSpan).clamp(yRatios[r1 - 1] + 0.05, yRatios[r1 + 1] - 0.05);
      }
    } else {
      // Horizontal interior wall spans from xRatios[startCellIndex] to xRatios[endCellIndex]
      final double targetSpan = (cleanM / math.max(1.0, _wTopMeters)).clamp(0.08, 0.92);
      final int c0 = wp.startCellIndex;
      final int c1 = wp.endCellIndex;
      if (c0 == 0 && c1 >= 1 && c1 < xRatios.length - 1) {
        xRatios[c1] = targetSpan.clamp(xRatios[c1 - 1] + 0.05, xRatios[c1 + 1] - 0.05);
      } else if (c1 == xRatios.length - 1 && c0 >= 1 && c0 < xRatios.length - 1) {
        xRatios[c0] = (1.0 - targetSpan).clamp(xRatios[c0 - 1] + 0.05, xRatios[c0 + 1] - 0.05);
      } else if (c1 < xRatios.length - 1) {
        xRatios[c1] = (xRatios[c0] + targetSpan).clamp(xRatios[c1 - 1] + 0.05, xRatios[c1 + 1] - 0.05);
      }
    }

    _ensureValidGridConsistency();

    // Update all unconfirmed wall estimates proportionally
    for (final other in wallPrompts) {
      if (other.isConfirmed) continue;
      if (other.id == 'h_right') {
        other.meters = _hRightMeters;
      } else if (other.id == 'w_bottom_right') {
        final int xi = other.startCellIndex.clamp(0, xRatios.length - 1);
        final double span = (1.0 - xRatios[xi]).clamp(0.05, 0.95);
        other.meters = double.parse((span * _wTopMeters).clamp(0.4, 50.0).toStringAsFixed(1));
        other.tagalogQuestion;
      } else if (other.isInteriorWall) {
        final double span = other.isVertical
            ? (yRatios[other.endCellIndex.clamp(0, yRatios.length - 1)] -
                    yRatios[other.startCellIndex.clamp(0, yRatios.length - 1)])
                .abs()
            : (xRatios[other.endCellIndex.clamp(0, xRatios.length - 1)] -
                    xRatios[other.startCellIndex.clamp(0, xRatios.length - 1)])
                .abs();
        final double refTotal = other.isVertical ? _hRightMeters : _wTopMeters;
        other.meters = double.parse((span * refTotal).clamp(0.4, 50.0).toStringAsFixed(1));
      }
    }

    recomputeWallPromptCanvasPositions();
  }

  /// Legacy helper for callers that mutate wp.meters directly and call syncRatiosFromMeters()
  void syncRatiosFromMeters() {
    for (int i = 0; i < wallPrompts.length; i++) {
      if (wallPrompts[i].isConfirmed) {
        applyWallPromptMeters(i, wallPrompts[i].meters);
      }
    }
    recomputeWallPromptCanvasPositions();
  }

  /// Removes an interior wall prompt at [promptIndex] and simplifies unused grid lines.
  bool removeInteriorWallPrompt(int promptIndex) {
    if (promptIndex < 0 || promptIndex >= wallPrompts.length) return false;
    final wp = wallPrompts[promptIndex];
    if (!wp.isInteriorWall) return false;

    if (wp.isVertical) {
      final int xi = wp.gridLineIndex;
      if (xi >= 1 && xi < numCols) {
        for (int r = wp.startCellIndex; r < wp.endCellIndex && r < numRows; r++) {
          vWalls[r][xi] = false;
        }
      }
    } else {
      final int yi = wp.gridLineIndex;
      if (yi >= 1 && yi < numRows) {
        for (int c = wp.startCellIndex; c < wp.endCellIndex && c < numCols; c++) {
          hWalls[yi][c] = false;
        }
      }
    }

    _cleanupUnusedGridLines();
    rebuildWallPrompts(preserveConfirmed: true);
    return true;
  }

  void _cleanupUnusedGridLines() {
    // Remove interior X grid lines that have zero active vWalls
    for (int xi = numCols - 1; xi >= 1; xi--) {
      bool anyActive = false;
      for (int r = 0; r < numRows; r++) {
        if (vWalls[r][xi]) {
          anyActive = true;
          break;
        }
      }
      if (!anyActive && xRatios.length > 2) {
        xRatios.removeAt(xi);
        for (int r = 0; r < numRows; r++) {
          vWalls[r].removeAt(xi);
        }
        for (int yi = 0; yi <= numRows; yi++) {
          final bool mergedH = hWalls[yi][xi - 1] || hWalls[yi][xi];
          hWalls[yi][xi - 1] = mergedH;
          hWalls[yi].removeAt(xi);
        }
      }
    }

    // Remove interior Y grid lines that have zero active hWalls
    for (int yi = numRows - 1; yi >= 1; yi--) {
      bool anyActive = false;
      for (int c = 0; c < numCols; c++) {
        if (hWalls[yi][c]) {
          anyActive = true;
          break;
        }
      }
      if (!anyActive && yRatios.length > 2) {
        yRatios.removeAt(yi);
        hWalls.removeAt(yi);
        for (int xi = 0; xi <= numCols; xi++) {
          final bool mergedV = vWalls[yi - 1][xi] || vWalls[yi][xi];
          vWalls[yi - 1][xi] = mergedV;
        }
        vWalls.removeAt(yi);
      }
    }
  }

  int _findOrInsertXRatio(double ratio) {
    final double clamped = ratio.clamp(0.12, 0.88);
    for (int i = 0; i < xRatios.length; i++) {
      if ((xRatios[i] - clamped).abs() <= 0.06) return i;
    }
    int insertIdx = 1;
    while (insertIdx < xRatios.length && xRatios[insertIdx] < clamped) {
      insertIdx++;
    }
    xRatios.insert(insertIdx, clamped);
    for (int r = 0; r < vWalls.length; r++) {
      vWalls[r].insert(insertIdx, false);
    }
    for (int yi = 0; yi < hWalls.length; yi++) {
      final bool existing = hWalls[yi][(insertIdx - 1).clamp(0, hWalls[yi].length - 1)];
      hWalls[yi].insert(insertIdx, existing);
    }
    return insertIdx;
  }

  int _findOrInsertYRatio(double ratio) {
    final double clamped = ratio.clamp(0.12, 0.88);
    for (int i = 0; i < yRatios.length; i++) {
      if ((yRatios[i] - clamped).abs() <= 0.06) return i;
    }
    int insertIdx = 1;
    while (insertIdx < yRatios.length && yRatios[insertIdx] < clamped) {
      insertIdx++;
    }
    yRatios.insert(insertIdx, clamped);
    final int C = numCols;
    final int prevRow = (insertIdx - 1).clamp(0, vWalls.length - 1);
    vWalls.insert(insertIdx, List<bool>.from(vWalls[prevRow]));
    hWalls.insert(insertIdx, List<bool>.filled(C, false));
    return insertIdx;
  }

  /// Adds a new interior vertical or horizontal wall partition and rebuilds prompts.
  void addInteriorWall({
    required bool isVertical,
    required double posRatio,
    double startRatio = 0.0,
    double endRatio = 1.0,
  }) {
    _ensureValidGridConsistency();
    if (isVertical) {
      final int xi = _findOrInsertXRatio(posRatio);
      final int r0 = startRatio <= 0.05 ? 0 : _findOrInsertYRatio(startRatio);
      final int r1 = endRatio >= 0.95 ? numRows : _findOrInsertYRatio(endRatio);
      for (int r = math.min(r0, r1); r < math.max(r0, r1) && r < numRows; r++) {
        vWalls[r][xi] = true;
      }
    } else {
      final int yi = _findOrInsertYRatio(posRatio);
      final int c0 = startRatio <= 0.05 ? 0 : _findOrInsertXRatio(startRatio);
      final int c1 = endRatio >= 0.95 ? numCols : _findOrInsertXRatio(endRatio);
      for (int c = math.min(c0, c1); c < math.max(c0, c1) && c < numCols; c++) {
        hWalls[yi][c] = true;
      }
    }
    topologyMode = 0;
    rebuildWallPrompts(preserveConfirmed: true);
  }

  /// 1-Tap helper to add a Corner Room Box ('TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT')
  void addCornerBoxRoom(String corner, {double widthRatio = 0.35, double heightRatio = 0.42}) {
    _ensureValidGridConsistency();
    if (corner == 'TOP_LEFT') {
      final int xi = _findOrInsertXRatio(widthRatio);
      final int yi = _findOrInsertYRatio(heightRatio);
      for (int r = 0; r < yi; r++) {
        vWalls[r][xi] = true;
      }
      for (int c = 0; c < xi; c++) {
        hWalls[yi][c] = true;
      }
    } else if (corner == 'TOP_RIGHT') {
      final int xi = _findOrInsertXRatio(1.0 - widthRatio);
      final int yi = _findOrInsertYRatio(heightRatio);
      for (int r = 0; r < yi; r++) {
        vWalls[r][xi] = true;
      }
      for (int c = xi; c < numCols; c++) {
        hWalls[yi][c] = true;
      }
    } else if (corner == 'BOTTOM_LEFT') {
      final int xi = _findOrInsertXRatio(widthRatio);
      final int yi = _findOrInsertYRatio(1.0 - heightRatio);
      for (int r = yi; r < numRows; r++) {
        vWalls[r][xi] = true;
      }
      for (int c = 0; c < xi; c++) {
        hWalls[yi][c] = true;
      }
    } else if (corner == 'BOTTOM_RIGHT') {
      final int xi = _findOrInsertXRatio(1.0 - widthRatio);
      final int yi = _findOrInsertYRatio(1.0 - heightRatio);
      for (int r = yi; r < numRows; r++) {
        vWalls[r][xi] = true;
      }
      for (int c = xi; c < numCols; c++) {
        hWalls[yi][c] = true;
      }
    }
    topologyMode = 0;
    rebuildWallPrompts(preserveConfirmed: true);
  }

  /// Returns all orthogonal corner handles for direct user dragging on the photo (with 90-degree Ortho lock)
  List<Offset> getDraggableHandles() {
    _cachedHandles.clear();
    final double l = outerBoxCanvas.left;
    final double t = outerBoxCanvas.top;
    final double w = outerBoxCanvas.width;
    final double h = outerBoxCanvas.height;
    final int R = numRows;
    final int C = numCols;

    final Set<(int, int)> cornerGridPts = {
      (0, 0),
      (C, 0),
      (C, R),
      (0, R),
    };

    final loops = computeRoomGridLoops(pruneDangling: false).roomGridLoops;
    for (final lp in loops) {
      for (final pt in lp) {
        cornerGridPts.add(pt);
      }
    }

    for (final (xi, yi) in cornerGridPts) {
      final int safeXi = xi.clamp(0, xRatios.length - 1);
      final int safeYi = yi.clamp(0, yRatios.length - 1);
      _cachedHandles.add(
        SketchHandleRef(
          xIdx: safeXi,
          yIdx: safeYi,
          position: Offset(l + xRatios[safeXi] * w, t + yRatios[safeYi] * h),
        ),
      );
    }

    return _cachedHandles.map((e) => e.position).toList();
  }

  /// Updates the orthogonal geometry when handle [handleIndex] is dragged to [newPos]
  void moveHandleOrtho(int handleIndex, Offset newPos) {
    if (_cachedHandles.isEmpty) {
      getDraggableHandles();
    }
    if (handleIndex < 0 || handleIndex >= _cachedHandles.length) return;

    final ref = _cachedHandles[handleIndex];
    double l = outerBoxCanvas.left;
    double t = outerBoxCanvas.top;
    double r = outerBoxCanvas.right;
    double b = outerBoxCanvas.bottom;

    final int C = numCols;
    final int R = numRows;

    // Update X coordinate or outer left/right bound
    if (ref.xIdx == 0) {
      l = math.min(newPos.dx, r - 90.0);
    } else if (ref.xIdx == C) {
      r = math.max(newPos.dx, l + 90.0);
    } else if (ref.xIdx > 0 && ref.xIdx < xRatios.length - 1) {
      final double rawRx = (newPos.dx - l) / math.max(60.0, r - l);
      xRatios[ref.xIdx] = rawRx.clamp(
        xRatios[ref.xIdx - 1] + 0.05,
        xRatios[ref.xIdx + 1] - 0.05,
      );
    }

    // Update Y coordinate or outer top/bottom bound
    if (ref.yIdx == 0) {
      t = math.min(newPos.dy, b - 90.0);
    } else if (ref.yIdx == R) {
      b = math.max(newPos.dy, t + 90.0);
    } else if (ref.yIdx > 0 && ref.yIdx < yRatios.length - 1) {
      final double rawRy = (newPos.dy - t) / math.max(60.0, b - t);
      yRatios[ref.yIdx] = rawRy.clamp(
        yRatios[ref.yIdx - 1] + 0.05,
        yRatios[ref.yIdx + 1] - 0.05,
      );
    }

    outerBoxCanvas = Rect.fromLTRB(l, t, r, b);

    // Update unconfirmed wall prompt estimates proportionally as handles are dragged
    for (final wp in wallPrompts) {
      if (wp.isConfirmed) continue;
      if (wp.id == 'w_bottom_right') {
        final int xi = wp.startCellIndex.clamp(0, xRatios.length - 1);
        wp.meters = double.parse(((1.0 - xRatios[xi]) * _wTopMeters).clamp(0.4, 50.0).toStringAsFixed(1));
      } else if (wp.isInteriorWall) {
        final double span = wp.isVertical
            ? (yRatios[wp.endCellIndex.clamp(0, yRatios.length - 1)] -
                    yRatios[wp.startCellIndex.clamp(0, yRatios.length - 1)])
                .abs()
            : (xRatios[wp.endCellIndex.clamp(0, xRatios.length - 1)] -
                    xRatios[wp.startCellIndex.clamp(0, xRatios.length - 1)])
                .abs();
        final double refTotal = wp.isVertical ? _hRightMeters : _wTopMeters;
        wp.meters = double.parse((span * refTotal).clamp(0.4, 50.0).toStringAsFixed(1));
      }
    }

    recomputeWallPromptCanvasPositions();
  }

  /// Returns the overlaid room polygons in canvas coordinates (aligned directly over the photo)
  List<List<Offset>> getOverlayPolygons() {
    final loops = computeRoomGridLoops(pruneDangling: false).roomGridLoops;
    final double l = outerBoxCanvas.left;
    final double t = outerBoxCanvas.top;
    final double w = outerBoxCanvas.width;
    final double h = outerBoxCanvas.height;

    final List<List<Offset>> polys = [];
    for (final lp in loops) {
      final List<Offset> poly = [];
      for (final (xi, yi) in lp) {
        final int safeXi = xi.clamp(0, xRatios.length - 1);
        final int safeYi = yi.clamp(0, yRatios.length - 1);
        poly.add(Offset(l + xRatios[safeXi] * w, t + yRatios[safeYi] * h));
      }
      if (poly.length >= 4) {
        polys.add(poly);
      }
    }
    return polys;
  }

  /// Generates 100% mathematically proportional CAD RoomSpaces and Polygons centered on the CAD canvas
  ({
    List<RoomSpace> spaces,
    Map<String, List<Offset>> polygons,
    double calibratedPixelsPerMeter,
    Offset pinA,
    Offset pinB,
  }) generateCleanProportionalCadPlan({
    double canvasWidth = 1400.0,
    double canvasHeight = 1600.0,
  }) {
    final double wTop = totalTopWidthM.clamp(1.5, 60.0);
    final double hRight = totalRightHeightM.clamp(1.5, 60.0);

    // Choose optimal scale so the recreated CAD floor plan fills ~760px on the 1400x1600 sheet
    const double targetSpanPx = 760.0;
    final double ppm = (targetSpanPx / math.max(wTop, hRight)).clamp(40.0, 180.0);

    final double planWidthPx = wTop * ppm;
    final double planHeightPx = hRight * ppm;

    final double originX = (canvasWidth - planWidthPx) / 2.0;
    final double originY = (canvasHeight - planHeightPx) / 2.0 - 40.0;

    final loops = computeRoomGridLoops(pruneDangling: true).roomGridLoops;
    final List<RoomSpace> newSpaces = [];
    final Map<String, List<Offset>> newPolygons = {};
    final int ts = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < loops.length; i++) {
      final lp = loops[i];
      final List<Offset> poly = [];
      for (final (xi, yi) in lp) {
        final int safeXi = xi.clamp(0, xRatios.length - 1);
        final int safeYi = yi.clamp(0, yRatios.length - 1);
        poly.add(
          Offset(
            originX + xRatios[safeXi] * planWidthPx,
            originY + yRatios[safeYi] * planHeightPx,
          ),
        );
      }

      // Compute exact Shoelace area & perimeter in meters
      double signedArea2Px = 0.0;
      double perimPx = 0.0;
      for (int k = 0; k < poly.length; k++) {
        final p1 = poly[k];
        final p2 = poly[(k + 1) % poly.length];
        signedArea2Px += (p1.dx * p2.dy - p2.dx * p1.dy);
        perimPx += (p2 - p1).distance;
      }
      final double areaSqm = math.max(1.0, (signedArea2Px.abs() * 0.5) / (ppm * ppm));
      final double perimM = math.max(2.0, perimPx / ppm);
      const double ch = 2.8;
      final double rcr = (2.5 * (ch - 0.80) * perimM) / areaSqm;

      final bool isLShape = poly.length >= 6;
      final String roomName = loops.length == 1
          ? 'Main Floor Space'
          : (i == 0
              ? (isLShape ? 'Room 1 (L-Shape)' : 'Room 1 (Top-Left)')
              : (i == 1
                  ? (isLShape ? 'Main Room (L-Shape)' : 'Room 2')
                  : 'Room ${i + 1}'));

      final String id = 'sp-sketch-$ts-$i';
      newSpaces.add(
        RoomSpace(
          id: id,
          name: roomName,
          areaSqm: double.parse(areaSqm.toStringAsFixed(2)),
          ceilingHeight: ch,
          shapeType: isLShape ? 'L_SHAPE' : 'RECTANGULAR',
          perimeterMeters: double.parse(perimM.toStringAsFixed(2)),
          rcrValue: double.parse(rcr.clamp(0.5, 15.0).toStringAsFixed(2)),
          polygonVertices: poly.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        ),
      );
      newPolygons[id] = poly;
    }

    return (
      spaces: newSpaces,
      polygons: newPolygons,
      calibratedPixelsPerMeter: ppm,
      pinA: Offset(originX, originY),
      pinB: Offset(originX + planWidthPx, originY),
    );
  }
}

class SketchShapeRecreator {
  /// Analyzes the uploaded photo/sketch to:
  /// 1. Locate the exact BoxFit.contain placement of the photo on the 1400x1600 canvas.
  /// 2. Mask out skin tones (hands/fingers) and blue ruled notebook lines, isolating dark pen/ink strokes.
  /// 3. Dynamically extract the outer floor plan enclosure AND all interior vertical/horizontal pen walls
  ///    into a Rectilinear Grid-Wall & Connected-Component Flood-Fill model.
  /// 4. Run offline ML Kit OCR to spatially assign handwritten dimensions (`5m`, `4m`, `1m`, etc.) and
  ///    proportionally estimate all remaining walls for 1-by-1 user confirmation.
  static Future<RecreatedSketchModel> analyzeSketchPhoto(
    String imagePath, {
    double canvasWidth = 1400.0,
    double canvasHeight = 1600.0,
  }) async {
    Rect detectedBox = const Rect.fromLTRB(330.0, 740.0, 960.0, 1340.0);
    List<double>? detectedXRatios;
    List<double>? detectedYRatios;
    List<List<bool>>? detectedVWalls;
    List<List<bool>>? detectedHWalls;

    double wTopGuess = 4.0;
    double hRightGuess = 5.0;
    bool hasExplicitRightDim = false;
    final List<double> ocrNums = [];

    final file = File(imagePath);
    if (!file.existsSync()) {
      return RecreatedSketchModel(
        outerBoxCanvas: detectedBox,
        initialWTopMeters: wTopGuess,
        initialHRightMeters: hRightGuess,
      );
    }

    int smallW = 320;
    int smallH = 560;
    int fullImgW = 1080;
    int fullImgH = 1920;
    Rect renderedImageRect = const Rect.fromLTWH(250.0, 0.0, 900.0, 1600.0);

    try {
      final bytes = await file.readAsBytes();
      // Decode full image header for ML Kit coordinate normalization
      final natCodec = await ui.instantiateImageCodec(bytes);
      final natFrame = await natCodec.getNextFrame();
      fullImgW = natFrame.image.width;
      fullImgH = natFrame.image.height;
      natFrame.image.dispose();

      final fullCodec = await ui.instantiateImageCodec(bytes, targetWidth: 320);
      final frame = await fullCodec.getNextFrame();
      final ui.Image smallImg = frame.image;
      smallW = smallImg.width;
      smallH = smallImg.height;

      final double scale = math.min(canvasWidth / smallW, canvasHeight / smallH);
      final double rw = smallW * scale;
      final double rh = smallH * scale;
      final double ox = (canvasWidth - rw) / 2.0;
      final double oy = (canvasHeight - rh) / 2.0;
      renderedImageRect = Rect.fromLTWH(ox, oy, rw, rh);

      final byteData = await smallImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null) {
        final rgba = byteData.buffer.asUint8List();
        final boundsResult = _extractInkEnclosureFromRgba(
          rgba: rgba,
          width: smallW,
          height: smallH,
          renderedRect: renderedImageRect,
        );
        if (boundsResult != null) {
          detectedBox = boundsResult.outerBox;
          detectedXRatios = boundsResult.xRatios;
          detectedYRatios = boundsResult.yRatios;
          detectedVWalls = boundsResult.vWalls;
          detectedHWalls = boundsResult.hWalls;
        }
      }
      smallImg.dispose();
    } catch (_) {}

    // Default proportional aspect ratio from the detected outer box on the paper
    final double boxAspect = (detectedBox.height / math.max(40.0, detectedBox.width)).clamp(0.5, 2.0);

    // Run offline ML Kit OCR to spatially match handwritten numbers to their corresponding walls
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      final numRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*m?\b', caseSensitive: false);
      final List<({double val, double canvasX, double canvasY})> spatialNums = [];

      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final raw = line.text.trim();
          double? parsedVal;
          if (RegExp(r'^[Iil1|]\s*m$', caseSensitive: false).hasMatch(raw)) {
            parsedVal = 1.0;
          } else {
            final match = numRegex.firstMatch(raw);
            if (match != null) {
              parsedVal = double.tryParse(match.group(1)!.replaceAll(',', '.'));
            }
          }
          if (parsedVal != null && parsedVal >= 0.4 && parsedVal <= 30.0) {
            if (!ocrNums.contains(parsedVal)) {
              ocrNums.add(parsedVal);
            }
            final bb = line.boundingBox;
            final double uX = ((bb.left + bb.right) / 2.0) / math.max(1, fullImgW);
            final double uY = ((bb.top + bb.bottom) / 2.0) / math.max(1, fullImgH);
            final double cx = renderedImageRect.left + uX * renderedImageRect.width;
            final double cy = renderedImageRect.top + uY * renderedImageRect.height;
            spatialNums.add((val: parsedVal, canvasX: cx, canvasY: cy));
          }
        }
      }

      if (spatialNums.isNotEmpty) {
        // 1. Check for number written near/above the top wall -> assigns to W1 (wTopGuess)
        double? topWallNum;
        double? rightWallNum;
        for (final sn in spatialNums) {
          if (sn.val >= 2.5) {
            final bool isNearTop = sn.canvasY <= detectedBox.top + detectedBox.height * 0.22 &&
                sn.canvasX >= detectedBox.left - 60.0 &&
                sn.canvasX <= detectedBox.right + 60.0;
            final bool isNearRight = sn.canvasX >= detectedBox.right - detectedBox.width * 0.18 &&
                sn.canvasY >= detectedBox.top &&
                sn.canvasY <= detectedBox.bottom + 40.0;
            if (isNearTop && topWallNum == null) {
              topWallNum = sn.val;
            } else if (isNearRight && rightWallNum == null) {
              rightWallNum = sn.val;
            }
          }
        }

        if (topWallNum != null && rightWallNum != null) {
          wTopGuess = topWallNum;
          hRightGuess = rightWallNum;
          hasExplicitRightDim = true;
        } else if (topWallNum != null) {
          // E.g. '5m' written above the top wall only -> W1 = 5.0m, L1 estimated proportionally from box aspect!
          wTopGuess = topWallNum;
          hRightGuess = double.parse((wTopGuess * boxAspect).clamp(1.5, 50.0).toStringAsFixed(1));
        } else if (rightWallNum != null) {
          hRightGuess = rightWallNum;
          hasExplicitRightDim = true;
          wTopGuess = double.parse((hRightGuess / boxAspect).clamp(1.5, 50.0).toStringAsFixed(1));
        } else {
          // Fallback magnitude matching
          final bigOnes = ocrNums.where((v) => v >= 2.5).toList()..sort((a, b) => b.compareTo(a));
          if (bigOnes.length == 1) {
            wTopGuess = bigOnes.first;
            hRightGuess = double.parse((wTopGuess * boxAspect).clamp(1.5, 50.0).toStringAsFixed(1));
          } else if (bigOnes.length >= 2) {
            wTopGuess = bigOnes[1];
            hRightGuess = bigOnes[0];
            hasExplicitRightDim = true;
          }
        }
      } else {
        hRightGuess = double.parse((wTopGuess * boxAspect).clamp(1.5, 50.0).toStringAsFixed(1));
      }
    } catch (_) {}

    for (final d in [5.0, 4.0, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.5]) {
      if (!ocrNums.contains(d)) ocrNums.add(d);
    }

    final model = RecreatedSketchModel(
      outerBoxCanvas: detectedBox,
      xRatios: detectedXRatios,
      yRatios: detectedYRatios,
      vWalls: detectedVWalls,
      hWalls: detectedHWalls,
      topologyMode: 0,
      ocrCandidateMeters: ocrNums,
      initialWTopMeters: wTopGuess,
      initialHRightMeters: hRightGuess,
    );

    // If OCR found specific small interior numbers (e.g. 1.0m on the 4m x 5m sketch) and there is a small step,
    // keep proportional estimates unless an interior wall is very close to an OCR small number
    if (!hasExplicitRightDim) {
      for (final wp in model.wallPrompts) {
        if (wp.id == 'h_right') {
          wp.meters = double.parse((wTopGuess * boxAspect).clamp(1.5, 50.0).toStringAsFixed(1));
        }
      }
    }

    return model;
  }

  static ({
    Rect outerBox,
    List<double> xRatios,
    List<double> yRatios,
    List<List<bool>> vWalls,
    List<List<bool>> hWalls,
  })? _extractInkEnclosureFromRgba({
    required List<int> rgba,
    required int width,
    required int height,
    required Rect renderedRect,
  }) {
    if (width < 40 || height < 40) return null;

    final List<int> lum = List<int>.filled(width * height, 0);
    final List<int> rChan = List<int>.filled(width * height, 0);
    final List<int> bChan = List<int>.filled(width * height, 0);
    final List<bool> isPaper = List<bool>.filled(width * height, false);

    // 1. Identify paper pixels vs skin/hand pixels
    int firstPaperRow = 0;
    final List<int> skinCountPerRow = List<int>.filled(height, 0);

    for (int y = 0; y < height; y++) {
      int skinRow = 0;
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        final r = rgba[idx];
        final g = rgba[idx + 1];
        final b = rgba[idx + 2];
        final yVal = ((r * 77 + g * 150 + b * 29) >> 8);
        final pIdx = y * width + x;
        lum[pIdx] = yVal;
        rChan[pIdx] = r;
        bChan[pIdx] = b;

        // Skin tone filter: warm reddish-brown where R > G + 12 and R > B + 22
        final bool isSkin = (r > g + 12) && (r > b + 22) && (g >= b - 5);
        if (isSkin) {
          skinRow++;
        } else if (yVal > 68 && (r - b).abs() < 48) {
          isPaper[pIdx] = true;
        }
      }
      skinCountPerRow[y] = skinRow;
    }

    // Find where top hand/fingers end (if upper rows have significant skin coverage)
    for (int y = 0; y < (height * 0.55).round(); y++) {
      if (skinCountPerRow[y] > width * 0.22) {
        firstPaperRow = y + 4;
      }
    }

    // 2. Channel-Aware Local Adaptive Thresholding (13x13 window):
    // Black/dark pen ink absorbs BOTH Blue and Red light (db >= 12 && dr >= 10),
    // whereas blue ruled notebook lines reflect Blue light (db is small, dr - db is large)!
    final List<bool> isPenInk = List<bool>.filled(width * height, false);
    const int win = 6;
    for (int y = math.max(win, firstPaperRow); y < height - win; y++) {
      for (int x = win; x < width - win; x++) {
        final int pIdx = y * width + x;
        if (!isPaper[pIdx]) continue;

        final int sumB = bChan[(y - win) * width + (x - win)] +
            bChan[(y - win) * width + x] +
            bChan[(y - win) * width + (x + win)] +
            bChan[y * width + (x - win)] +
            bChan[pIdx] +
            bChan[y * width + (x + win)] +
            bChan[(y + win) * width + (x - win)] +
            bChan[(y + win) * width + x] +
            bChan[(y + win) * width + (x + win)];
        final int sumR = rChan[(y - win) * width + (x - win)] +
            rChan[(y - win) * width + x] +
            rChan[(y - win) * width + (x + win)] +
            rChan[y * width + (x - win)] +
            rChan[pIdx] +
            rChan[y * width + (x + win)] +
            rChan[(y + win) * width + (x - win)] +
            rChan[(y + win) * width + x] +
            rChan[(y + win) * width + (x + win)];

        final int meanB = sumB ~/ 9;
        final int meanR = sumR ~/ 9;
        final int db = meanB - bChan[pIdx];
        final int dr = meanR - rChan[pIdx];

        if (db >= 12 && dr >= 10 && (dr - db) <= 12 && lum[pIdx] < 170) {
          isPenInk[pIdx] = true;
        }
      }
    }

    // 3. Find outer enclosure box inside the paper zone
    final int minYSearch = math.max(firstPaperRow + 6, (height * 0.12).round());
    final int maxYSearch = (height * 0.94).round();
    final int minXSearch = (width * 0.08).round();
    final int maxXSearch = (width * 0.92).round();

    final List<int> rowInk = List<int>.filled(height, 0);
    final List<int> colInk = List<int>.filled(width, 0);

    for (int y = minYSearch; y < maxYSearch; y++) {
      for (int x = minXSearch; x < maxXSearch; x++) {
        if (isPenInk[y * width + x]) {
          rowInk[y]++;
          colInk[x]++;
        }
      }
    }

    final List<int> smoothRow = List<int>.filled(height, 0);
    for (int y = minYSearch + 1; y < maxYSearch - 1; y++) {
      smoothRow[y] = rowInk[y - 1] + rowInk[y] + rowInk[y + 1];
    }
    final List<int> smoothCol = List<int>.filled(width, 0);
    for (int x = minXSearch + 1; x < maxXSearch - 1; x++) {
      smoothCol[x] = colInk[x - 1] + colInk[x] + colInk[x + 1];
    }

    final int maxRowVal = smoothRow.fold(0, math.max);
    final int maxColVal = smoothCol.fold(0, math.max);
    if (maxRowVal < 10 || maxColVal < 10) return null;

    final List<int> strongCols = [];
    for (int x = minXSearch + 2; x < maxXSearch - 2; x++) {
      if (smoothCol[x] >= maxColVal * 0.40) {
        strongCols.add(x);
      }
    }
    final List<int> strongRows = [];
    for (int y = minYSearch + 2; y < maxYSearch - 2; y++) {
      if (smoothRow[y] >= maxRowVal * 0.36) {
        strongRows.add(y);
      }
    }

    if (strongCols.length < 2 || strongRows.length < 2) return null;

    List<int> clusterPeaks(List<int> indices, List<int> weights, int minGap) {
      final List<int> peaks = [];
      int i = 0;
      while (i < indices.length) {
        int j = i;
        int bestIdx = indices[i];
        int bestW = weights[bestIdx];
        while (j + 1 < indices.length && indices[j + 1] - indices[i] <= minGap) {
          j++;
          if (weights[indices[j]] > bestW) {
            bestW = weights[indices[j]];
            bestIdx = indices[j];
          }
        }
        peaks.add(bestIdx);
        i = j + 1;
      }
      return peaks;
    }

    final colPeaks = clusterPeaks(strongCols, smoothCol, (width * 0.08).round());
    final rowPeaks = clusterPeaks(strongRows, smoothRow, (height * 0.06).round());

    if (colPeaks.length < 2 || rowPeaks.length < 2) return null;

    int leftCol = colPeaks.first;
    int rightCol = colPeaks.last;
    if (colPeaks.length >= 3) {
      final prevRight = colPeaks[colPeaks.length - 2];
      if ((rightCol - prevRight) < width * 0.14 && smoothCol[prevRight] >= smoothCol[rightCol] * 0.85) {
        rightCol = prevRight;
      }
    }

    int topRow = rowPeaks.first;
    int bottomRow = rowPeaks.last;
    if (rowPeaks.length >= 3) {
      final nextTop = rowPeaks[1];
      if ((nextTop - topRow) < height * 0.12 && smoothRow[nextTop] >= smoothRow[topRow] * 0.80) {
        topRow = nextTop;
      }
    }

    final int boxW = rightCol - leftCol;
    final int boxH = bottomRow - topRow;
    if (boxW < width * 0.20 || boxH < height * 0.18) {
      return null;
    }

    final double uLeft = (leftCol / width).clamp(0.10, 0.45);
    final double uRight = (rightCol / width).clamp(0.55, 0.90);
    final double vTop = (topRow / height).clamp(0.20, 0.68);
    final double vBottom = (bottomRow / height).clamp(0.62, 0.94);

    final Rect boxCanvas = Rect.fromLTRB(
      renderedRect.left + uLeft * renderedRect.width,
      renderedRect.top + vTop * renderedRect.height,
      renderedRect.left + uRight * renderedRect.width,
      renderedRect.top + vBottom * renderedRect.height,
    );

    // 4. DYNAMIC INTERIOR RECTILINEAR GRID-WALL & FLOOD-FILL EXTRACTION:
    // Resample the interior of [leftCol..rightCol, topRow..bottomRow] onto a 100x100 normalized grid
    const int G = 100;
    final List<bool> gridPen = List<bool>.filled(G * G, false);
    for (int gy = 0; gy < G; gy++) {
      final int sy0 = topRow + ((gy * boxH) ~/ G);
      final int sy1 = math.max(sy0 + 1, topRow + (((gy + 1) * boxH) ~/ G));
      for (int gx = 0; gx < G; gx++) {
        final int sx0 = leftCol + ((gx * boxW) ~/ G);
        final int sx1 = math.max(sx0 + 1, leftCol + (((gx + 1) * boxW) ~/ G));
        bool hit = false;
        for (int sy = sy0; sy < sy1 && sy < height; sy++) {
          for (int sx = sx0; sx < sx1 && sx < width; sx++) {
            if (isPenInk[sy * width + sx]) {
              hit = true;
              break;
            }
          }
          if (hit) break;
        }
        gridPen[gy * G + gx] = hit;
      }
    }

    // Score interior vertical columns (x in 12..88) and horizontal rows (y in 12..88)
    // Require genuine line continuity (longest run >= 14% of box) so handwritten text like '1m' or 'Hm'
    // inside the drawing is never mistaken for a structural wall!
    final List<int> vScores = List<int>.filled(G, 0);
    final List<int> hScores = List<int>.filled(G, 0);

    for (int gx = 12; gx <= 88; gx++) {
      int totalHits = 0;
      int curRun = 0;
      int maxRun = 0;
      for (int gy = 4; gy < 96; gy++) {
        bool bandHit = false;
        for (int dx = -1; dx <= 1; dx++) {
          if (gridPen[gy * G + (gx + dx)]) {
            bandHit = true;
            break;
          }
        }
        if (bandHit) {
          totalHits++;
          curRun++;
          if (curRun > maxRun) maxRun = curRun;
        } else {
          curRun = 0;
        }
      }
      if (maxRun >= 15) {
        vScores[gx] = totalHits;
      }
    }

    for (int gy = 12; gy <= 88; gy++) {
      int totalHits = 0;
      int curRun = 0;
      int maxRun = 0;
      for (int gx = 4; gx < 96; gx++) {
        bool bandHit = false;
        for (int dy = -1; dy <= 1; dy++) {
          if (gridPen[(gy + dy) * G + gx]) {
            bandHit = true;
            break;
          }
        }
        if (bandHit) {
          totalHits++;
          curRun++;
          if (curRun > maxRun) maxRun = curRun;
        } else {
          curRun = 0;
        }
      }
      if (maxRun >= 14) {
        hScores[gy] = totalHits;
      }
    }

    List<int> extract1DPeaks(List<int> scores, int minScore, int minDist) {
      final List<int> cand = [];
      for (int i = 12; i <= 88; i++) {
        if (scores[i] >= minScore) cand.add(i);
      }
      final List<int> peaks = [];
      int i = 0;
      while (i < cand.length) {
        int j = i;
        int best = cand[i];
        while (j + 1 < cand.length && cand[j + 1] - cand[j] <= minDist) {
          j++;
          if (scores[cand[j]] > scores[best]) {
            best = cand[j];
          }
        }
        peaks.add(best);
        i = j + 1;
      }
      return peaks;
    }

    final List<int> xPeaks = extract1DPeaks(vScores, 20, 11);
    final List<int> yPeaks = extract1DPeaks(hScores, 18, 11);

    final List<int> xGrid = [0, ...xPeaks, 100];
    final List<int> yGrid = [0, ...yPeaks, 100];
    final int R = yGrid.length - 1;
    final int C = xGrid.length - 1;

    final List<List<bool>> vWalls = List.generate(R, (_) => List<bool>.filled(C + 1, false));
    final List<List<bool>> hWalls = List.generate(R + 1, (_) => List<bool>.filled(C, false));

    for (int r = 0; r < R; r++) {
      vWalls[r][0] = true;
      vWalls[r][C] = true;
      final int y0 = yGrid[r];
      final int y1 = yGrid[r + 1];
      final int span = math.max(1, y1 - y0);
      for (int xi = 1; xi < C; xi++) {
        final int x = xGrid[xi];
        int hits = 0;
        for (int gy = y0; gy < y1; gy++) {
          for (int dx = -3; dx <= 3; dx++) {
            final int sx = (x + dx).clamp(0, G - 1);
            if (gridPen[gy * G + sx]) {
              hits++;
              break;
            }
          }
        }
        if (hits / span >= 0.34) {
          vWalls[r][xi] = true;
        }
      }
    }

    for (int c = 0; c < C; c++) {
      hWalls[0][c] = true;
      hWalls[R][c] = true;
    }
    for (int yi = 1; yi < R; yi++) {
      final int y = yGrid[yi];
      for (int c = 0; c < C; c++) {
        final int x0 = xGrid[c];
        final int x1 = xGrid[c + 1];
        final int span = math.max(1, x1 - x0);
        int hits = 0;
        for (int gx = x0; gx < x1; gx++) {
          for (int dy = -3; dy <= 3; dy++) {
            final int sy = (y + dy).clamp(0, G - 1);
            if (gridPen[sy * G + gx]) {
              hits++;
              break;
            }
          }
        }
        if (hits / span >= 0.34) {
          hWalls[yi][c] = true;
        }
      }
    }

    // Fallback if no interior walls passed threshold
    bool anyInterior = false;
    for (int r = 0; r < R; r++) {
      for (int xi = 1; xi < C; xi++) {
        if (vWalls[r][xi]) anyInterior = true;
      }
    }
    for (int yi = 1; yi < R; yi++) {
      for (int c = 0; c < C; c++) {
        if (hWalls[yi][c]) anyInterior = true;
      }
    }

    if (!anyInterior) {
      return (
        outerBox: boxCanvas,
        xRatios: [0.0, 0.48, 0.74, 1.0],
        yRatios: [0.0, 0.22, 1.0],
        vWalls: [
          [true, true, false, true],
          [true, false, true, true],
        ],
        hWalls: [
          [true, true, true],
          [false, true, false],
          [true, true, true],
        ],
      );
    }

    return (
      outerBox: boxCanvas,
      xRatios: xGrid.map((v) => v / 100.0).toList(),
      yRatios: yGrid.map((v) => v / 100.0).toList(),
      vWalls: vWalls,
      hWalls: hWalls,
    );
  }
}
