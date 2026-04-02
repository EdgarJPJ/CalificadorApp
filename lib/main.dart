import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'exam_models.dart';
import 'pdf/exam_pdf_generator.dart';

void main() {
  runApp(const CalificadorApp());
}

class CalificadorApp extends StatelessWidget {
  const CalificadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generador y Lector de Exámenes',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const FormularioExamenScreen(),
    );
  }
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
    Materia(nombre: "Ética Naturaleza y Sociedades", numeroPreguntas: 15),
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

  Future<void> _escanearExamen() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );

    if (photo == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final jpgPath = await convertirImagenAJpg(photo.path);
      final resultados = await subirExamen(jpgPath, materias);

      if (!mounted) return;
      Navigator.of(context).pop();
      _mostrarResultados(resultados);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

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
                final nombreMateria = materias[index].nombre;
                final respuestas =
                    (data[nombreMateria] as Map?)?.cast<String, dynamic>() ??
                    {};

                return ExpansionTile(
                  title: Text(
                    nombreMateria,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: respuestas.entries.map((entry) {
                    return ListTile(
                      dense: true,
                      title: Text(
                        "Pregunta ${entry.key}: Resp. ${entry.value}",
                      ),
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
            ),
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
                              decoration: const InputDecoration(
                                labelText: 'Materia',
                                helperText: 'No uses comas',
                              ),
                              onChanged: (value) {
                                materias[index].nombre =
                                    normalizarNombreMateria(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: materias[index].numeroPreguntas
                                  .toString(),
                              decoration: const InputDecoration(
                                labelText: 'Preguntas',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                materias[index].numeroPreguntas =
                                    int.tryParse(value) ?? 10;
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarMateria(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generarPDF(false),
                    icon: const Icon(Icons.person),
                    label: const Text(
                      "Generar Alumnos",
                      style: TextStyle(fontSize: 13),
                    ),
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
                    label: const Text(
                      "Clave Maestro",
                      style: TextStyle(fontSize: 13),
                    ),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _escanearExamen,
                icon: const Icon(Icons.camera_alt, size: 28),
                label: const Text(
                  "ESCANEAR Y CALIFICAR",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
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
  static const ExamPdfGenerator _generator = ExamPdfGenerator();

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
        title: Text(
          esClaveMaestro ? 'Clave del Maestro' : 'Exámenes de Alumnos',
        ),
        backgroundColor: esClaveMaestro ? Colors.deepPurple : Colors.green,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => _generator.buildDocument(
          materias: materias,
          esClaveMaestro: esClaveMaestro,
          nombresAlumnos: nombresAlumnos,
          pageFormat: format,
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>> subirExamen(
  String imagePath,
  List<Materia> materias,
) async {
  final uri = Uri.parse('http://192.168.1.73:8000/calificar');

  final request = http.MultipartRequest('POST', uri);

  request.fields['lista_materias'] = materias
      .map((m) => normalizarNombreMateria(m.nombre))
      .join(',');

  final file = File(imagePath);
  if (!await file.exists()) {
    throw Exception('La imagen no existe en la ruta: $imagePath');
  }

  final multipartFile = await http.MultipartFile.fromPath(
    'file',
    imagePath,
    filename: 'examen.jpg',
    contentType: MediaType('image', 'jpeg'),
  );

  request.files.add(multipartFile);

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  debugPrint('STATUS: ${response.statusCode}');
  debugPrint('BODY: ${response.body}');
  debugPrint('PATH ENVIADO: $imagePath');

  final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

  if (response.statusCode == 200) {
    if (body is Map<String, dynamic> && body['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(body['data']);
    }
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw Exception('Respuesta del servidor no válida');
  }

  if (body is Map<String, dynamic> && body['detail'] != null) {
    throw Exception(body['detail'].toString());
  }

  throw Exception('Error del servidor: ${response.statusCode}');
}

Future<String> convertirImagenAJpg(String originalPath) async {
  final tempDir = await getTemporaryDirectory();
  final targetPath =
      '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

  final result = await FlutterImageCompress.compressAndGetFile(
    originalPath,
    targetPath,
    format: CompressFormat.jpeg,
    quality: 90,
  );

  if (result == null) {
    throw Exception('No se pudo convertir la imagen a JPG');
  }

  debugPrint('ORIGINAL: $originalPath');
  debugPrint('CONVERTIDA: ${result.path}');

  return result.path;
}
