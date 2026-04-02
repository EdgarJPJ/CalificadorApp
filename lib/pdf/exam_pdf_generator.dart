import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../exam_models.dart';

class ExamPdfGenerator {
  const ExamPdfGenerator();

  // 1. CONSTANTES PARA UN EMPAQUETADO ULTRA DENSO
  static const double _pageMargin = 28;
  static const double _slotGap = 5;
  static const double _blockSpacing = 5;
  static const double _headerSpacing = 4;
  static const double _estimatedHeaderHeight = 75;

  static const double _blockPadding = 2.5;
  static const double _singleLineTitleHeight = 9.5;
  static const double _doubleLineTitleHeight = 16.5;
  static const double _titleBottomGap = 4;

  // 🔥 AJUSTES OMR (ESCALADOS 10%)
  static const double _questionRowHeight = 13.2; // 12 → 13.2
  static const double _questionNumberWidth = 15.4; // 14 → 15.4
  static const double _questionLabelGap = 2.2; // 2.0 → 2.2
  static const double _bubbleGap = 2.6; // 2.4 → 2.6
  static const double _bubbleSize = 9.9; // 9.0 → 9.9
  static const double _rowColumnGap = 6.6; // 6 → 6.6

  static const double _blockBorderWidth = 1.0;
  static const double _rowFontSize = 7.7; // 7.0 → 7.7
  static const double _bubbleFontSize = 5.7; // 5.2 → 5.7
  static const double _titleFontSize = 7.2; // 6.5 → 7.2

  // 2. SISTEMA DE CUADRÍCULA FINA (Permite empaquetado milimétrico)
  static const double _minSlotWidth = 10;
  static const int _maxSlots = 36;
  static const int _minSlots = 6;
  static const double _singleColumnSafetyWidth = 4;
  static const double _titleCharacterWidthFactor = 0.55;

  Future<Uint8List> buildDocument({
    required List<Materia> materias,
    required bool esClaveMaestro,
    required String nombresAlumnos,
    PdfPageFormat pageFormat = PdfPageFormat.letter,
  }) async {
    final pdf = pw.Document();
    final nombres = _resolverNombres(esClaveMaestro, nombresAlumnos);
    final pageWidth = pageFormat.width - (_pageMargin * 2);
    final contentHeight =
        pageFormat.height - (_pageMargin * 2) - _estimatedHeaderHeight;
    final slotCount = _resolveSlotCount(pageWidth);
    final pageLayouts = _layoutPages(
      materias: materias,
      pageWidth: pageWidth,
      contentHeight: contentHeight,
      slotCount: slotCount,
    );

    for (final nombreAlumno in nombres) {
      for (final pageLayout in pageLayouts) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(_pageMargin),
            build: (context) => _buildPage(
              nombreAlumno: nombreAlumno,
              esClaveMaestro: esClaveMaestro,
              pageLayout: pageLayout,
            ),
          ),
        );
      }
    }

    return pdf.save();
  }

  List<String> _resolverNombres(bool esClaveMaestro, String nombresAlumnos) {
    if (esClaveMaestro) {
      return const ['CLAVE MAESTRO'];
    }

    final nombres = nombresAlumnos
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return nombres.isEmpty ? [''] : nombres;
  }

  int _resolveSlotCount(double pageWidth) {
    for (var slots = _maxSlots; slots >= _minSlots; slots--) {
      final totalGap = _slotGap * (slots - 1);
      final slotWidth = (pageWidth - totalGap) / slots;
      if (slotWidth >= _minSlotWidth) {
        return slots;
      }
    }
    return _minSlots;
  }

  List<_PageLayout> _layoutPages({
    required List<Materia> materias,
    required double pageWidth,
    required double contentHeight,
    required int slotCount,
  }) {
    final pages = <_PageLayout>[];
    var currentPage = _PageLayout(pageWidth: pageWidth, slotCount: slotCount);

    for (final materia in materias) {
      final block = _MateriaLayoutBlock.fromMateria(
        materia: materia,
        pageWidth: pageWidth,
        slotCount: slotCount,
      );

      while (true) {
        final placement = currentPage.findPlacement(block);
        final blockBottom = placement.top + block.estimatedHeight;

        if (blockBottom <= contentHeight || currentPage.isEmpty) {
          currentPage.addBlock(block, placement);
          break;
        }

        pages.add(currentPage.finish());
        currentPage = _PageLayout(pageWidth: pageWidth, slotCount: slotCount);
      }
    }

    if (!currentPage.isEmpty) {
      pages.add(currentPage.finish());
    }

    return pages;
  }

  pw.Widget _buildPage({
    required String nombreAlumno,
    required bool esClaveMaestro,
    required _PageLayout pageLayout,
  }) {
    // 3. CÁLCULO DE CENTRADO TOTAL: Centra la "isla" de respuestas en la página
    final maxRight = pageLayout.maxRight;
    final offsetX = math.max(0.0, (pageLayout.pageWidth - maxRight) / 2.0);

    return pw.Stack(
      children: [
        pw.Positioned(left: 6, top: 6, child: marcador()),
        pw.Positioned(right: 6, top: 6, child: marcador()),
        pw.Positioned(left: 6, bottom: 40, child: marcador()),
        pw.Positioned(right: 6, bottom: 40, child: marcador()),
        pw.Column(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.only(left: offsetX, right: offsetX),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: _buildHeader(
                  nombreAlumno: nombreAlumno,
                  esClaveMaestro: esClaveMaestro,
                ),
              ),
            ),
            if (pageLayout.blocks.isNotEmpty)
              pw.SizedBox(
                height: pageLayout.contentHeight,
                child: pw.Stack(
                  children: [
                    for (final placedBlock in pageLayout.blocks)
                      pw.Positioned(
                        left:
                            placedBlock.left +
                            offsetX, // Aplica el centrado aquí
                        top: placedBlock.top,
                        child: pw.SizedBox(
                          width: placedBlock.block.blockWidth,
                          child: _buildBlock(placedBlock.block),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget marcador() {
    return pw.Container(width: 14, height: 14, color: PdfColors.black);
  }

  List<pw.Widget> _buildHeader({
    required String nombreAlumno,
    required bool esClaveMaestro,
  }) {
    final accentColor = esClaveMaestro
        ? PdfColors.deepPurple
        : PdfColors.green700;
    final nombreTexto = esClaveMaestro
        ? 'Grado y Grupo: _______________________________'
        : (nombreAlumno.isEmpty
              ? 'Nombre del Alumno: ______________________________________________'
              : 'Nombre del Alumno: $nombreAlumno');

    return [
      pw.Text(
        esClaveMaestro
            ? 'CLAVE DE RESPUESTAS DEL MAESTRO'
            : 'HOJA DE RESPUESTAS DEL ALUMNO',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: accentColor,
        ),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 10),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          nombreTexto,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
          color: PdfColors.grey200,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          'INSTRUCCIONES: 1. Use lápiz del número 2 o 2 1/2. 2. Rellene el círculo por completo. 3. Borre bien para corregir.',
          style: const pw.TextStyle(fontSize: 8),
          textAlign: pw.TextAlign.justify,
        ),
      ),
      pw.SizedBox(height: 8),
    ];
  }

  pw.Widget _buildBlock(_MateriaLayoutBlock block) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(_blockPadding),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: _blockBorderWidth),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            height: block.titleHeight,
            width: block.blockWidth - (_blockPadding * 2),
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2), // 🔥 clave
              child: pw.Center(
                child: pw.Text(
                  block.materia.nombre.toUpperCase(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: _titleFontSize,
                  ),
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: _titleBottomGap),
          if (block.splitInternally)
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  children: [
                    for (final question in block.leftQuestions)
                      _buildQuestionRow(question),
                  ],
                ),
                pw.SizedBox(width: _rowColumnGap),
                pw.Column(
                  children: [
                    for (final question in block.rightQuestions)
                      _buildQuestionRow(question),
                  ],
                ),
              ],
            )
          else
            pw.Column(
              children: [
                for (final question in block.leftQuestions)
                  _buildQuestionRow(question),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _buildQuestionRow(int numero) {
    return pw.SizedBox(
      height: _questionRowHeight,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: _questionNumberWidth,
            child: pw.Text(
              numero.toString().padLeft(2, '0'),
              style: const pw.TextStyle(fontSize: _rowFontSize),
            ),
          ),
          pw.SizedBox(width: _questionLabelGap),

          _buildBubble('A'),
          pw.SizedBox(width: _bubbleGap),
          _buildBubble('B'),
          pw.SizedBox(width: _bubbleGap),
          _buildBubble('C'),
          pw.SizedBox(width: _bubbleGap),
          _buildBubble('D'),
        ],
      ),
    );
  }

  pw.Widget _buildBubble(String texto) {
    return pw.Container(
      width: _bubbleSize,
      height: _bubbleSize,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColors.black,
          width: 1.2, // 🔥 más grueso para OMR
        ),
      ),
      child: pw.Center(
        child: pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: _bubbleFontSize,
            fontWeight: pw.FontWeight.bold, // 🔥 clave para escaneo
            color: PdfColors.black,
          ),
        ),
      ),
    );
  }
}

class _MateriaLayoutBlock {
  _MateriaLayoutBlock({
    required this.materia,
    required this.blockWidth,
    required this.slotSpan,
    required this.titleLineCount,
    required this.titleHeight,
    required this.estimatedHeight,
    required this.splitInternally,
    required this.leftQuestions,
    required this.rightQuestions,
  });

  final Materia materia;
  final double blockWidth;
  final int slotSpan;
  final int titleLineCount;
  final double titleHeight;
  final double estimatedHeight;
  final bool splitInternally;
  final List<int> leftQuestions;
  final List<int> rightQuestions;

  factory _MateriaLayoutBlock.fromMateria({
    required Materia materia,
    required double pageWidth,
    required int slotCount,
  }) {
    final splitInternally = materia.numeroPreguntas > 20;
    final leftCount = splitInternally
        ? (materia.numeroPreguntas / 2).ceil()
        : materia.numeroPreguntas;
    final rightCount = splitInternally
        ? materia.numeroPreguntas - leftCount
        : 0;

    final leftQuestions = List<int>.generate(leftCount, (index) => index + 1);
    final rightQuestions = List<int>.generate(
      rightCount,
      (index) => leftCount + index + 1,
    );

    final contentWidth = _contentWidthForQuestions(splitInternally);
    final titleMetrics = _TitleMetrics.fromTitle(materia.nombre);

    // 4. OPTIMIZACIÓN DE TÍTULOS: Permite que los títulos largos usen 2 líneas
    // para no ensanchar la caja innecesariamente y ahorrar más espacio.
    double minTitleWidth = titleMetrics.twoLineWidth;
    if (titleMetrics.singleLineWidth <= contentWidth) {
      minTitleWidth = titleMetrics.singleLineWidth;
    }

    final desiredBlockWidth =
        math.max(contentWidth, minTitleWidth) +
        (ExamPdfGenerator._blockPadding * 2);

    final slotSpan = _resolveSlotSpan(
      desiredBlockWidth: desiredBlockWidth,
      pageWidth: pageWidth,
      slotCount: slotCount,
    );
    final maxBlockWidth = _widthForSpan(
      pageWidth: pageWidth,
      slotCount: slotCount,
      span: slotSpan,
    );
    final blockWidth = math.min(desiredBlockWidth, maxBlockWidth);
    final titleContentWidth = blockWidth - (ExamPdfGenerator._blockPadding * 2);
    final titleLineCount = 2;
    final titleHeight = ExamPdfGenerator._doubleLineTitleHeight;

    final visibleRows = splitInternally ? leftCount : materia.numeroPreguntas;
    final estimatedHeight =
        (ExamPdfGenerator._blockPadding * 2) +
        titleHeight +
        ExamPdfGenerator._titleBottomGap +
        (visibleRows * ExamPdfGenerator._questionRowHeight) +
        2;

    return _MateriaLayoutBlock(
      materia: materia,
      blockWidth: blockWidth,
      slotSpan: slotSpan,
      titleLineCount: titleLineCount,
      titleHeight: titleHeight,
      estimatedHeight: estimatedHeight,
      splitInternally: splitInternally,
      leftQuestions: leftQuestions,
      rightQuestions: rightQuestions,
    );
  }

  static double _contentWidthForQuestions(bool splitInternally) {
    final questionColumnWidth =
        ExamPdfGenerator._questionNumberWidth +
        ExamPdfGenerator._questionLabelGap +
        (ExamPdfGenerator._bubbleSize * 4) +
        (ExamPdfGenerator._bubbleGap * 3);

    if (splitInternally) {
      return (questionColumnWidth * 2) + ExamPdfGenerator._rowColumnGap;
    }

    return questionColumnWidth + ExamPdfGenerator._singleColumnSafetyWidth;
  }

  static int _resolveTitleLineCount({
    required _TitleMetrics titleMetrics,
    required double titleContentWidth,
  }) {
    return titleMetrics.singleLineWidth <= titleContentWidth ? 1 : 2;
  }

  static int _resolveSlotSpan({
    required double desiredBlockWidth,
    required double pageWidth,
    required int slotCount,
  }) {
    for (var span = 1; span <= slotCount; span++) {
      final maxWidth = _widthForSpan(
        pageWidth: pageWidth,
        slotCount: slotCount,
        span: span,
      );
      if (desiredBlockWidth <= maxWidth) {
        return span;
      }
    }
    return slotCount;
  }

  static double _widthForSpan({
    required double pageWidth,
    required int slotCount,
    required int span,
  }) {
    final slotWidth =
        (pageWidth - (ExamPdfGenerator._slotGap * (slotCount - 1))) / slotCount;
    return (slotWidth * span) + (ExamPdfGenerator._slotGap * (span - 1));
  }
}

class _TitleMetrics {
  const _TitleMetrics({
    required this.singleLineWidth,
    required this.twoLineWidth,
  });

  final double singleLineWidth;
  final double twoLineWidth;

  factory _TitleMetrics.fromTitle(String title) {
    final normalized = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    final baseWidth =
        normalized.length *
        ExamPdfGenerator._titleFontSize *
        ExamPdfGenerator._titleCharacterWidthFactor;
    final words = normalized.isEmpty ? const <String>[] : normalized.split(' ');
    final longestWordChars = words.fold<int>(
      0,
      (current, word) => word.length > current ? word.length : current,
    );
    final longestWordWidth =
        longestWordChars *
        ExamPdfGenerator._titleFontSize *
        ExamPdfGenerator._titleCharacterWidthFactor;
    final halfWidth = baseWidth / 2;

    return _TitleMetrics(
      singleLineWidth: baseWidth + 12,
      twoLineWidth: math.max(longestWordWidth, halfWidth) + 10,
    );
  }
}

class _PlacedBlock {
  const _PlacedBlock({
    required this.block,
    required this.startSlot,
    required this.left,
    required this.top,
  });

  final _MateriaLayoutBlock block;
  final int startSlot;
  final double left;
  final double top;
}

class _PlacementCandidate {
  const _PlacementCandidate({
    required this.startSlot,
    required this.left,
    required this.top,
  });

  final int startSlot;
  final double left;
  final double top;
}

class _PageLayout {
  _PageLayout({required this.pageWidth, required this.slotCount})
    : _slotHeights = List<double>.filled(slotCount, 0);

  final double pageWidth;
  final int slotCount;
  final List<_PlacedBlock> blocks = [];
  final List<double> _slotHeights;

  double contentHeight = 0;

  bool get isEmpty => blocks.isEmpty;

  // Propiedad para conocer hasta dónde llega el contenido visualmente a la derecha
  double get maxRight {
    double max = 0.0;
    for (final b in blocks) {
      final rightEdge = b.left + b.block.blockWidth;
      if (rightEdge > max) {
        max = rightEdge;
      }
    }
    return max;
  }

  _PlacementCandidate findPlacement(_MateriaLayoutBlock block) {
    final maxStart = slotCount - block.slotSpan;
    var bestStart = 0;
    var bestTop = double.infinity;
    var bestSupportGap = double.infinity;
    var bestFutureBottom = double.infinity;
    var bestReservedSlack = double.infinity;

    for (var start = 0; start <= maxStart; start++) {
      var top = 0.0;
      var minCoveredHeight = double.infinity;
      for (var slot = start; slot < start + block.slotSpan; slot++) {
        if (_slotHeights[slot] > top) {
          top = _slotHeights[slot];
        }
        if (_slotHeights[slot] < minCoveredHeight) {
          minCoveredHeight = _slotHeights[slot];
        }
      }

      final supportGap = top - minCoveredHeight;
      final futureBottom = top + block.estimatedHeight;
      final reservedSlack =
          _reservedWidthForSpan(block.slotSpan) - block.blockWidth;

      final isBetter =
          top < bestTop ||
          (top == bestTop && supportGap < bestSupportGap) ||
          (top == bestTop &&
              supportGap == bestSupportGap &&
              futureBottom < bestFutureBottom) ||
          (top == bestTop &&
              supportGap == bestSupportGap &&
              futureBottom == bestFutureBottom &&
              reservedSlack < bestReservedSlack) ||
          (top == bestTop &&
              supportGap == bestSupportGap &&
              futureBottom == bestFutureBottom &&
              reservedSlack == bestReservedSlack &&
              start < bestStart);

      if (isBetter) {
        bestTop = top;
        bestStart = start;
        bestSupportGap = supportGap;
        bestFutureBottom = futureBottom;
        bestReservedSlack = reservedSlack;
      }
    }

    return _PlacementCandidate(
      startSlot: bestStart,
      left: _leftForSlot(bestStart),
      top: bestTop,
    );
  }

  void addBlock(_MateriaLayoutBlock block, _PlacementCandidate placement) {
    final allocatedWidth = _reservedWidthForSpan(block.slotSpan);
    final extraSpace = allocatedWidth - block.blockWidth;
    final centeredLeft = placement.left + (extraSpace / 2);

    blocks.add(
      _PlacedBlock(
        block: block,
        startSlot: placement.startSlot,
        left: centeredLeft,
        top: placement.top,
      ),
    );

    final slotBottom =
        placement.top + block.estimatedHeight + ExamPdfGenerator._blockSpacing;
    for (
      var slot = placement.startSlot;
      slot < placement.startSlot + block.slotSpan;
      slot++
    ) {
      _slotHeights[slot] = slotBottom;
    }

    final actualBottom = placement.top + block.estimatedHeight;
    if (actualBottom > contentHeight) {
      contentHeight = actualBottom;
    }
  }

  _PageLayout finish() {
    return this;
  }

  double _leftForSlot(int slotIndex) {
    final slotWidth =
        (pageWidth - (ExamPdfGenerator._slotGap * (slotCount - 1))) / slotCount;
    return slotIndex * (slotWidth + ExamPdfGenerator._slotGap);
  }

  double _reservedWidthForSpan(int span) {
    final slotWidth =
        (pageWidth - (ExamPdfGenerator._slotGap * (slotCount - 1))) / slotCount;
    return (slotWidth * span) + (ExamPdfGenerator._slotGap * (span - 1));
  }
}
