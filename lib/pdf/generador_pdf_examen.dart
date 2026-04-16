import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

import '../exam_models.dart';
import 'constantes_examen.dart';
import 'modelos_layout.dart';
import 'componentes_examen.dart';

class GeneradorPdfExamen {
  const GeneradorPdfExamen();

  Future<Uint8List> construirDocumento({
    required List<Materia> materias,
    required bool esClaveMaestro,
    required String nombresAlumnos,
    PdfPageFormat formatoPagina = PdfPageFormat.letter,
  }) async {
    final pdf = pw.Document();

    // 🔥 CARGAR ARUCO (NUEVO)
    final marker0 = pw.MemoryImage(
      (await rootBundle.load('lib/assets/aruco/marker_0.png')).buffer.asUint8List(),
    );
    final marker1 = pw.MemoryImage(
      (await rootBundle.load('lib/assets/aruco/marker_1.png')).buffer.asUint8List(),
    );
    final marker2 = pw.MemoryImage(
      (await rootBundle.load('lib/assets/aruco/marker_2.png')).buffer.asUint8List(),
    );
    final marker3 = pw.MemoryImage(
      (await rootBundle.load('lib/assets/aruco/marker_3.png')).buffer.asUint8List(),
    );

    final nombres = _resolverNombres(esClaveMaestro, nombresAlumnos);
    final anchoPagina = formatoPagina.width - (ConstantesExamen.margenPagina * 2);
    final altoContenido = formatoPagina.height - (ConstantesExamen.margenPagina * 2) - ConstantesExamen.alturaEstimadaEncabezado;

    final cantidadColumnas = _resolverCantidadColumnas(anchoPagina);
    final disenosDePaginas = _organizarPaginas(
      materias: materias,
      anchoPagina: anchoPagina,
      altoContenido: altoContenido,
      cantidadColumnas: cantidadColumnas,
    );

    for (final nombreAlumno in nombres) {
      for (final diseno in disenosDePaginas) {
        pdf.addPage(
          pw.Page(
            pageFormat: formatoPagina,
            margin: const pw.EdgeInsets.all(ConstantesExamen.margenPagina),
            build: (context) => _ensamblarPagina(
              nombreAlumno: nombreAlumno,
              esClaveMaestro: esClaveMaestro,
              diseno: diseno,
              marker0: marker0,
              marker1: marker1,
              marker2: marker2,
              marker3: marker3,
            ),
          ),
        );
      }
    }

    return pdf.save();
  }

  List<String> _resolverNombres(bool esClaveMaestro, String nombresAlumnos) {
    if (esClaveMaestro) return const ['CLAVE MAESTRO'];
    final nombres = nombresAlumnos.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return nombres.isEmpty ? [''] : nombres;
  }

  int _resolverCantidadColumnas(double anchoPagina) {
    for (var columnas = ConstantesExamen.maxColumnas; columnas >= ConstantesExamen.minColumnas; columnas--) {
      final espacioTotal = ConstantesExamen.separacionColumnas * (columnas - 1);
      if ((anchoPagina - espacioTotal) / columnas >= ConstantesExamen.anchoMinimoColumna) return columnas;
    }
    return ConstantesExamen.minColumnas;
  }

  List<DisenoPagina> _organizarPaginas({
    required List<Materia> materias,
    required double anchoPagina,
    required double altoContenido,
    required int cantidadColumnas,
  }) {
    final paginas = <DisenoPagina>[];
    var paginaActual = DisenoPagina(anchoPagina: anchoPagina, cantidadColumnas: cantidadColumnas);

    for (final materia in materias) {
      final bloque = BloqueMateria.desdeMateria(
        materia: materia,
        anchoPagina: anchoPagina,
        cantidadColumnas: cantidadColumnas,
      );

      while (true) {
        final ubicacion = paginaActual.buscarUbicacion(bloque);
        if (ubicacion.arriba + bloque.alturaEstimada <= altoContenido || paginaActual.estaVacia) {
          paginaActual.agregarBloque(bloque, ubicacion);
          break;
        }
        paginas.add(paginaActual);
        paginaActual = DisenoPagina(anchoPagina: anchoPagina, cantidadColumnas: cantidadColumnas);
      }
    }

    if (!paginaActual.estaVacia) paginas.add(paginaActual);
    return paginas;
  }

  pw.Widget _ensamblarPagina({
    required String nombreAlumno,
    required bool esClaveMaestro,
    required DisenoPagina diseno,
    required pw.MemoryImage marker0,
    required pw.MemoryImage marker1,
    required pw.MemoryImage marker2,
    required pw.MemoryImage marker3,
  }) {
    final offsetX = math.max(0.0, (diseno.anchoPagina - diseno.maximoDerecha) / 2.0);

    return pw.Stack(
      children: [
        // 🔥 ARUCO EN LUGAR DE CUADROS
        pw.Positioned(
          left: 6,
          top: 6,
          child: pw.Image(marker0, width: 24, height: 24),
        ),
        pw.Positioned(
          right: 6,
          top: 6,
          child: pw.Image(marker1, width: 24, height: 24),
        ),
        pw.Positioned(
          left: 6,
          bottom: 40,
          child: pw.Image(marker2, width: 24, height: 24),
        ),
        pw.Positioned(
          right: 6,
          bottom: 40,
          child: pw.Image(marker3, width: 24, height: 24),
        ),

        // 🔥 CONTENIDO ORIGINAL (SIN CAMBIOS)
        pw.Column(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.only(left: offsetX, right: offsetX),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: ComponentesExamen.construirEncabezado(
                  nombreAlumno: nombreAlumno,
                  esClaveMaestro: esClaveMaestro,
                ),
              ),
            ),
            if (diseno.bloques.isNotEmpty)
              pw.SizedBox(
                height: diseno.alturaContenido,
                child: pw.Stack(
                  children: diseno.bloques.map((b) => pw.Positioned(
                    left: b.izquierda + offsetX,
                    top: b.arriba,
                    child: pw.SizedBox(
                      width: b.bloque.anchoBloque,
                      child: ComponentesExamen.construirBloqueMateria(b.bloque),
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
