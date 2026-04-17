import 'package:flutter/material.dart';

import '../exam_models.dart';
import '../scan/camera_screen.dart';
import '../utils/dialogos_examen.dart';
import '../widgets/botones_accion.dart';
import '../widgets/tarjeta_materia.dart';
import 'pdf_preview_screen.dart';

class FormularioExamenScreen extends StatefulWidget {
  const FormularioExamenScreen({super.key});

  @override
  State<FormularioExamenScreen> createState() => _FormularioExamenScreenState();
}

class _FormularioExamenScreenState extends State<FormularioExamenScreen> {
  final TextEditingController _alumnosController = TextEditingController();
  bool _claveMaestroCargada = false;

  List<Materia> materias = [
    Materia(nombre: 'Lenguajes', numeroPreguntas: 20),
    Materia(nombre: 'Saberes y Pensamiento Cientifico', numeroPreguntas: 30),
    Materia(nombre: 'Etica Naturaleza y Sociedades', numeroPreguntas: 15),
    Materia(nombre: 'De lo Humano y lo Comunitario', numeroPreguntas: 25),
  ];

  void _agregarMateria() {
    setState(() {
      materias.add(Materia(nombre: 'Nueva Materia', numeroPreguntas: 10));
    });
  }

  void _eliminarMateria(int index) {
    setState(() {
      materias.removeAt(index);
      _claveMaestroCargada = false;
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

  Future<void> _subirClaveMaestro() async {
    final resultados = await _abrirCamara(ScanUploadMode.uploadKey);

    if (!mounted || resultados == null) return;

    setState(() {
      _claveMaestroCargada = true;
    });
    DialogosExamen.mostrarClaveCargada(context, resultados);
  }

  Future<void> _escanearAlumno() async {
    if (!_claveMaestroCargada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero sube la clave del maestro.'),
        ),
      );
      return;
    }

    final resultados = await _abrirCamara(ScanUploadMode.gradeExam);

    if (!mounted || resultados == null) return;

    try {
      DialogosExamen.mostrarCalificacion(context, resultados);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<Map<String, dynamic>?> _abrirCamara(ScanUploadMode mode) {
    return Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(materias: materias, mode: mode),
      ),
    );
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
                hintText: 'Ej. Juan Perez, Ana Gomez, Luis Diaz...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 15),
            _EstadoClaveBanner(claveMaestroCargada: _claveMaestroCargada),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: materias.length,
                itemBuilder: (context, index) {
                  return TarjetaMateria(
                    materia: materias[index],
                    onEliminar: () => _eliminarMateria(index),
                    onNombreChanged: (value) {
                      materias[index].nombre = normalizarNombreMateria(value);
                      if (_claveMaestroCargada) {
                        setState(() {
                          _claveMaestroCargada = false;
                        });
                      }
                    },
                    onPreguntasChanged: (value) {
                      materias[index].numeroPreguntas =
                          int.tryParse(value) ?? 10;
                    },
                  );
                },
              ),
            ),
            BotonesAccion(
              onGenerarAlumnos: () => _generarPDF(false),
              onGenerarMaestro: () => _generarPDF(true),
              onSubirClave: _subirClaveMaestro,
              onEscanearAlumno: _escanearAlumno,
              claveMaestroCargada: _claveMaestroCargada,
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

class _EstadoClaveBanner extends StatelessWidget {
  const _EstadoClaveBanner({required this.claveMaestroCargada});

  final bool claveMaestroCargada;

  @override
  Widget build(BuildContext context) {
    final color = claveMaestroCargada ? Colors.green : Colors.orange;
    final icon = claveMaestroCargada ? Icons.check_circle : Icons.info_outline;
    final text = claveMaestroCargada
        ? 'Clave del maestro cargada en el backend.'
        : 'Sube la clave del maestro antes de escanear alumnos.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
