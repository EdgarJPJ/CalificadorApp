import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'constantes_examen.dart';
import 'modelos_layout.dart';

class ComponentesExamen {
  static pw.Widget marcador() => pw.Container(width: 14, height: 14, color: PdfColors.black);

  static List<pw.Widget> construirEncabezado({required String nombreAlumno, required bool esClaveMaestro}) {
    final colorAcento = esClaveMaestro ? ConstantesExamen.colorMaestro : ConstantesExamen.colorAlumno;
    final textoNombre = esClaveMaestro 
        ? 'Grado y Grupo: _______________________________'
        : (nombreAlumno.isEmpty ? 'Nombre del Alumno: ______________________________________________' : 'Nombre del Alumno: $nombreAlumno');

    return [
      pw.Text(
        esClaveMaestro ? 'CLAVE DE RESPUESTAS DEL MAESTRO' : 'HOJA DE RESPUESTAS DEL ALUMNO',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: colorAcento),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
        child: pw.Text(textoNombre, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1), color: PdfColors.grey200, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
        child: pw.Text('INSTRUCCIONES: 1. Use lápiz del número 2 o 2 1/2. 2. Rellene el círculo por completo. 3. Borre bien para corregir.', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.justify),
      ),
      pw.SizedBox(height: 8),
    ];
  }

  static pw.Widget construirBloqueMateria(BloqueMateria bloque) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(ConstantesExamen.paddingBloque),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: ConstantesExamen.anchoBordeBloque),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            height: bloque.alturaTitulo,
            width: bloque.anchoBloque - (ConstantesExamen.paddingBloque * 2),
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Center(child: pw.Text(bloque.materia.nombre.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: ConstantesExamen.tamanoFuenteTitulo), textAlign: pw.TextAlign.center, maxLines: 2)),
            ),
          ),
          pw.SizedBox(height: ConstantesExamen.margenInferiorTitulo),
          if (bloque.divididoInternamente)
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(children: bloque.preguntasIzquierda.map(construirFilaPregunta).toList()),
                pw.SizedBox(width: ConstantesExamen.separacionFilasColumnas),
                pw.Column(children: bloque.preguntasDerecha.map(construirFilaPregunta).toList()),
              ],
            )
          else
            pw.Column(children: bloque.preguntasIzquierda.map(construirFilaPregunta).toList()),
        ],
      ),
    );
  }

  static pw.Widget construirFilaPregunta(int numero) {
    return pw.SizedBox(
      height: ConstantesExamen.alturaFilaPregunta,
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(width: ConstantesExamen.anchoNumeroPregunta, child: pw.Text(numero.toString().padLeft(2, '0'), style: const pw.TextStyle(fontSize: ConstantesExamen.tamanoFuenteFila))),
          pw.SizedBox(width: ConstantesExamen.separacionEtiquetaPregunta),
          _construirBurbuja('A'), pw.SizedBox(width: ConstantesExamen.separacionBurbuja),
          _construirBurbuja('B'), pw.SizedBox(width: ConstantesExamen.separacionBurbuja),
          _construirBurbuja('C'), pw.SizedBox(width: ConstantesExamen.separacionBurbuja),
          _construirBurbuja('D'),
        ],
      ),
    );
  }

  static pw.Widget _construirBurbuja(String texto) {
    return pw.Container(
      width: ConstantesExamen.tamanoBurbuja,
      height: ConstantesExamen.tamanoBurbuja,
      decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.white, border: pw.Border.all(color: PdfColors.black, width: 1.2)),
      child: pw.Center(child: pw.Text(texto, style: pw.TextStyle(fontSize: ConstantesExamen.tamanoFuenteBurbuja, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
    );
  }
}