import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../exam_models.dart';
import '../pdf/generador_pdf_examen.dart';

class PdfPreviewScreen extends StatelessWidget {
  final List<Materia> materias;
  final bool esClaveMaestro;
  final String nombresAlumnos;
  static const GeneradorPdfExamen _generator = GeneradorPdfExamen();

  const PdfPreviewScreen({
    super.key,
    required this.materias,
    required this.esClaveMaestro,
    required this.nombresAlumnos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(esClaveMaestro ? 'Clave del Maestro' : 'Exámenes de Alumnos'),
        backgroundColor: esClaveMaestro ? Colors.deepPurple : Colors.green,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => _generator.construirDocumento(
          materias: materias,
          esClaveMaestro: esClaveMaestro,
          nombresAlumnos: nombresAlumnos,
          formatoPagina: format,
        ),
      ),
    );
  }
}