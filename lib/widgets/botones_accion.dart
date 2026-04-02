import 'package:flutter/material.dart';

class BotonesAccion extends StatelessWidget {
  final VoidCallback onGenerarAlumnos;
  final VoidCallback onGenerarMaestro;
  final VoidCallback onEscanear;

  const BotonesAccion({
    super.key,
    required this.onGenerarAlumnos,
    required this.onGenerarMaestro,
    required this.onEscanear,
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
                onPressed: onGenerarMaestro,
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onEscanear,
            icon: const Icon(Icons.camera_alt, size: 28),
            label: const Text("ESCANEAR Y CALIFICAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}