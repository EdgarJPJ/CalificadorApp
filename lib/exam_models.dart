String normalizarNombreMateria(String value) {
  return value.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

class Materia {
  String nombre;
  int numeroPreguntas;

  Materia({required String nombre, required this.numeroPreguntas})
    : nombre = normalizarNombreMateria(nombre);
}
