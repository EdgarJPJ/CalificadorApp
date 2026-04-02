import 'package:flutter/material.dart';
import 'screens/formulario_examen_screen.dart';

void main() {
  runApp(const CalificadorApp());
}

class CalificadorApp extends StatelessWidget {
  const CalificadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generador y Lector de Exámenes',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FormularioExamenScreen(),
    );
  }
}