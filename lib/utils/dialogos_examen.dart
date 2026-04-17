import 'package:flutter/material.dart';

class DialogosExamen {
  static void mostrarClaveCargada(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final mensaje = _pickValue(data, const ['mensaje', 'message'])?.toString();
    final materias = _pickValue(data, const [
      'materias_usadas',
      'materias usadas',
      'materias',
      'subjects',
    ]);
    final respuestas = _pickValue(data, const [
      'respuestas_detectadas',
      'respuestas detectadas',
      'answer_key',
      'clave',
    ]);

    _showScrollableDialog(
      context: context,
      title: 'Clave maestro cargada',
      children: [
        if (mensaje != null && mensaje.isNotEmpty)
          _InfoTile(
            icon: Icons.check_circle,
            color: Colors.green,
            title: mensaje,
          ),
        _Section(title: 'Materias usadas', value: materias),
        _Section(title: 'Respuestas detectadas', value: respuestas),
        if (mensaje == null && materias == null && respuestas == null)
          _Section(title: 'Respuesta del servidor', value: data),
      ],
    );
  }

  static void mostrarCalificacion(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final alumno = _pickValue(data, const [
      'alumno',
      'nombre_alumno',
      'nombre alumno',
      'student_name',
    ]);
    final calificacion = _pickValue(data, const [
      'calificacion_total',
      'calificación_total',
      'calificacion total',
      'calificación total',
      'calificacion',
      'calificación',
    ]);
    final aciertos = _pickValue(data, const [
      'aciertos_totales',
      'aciertos totales',
      'aciertos',
    ]);
    final incorrectas = _pickValue(data, const [
      'incorrectas_totales',
      'incorrectas totales',
      'incorrectas',
      'errores',
    ]);
    final resultadosPorMateria = _pickValue(data, const [
      'resultados_por_materia',
      'resultados por materia',
      'materias',
      'resultados',
    ]);
    final detalle = _pickValue(data, const [
      'detalle_pregunta_por_pregunta',
      'detalle pregunta por pregunta',
      'detalle',
    ]);
    final respuestasAlumno = _pickValue(data, const [
      'respuestas_detectadas_alumno',
      'respuestas detectadas alumno',
      'respuestas_detectadas',
      'respuestas alumno',
    ]);

    _showScrollableDialog(
      context: context,
      title: 'Resultados del examen',
      children: [
        _SummaryCard(
          alumno: alumno?.toString(),
          calificacion: calificacion,
          aciertos: aciertos,
          incorrectas: incorrectas,
        ),
        _Section(title: 'Resultados por materia', value: resultadosPorMateria),
        _Section(title: 'Detalle pregunta por pregunta', value: detalle),
        _Section(title: 'Respuestas detectadas del alumno', value: respuestasAlumno),
        if (calificacion == null &&
            aciertos == null &&
            incorrectas == null &&
            resultadosPorMateria == null &&
            detalle == null &&
            respuestasAlumno == null)
          _Section(title: 'Respuesta del servidor', value: data),
      ],
    );
  }

  static Object? _pickValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key)) return data[key];
    }

    final normalizedTargets = keys.map(_normalizeKey).toSet();
    for (final entry in data.entries) {
      if (normalizedTargets.contains(_normalizeKey(entry.key))) {
        return entry.value;
      }
    }

    return null;
  }

  static String _normalizeKey(String key) {
    return key
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[\s-]+'), '_');
  }

  static void _showScrollableDialog({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: children,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.alumno,
    required this.calificacion,
    required this.aciertos,
    required this.incorrectas,
  });

  final String? alumno;
  final Object? calificacion;
  final Object? aciertos;
  final Object? incorrectas;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueAccent.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alumno != null && alumno!.isNotEmpty)
              _ResultLine(label: 'Alumno', value: alumno!),
            _ResultLine(
              label: 'Calificacion',
              value: calificacion?.toString() ?? 'No disponible',
            ),
            _ResultLine(
              label: 'Aciertos',
              value: aciertos?.toString() ?? 'No disponible',
            ),
            _ResultLine(
              label: 'Incorrectas',
              value: incorrectas?.toString() ?? 'No disponible',
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.value});

  final String title;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: _buildValueWidgets(value),
    );
  }

  List<Widget> _buildValueWidgets(Object? value) {
    if (value is Map) {
      if (value.isEmpty) {
        return const [ListTile(dense: true, title: Text('Sin datos'))];
      }
      return value.entries.map((entry) {
        return ListTile(
          dense: true,
          title: Text(entry.key.toString()),
          subtitle: Text(_formatValue(entry.value)),
        );
      }).toList();
    }

    if (value is Iterable) {
      final items = value.toList();
      if (items.isEmpty) {
        return const [ListTile(dense: true, title: Text('Sin datos'))];
      }
      return items.map((item) {
        return ListTile(
          dense: true,
          title: Text(_formatValue(item)),
        );
      }).toList();
    }

    return [
      ListTile(
        dense: true,
        title: Text(_formatValue(value)),
      ),
    ];
  }

  String _formatValue(Object? value) {
    if (value == null) return 'N/A';
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${_formatValue(entry.value)}')
          .join('\n');
    }
    if (value is Iterable) {
      return value.map(_formatValue).join(', ');
    }
    return value.toString();
  }
}
