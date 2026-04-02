import 'package:pdf/pdf.dart';

class ConstantesExamen {
  // Empaquetado general
  static const double margenPagina = 28;
  static const double separacionColumnas = 5;
  static const double espacioEntreBloques = 5;
  static const double alturaEstimadaEncabezado = 75;
  static const double paddingBloque = 2.5;
  static const double alturaTituloDobleLinea = 16.5;
  static const double margenInferiorTitulo = 4;

  // Ajustes OMR
  static const double alturaFilaPregunta = 13.2;
  static const double anchoNumeroPregunta = 15.4;
  static const double separacionEtiquetaPregunta = 2.2;
  static const double separacionBurbuja = 2.6;
  static const double tamanoBurbuja = 9.9;
  static const double separacionFilasColumnas = 6.6;

  // Estilos
  static const double anchoBordeBloque = 1.0;
  static const double tamanoFuenteFila = 7.7;
  static const double tamanoFuenteBurbuja = 5.7;
  static const double tamanoFuenteTitulo = 7.2;
  
  // Sistema de cuadrícula
  static const double anchoMinimoColumna = 10;
  static const int maxColumnas = 36;
  static const int minColumnas = 6;
  static const double margenSeguridadColumnaUnica = 4;
  static const double factorAnchoCaracterTitulo = 0.55;

  // Colores
  static const colorMaestro = PdfColors.deepPurple;
  static const colorAlumno = PdfColors.green700;
}