import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:convert'; // 🔥 Para leer el JSON de respuesta
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // 🔥 Para la cámara

void main() {
  runApp(const CalificadorApp());
}

class CalificadorApp extends StatelessWidget {
  const CalificadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generador y Lector de Exámenes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FormularioExamenScreen(),
    );
  }
}

class Materia {
  String nombre;
  int numeroPreguntas;
  Materia({required this.nombre, required this.numeroPreguntas});
}

class FormularioExamenScreen extends StatefulWidget {
  const FormularioExamenScreen({super.key});

  @override
  State<FormularioExamenScreen> createState() => _FormularioExamenScreenState();
}

class _FormularioExamenScreenState extends State<FormularioExamenScreen> {
  final TextEditingController _alumnosController = TextEditingController();

  List<Materia> materias = [
    Materia(nombre: "Lenguajes", numeroPreguntas: 20),
    Materia(nombre: "Saberes y Pensamiento Científico", numeroPreguntas: 30),
    Materia(nombre: "Ética, Naturaleza y Sociedades", numeroPreguntas: 15),
    Materia(nombre: "De lo Humano y lo Comunitario", numeroPreguntas: 25),
  ];

  void _agregarMateria() {
    setState(() {
      materias.add(Materia(nombre: "Nueva Materia", numeroPreguntas: 10));
    });
  }

  void _eliminarMateria(int index) {
    setState(() {
      materias.removeAt(index);
    });
  }

  void _generarPDF(bool esClaveMaestro) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewScreen(
          materias: materias,
          esClaveMaestro: esClaveMaestro,
          nombresAlumnos: _alumnosController.text,
        ),
      ),
    );
  }

  // 🔥 NUEVO: Función para abrir la cámara y enviar a Python
  Future<void> _escanearExamen() async {
    final ImagePicker picker = ImagePicker();
    // Abrimos la cámara
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      // Mostramos un diálogo de "Cargando..."
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Enviamos la foto y la lista de materias a Python
      Map<String, dynamic>? resultados = await subirExamen(photo.path, materias);

      // Cerramos el diálogo de "Cargando..."
      // ignore: use_build_context_synchronously
      Navigator.pop(context);

      if (resultados != null) {
        // Mostramos los resultados en pantalla
        _mostrarResultados(resultados);
      } else {
        // Mostramos error
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al conectar con el servidor")),
        );
      }
    }
  }

  // 🔥 NUEVO: Ventana emergente para mostrar el JSON calificado
  void _mostrarResultados(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Resultados del Examen"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: materias.length,
              itemBuilder: (context, index) {
                String nombreMateria = materias[index].nombre;
                // Obtenemos las respuestas de esta materia desde el JSON
                Map<String, dynamic> respuestas = data[nombreMateria] ?? {};
                
                return ExpansionTile(
                  title: Text(nombreMateria, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: respuestas.entries.map((entry) {
                    return ListTile(
                      dense: true,
                      title: Text("Pregunta ${entry.key}: Resp. ${entry.value}"),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cerrar"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Examen'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _alumnosController,
              decoration: const InputDecoration(
                labelText: 'Lista de Alumnos (Separados por coma)',
                hintText: 'Ej. Juan Pérez, Ana Gómez, Luis Díaz...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: materias.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: materias[index].nombre,
                              decoration: const InputDecoration(labelText: 'Materia'),
                              onChanged: (value) => materias[index].nombre = value,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: materias[index].numeroPreguntas.toString(),
                              decoration: const InputDecoration(labelText: 'Preguntas'),
                              keyboardType: TextInputType.number,
                              onChanged: (value) =>
                                  materias[index].numeroPreguntas = int.tryParse(value) ?? 10,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarMateria(index),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Botones de PDF
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generarPDF(false),
                    icon: const Icon(Icons.person),
                    label: const Text("Generar Alumnos", style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generarPDF(true),
                    icon: const Icon(Icons.school),
                    label: const Text("Clave Maestro", style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // 🔥 NUEVO: Gran botón para Escanear
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _escanearExamen,
                icon: const Icon(Icons.camera_alt, size: 28),
                label: const Text("ESCANEAR Y CALIFICAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarMateria,
        tooltip: 'Agregar Materia',
        child: const Icon(Icons.add),
      ),
    );
  }
}
class PdfPreviewScreen extends StatelessWidget {
  final List<Materia> materias;
  final bool esClaveMaestro;
  final String nombresAlumnos;

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
        build: (format) => _crearDocumentoPdf(format),
      ),
    );
  }

  Future<Uint8List> _crearDocumentoPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    List<String> listaNombres = [];
    if (esClaveMaestro) {
      listaNombres = ["CLAVE MAESTRO"];
    } else {
      listaNombres = nombresAlumnos
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (listaNombres.isEmpty) {
        listaNombres = [""];
      }
    }

    for (var nombreAlumno in listaNombres) {

      // ── ENCABEZADO ULTRA-REDUCIDO ──────────────────────────────────────────────
      final headerWidgets = [
        pw.Text(
          esClaveMaestro
              ? 'CLAVE DE RESPUESTAS DEL MAESTRO'
              : 'HOJA DE RESPUESTAS DEL ALUMNO',
          style: pw.TextStyle(
            fontSize: 14, 
            fontWeight: pw.FontWeight.bold,
            color: esClaveMaestro ? PdfColors.deepPurple : PdfColors.black,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4), 

        pw.Container(
          padding: const pw.EdgeInsets.all(5), 
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                esClaveMaestro
                    ? "Grado y Grupo: _______________________________"
                    : (nombreAlumno.isEmpty
                        ? "Nombre del Alumno: ____________________________________________________"
                        : "Nombre del Alumno:  $nombreAlumno"),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),

        pw.Container(
          padding: const pw.EdgeInsets.all(5), 
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
            color: PdfColors.grey200,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Text(
                  "INSTRUCCIONES:\n1. Use lápiz del número 2 o 2 1/2.\n2. Rellene el círculo.\n3. Borre bien para corregir.",
                  style: const pw.TextStyle(fontSize: 7.5), 
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                color: PdfColors.white,
                child: pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Column(children: [
                      pw.Text("CORRECTO",
                          style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      _construirBurbuja('a', isFilled: true),
                    ]),
                    pw.SizedBox(width: 12),
                    pw.Column(children: [
                      pw.Text("INCORRECTO",
                          style: pw.TextStyle(
                              fontSize: 6, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Row(children: [
                        _construirBurbujaMarca('b', 'x'),
                        pw.SizedBox(width: 2),
                        _construirBurbujaMarca('c', '/'),
                        pw.SizedBox(width: 2),
                        _construirBurbujaMarca('d', '-'),
                      ])
                    ]),
                  ],
                ),
              )
            ],
          ),
        ),
        pw.SizedBox(height: 6),
      ];

      // ── ALGORITMO TETRIS ─────────────────────────────────────────────────
      List<pw.Widget> leftColumnWidgets = [];
      List<pw.Widget> rightColumnWidgets = [];
      int leftHeightEstimation = 0;
      int rightHeightEstimation = 0;

      for (var materia in materias) {
        int count = materia.numeroPreguntas;
        int filas = count > 20 ? (count / 2).ceil() : count;

        final widgetMateria = pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8), 
          child: _construirBloqueMateria(materia),
        );

        if (leftHeightEstimation <= rightHeightEstimation) {
          leftColumnWidgets.add(widgetMateria);
          leftHeightEstimation += filas + 4;
        } else {
          rightColumnWidgets.add(widgetMateria);
          rightHeightEstimation += filas + 4;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(15), 
          build: (pw.Context context) {
            return [
              ...headerWidgets,
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Column(children: leftColumnWidgets),
                  pw.SizedBox(width: 15), 
                  pw.Column(children: rightColumnWidgets),
                ],
              )
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _construirBloqueMateria(Materia materia) {
    final int count = materia.numeroPreguntas;
    final bool requiereDivision = count > 20;

    return pw.Container(
      padding: const pw.EdgeInsets.all(5), 
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.ConstrainedBox(
            constraints: pw.BoxConstraints(maxWidth: requiereDivision ? 175 : 105),
            child: pw.Text(
              materia.nombre.toUpperCase(),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
          // 🔥 CAMBIA ESTO: De height: 4 a height: 15 (o 20)
          pw.SizedBox(height: 15),

          if (!requiereDivision)
            ...List.generate(count, (index) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: _construirFilaPregunta(index + 1),
              );
            })
          else
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  children: List.generate((count / 2).ceil(), (index) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: _construirFilaPregunta(index + 1),
                    );
                  }),
                ),
                pw.SizedBox(width: 8),
                pw.Column(
                  children: List.generate(count - (count / 2).ceil(), (index) {
                    final start = (count / 2).ceil();
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: _construirFilaPregunta(start + index + 1),
                    );
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _construirFilaPregunta(int numero) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          numero.toString().padLeft(2, '0'),
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(width: 3),
        _construirBurbuja('a'),
        pw.SizedBox(width: 2.5),
        _construirBurbuja('b'),
        pw.SizedBox(width: 2.5),
        _construirBurbuja('c'),
        pw.SizedBox(width: 2.5),
        _construirBurbuja('d'),
      ],
    );
  }

  pw.Widget _construirBurbuja(String texto, {bool isFilled = false}) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        color: isFilled ? PdfColors.black : PdfColors.white,
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Center(
        child: pw.Text(
          texto,
          style: pw.TextStyle(
            fontSize: 6,
            color: isFilled ? PdfColors.white : PdfColors.black,
          ),
        ),
      ),
    );
  }

  pw.Widget _construirBurbujaMarca(String letra, String marca) {
    return pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Center(
        child: pw.Text(
          marca,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
        ),
      ),
    );
  }
}

// ---------------------------------------------------
// 4. FUNCIÓN: Subir Examen al Servidor (AHORA DEVUELVE EL JSON)
// ---------------------------------------------------
Future<Map<String, dynamic>?> subirExamen(String imagePath, List<Materia> materias) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      // 🔥 IMPORTANTE: Cambia esta IP por la IP local de tu computadora (ej: 192.168.1.75) 
      // si estás probando desde un celular físico. Si usas el emulador de Android usa 10.0.2.2
      Uri.parse('http://192.168.1.73:8000/calificar'), 
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', imagePath),
    );

    String nombresMaterias = materias.map((m) => m.nombre).join(",");
    request.fields['lista_materias'] = nombresMaterias;

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      // 🔥 Convertimos el texto del servidor a un Mapa (JSON) de Dart
      Map<String, dynamic> jsonFormat = jsonDecode(responseData);
      
      // Dependiendo de cómo devuelva tu API el JSON. Si devuelve {"status": "success", "data": {...}}
      if (jsonFormat.containsKey('data')) {
        return jsonFormat['data'];
      }
      // Si la API devuelve directamente los resultados {...}
      return jsonFormat; 

    } else {
      print('Error al subir examen: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error en subirExamen: $e');
    return null;
  }
}