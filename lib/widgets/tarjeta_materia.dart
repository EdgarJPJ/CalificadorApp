import 'package:flutter/material.dart';
import '../exam_models.dart';

class TarjetaMateria extends StatelessWidget {
  final Materia materia;
  final VoidCallback onEliminar;
  final ValueChanged<String> onNombreChanged;
  final ValueChanged<String> onPreguntasChanged;

  const TarjetaMateria({
    super.key,
    required this.materia,
    required this.onEliminar,
    required this.onNombreChanged,
    required this.onPreguntasChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                initialValue: materia.nombre,
                decoration: const InputDecoration(
                  labelText: 'Materia',
                  helperText: 'No uses comas',
                ),
                onChanged: onNombreChanged,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: materia.numeroPreguntas.toString(),
                decoration: const InputDecoration(labelText: 'Preguntas'),
                keyboardType: TextInputType.number,
                onChanged: onPreguntasChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onEliminar,
            ),
          ],
        ),
      ),
    );
  }
}