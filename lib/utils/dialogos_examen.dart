import 'package:flutter/material.dart';
import '../exam_models.dart';

class DialogosExamen {
  static void mostrarResultados(BuildContext context, List<Materia> materias, Map<String, dynamic> data) {
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
                final respuestas = (data[nombreMateria] as Map?)?.cast<String, dynamic>() ?? {};

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
            ),
          ],
        );
      },
    );
  }
}