import 'package:flutter/material.dart';

import '../exam_models.dart';
import '../widgets/tarjeta_materia.dart';
import '../widgets/botones_accion.dart';
import '../utils/dialogos_examen.dart';
import '../scan/camera_screen.dart';
import 'pdf_preview_screen.dart';

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

    if (!mounted || resultados == null) return;

    try {
      DialogosExamen.mostrarResultados(context, materias, resultados);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    _alumnosController.dispose();
    super.dispose();
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
            
            // 🔥 LISTA DE MATERIAS DELEGADA AL WIDGET TarjetaMateria
            Expanded(
              child: ListView.builder(
                itemCount: materias.length,
                itemBuilder: (context, index) {
                  return TarjetaMateria(
                    materia: materias[index],
                    onEliminar: () => _eliminarMateria(index),
                    // Nota: Asumo que `normalizarNombreMateria` es una función global que tienes
                    onNombreChanged: (value) => materias[index].nombre = normalizarNombreMateria(value),
                    onPreguntasChanged: (value) => materias[index].numeroPreguntas = int.tryParse(value) ?? 10,
                  );
                },
              ),
            ),
            
            // 🔥 BOTONES DELEGADOS AL WIDGET BotonesAccion
            BotonesAccion(
              onGenerarAlumnos: () => _generarPDF(false),
              onGenerarMaestro: () => _generarPDF(true),
              onEscanear: _escanearExamen,
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