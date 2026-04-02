import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'exam_models.dart';
import 'pdf/exam_pdf_generator.dart';
import 'scan/camera_screen.dart';

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
    final resultados = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => CameraScreen(materias: materias)),
    );

    if (!mounted || resultados == null) {
      return;
    }

    try {
      _mostrarResultados(resultados);
    } catch (e) {
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
