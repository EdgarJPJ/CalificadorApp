import 'package:flutter/material.dart';

class BotonesAccion extends StatelessWidget {
  final VoidCallback onGenerarAlumnos;
  final VoidCallback onGenerarMaestro;
  final VoidCallback onSubirClave;
  final VoidCallback onEscanearAlumno;
  final bool claveMaestroCargada;

  const BotonesAccion({
    super.key,
    required this.onGenerarAlumnos,
    required this.onGenerarMaestro,
    required this.onSubirClave,
    required this.onEscanearAlumno,
    required this.claveMaestroCargada,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onGenerarAlumnos,
                icon: const Icon(Icons.person),
                label: const Text(
                  'Generar Alumnos',
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
                onPressed: onGenerarMaestro,
                icon: const Icon(Icons.school),
                label: const Text(
                  'Clave Maestro',
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
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSubirClave,
                icon: const Icon(Icons.upload_file),
                label: const Text(
                  'SUBIR CLAVE',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onEscanearAlumno,
                icon: Icon(
                  claveMaestroCargada ? Icons.camera_alt : Icons.lock_outline,
                ),
                label: const Text(
                  'ESCANEAR ALUMNO',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
      ],
    );
  }
}
