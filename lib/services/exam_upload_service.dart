import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../exam_models.dart';

class ExamUploadService {
  const ExamUploadService._();

  static const String _baseUrl = 'http://192.168.1.73:8000';

  static Future<Map<String, dynamic>> processExamImage({
    required String imagePath,
    required List<Materia> materias,
  }) async {
    final normalizedImagePath = await normalizeCapturedImage(imagePath);
    final uri = Uri.parse('$_baseUrl/process_exam_image');
    final request = http.MultipartRequest('POST', uri);

    request.fields['lista_materias'] = materias
        .map((m) => normalizarNombreMateria(m.nombre))
        .join(',');

    final file = File(normalizedImagePath);
    if (!await file.exists()) {
      throw Exception('La imagen no existe en la ruta: $normalizedImagePath');
    }

    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      normalizedImagePath,
      filename: 'examen.jpg',
      contentType: MediaType('image', 'jpeg'),
    );

    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('STATUS: ${response.statusCode}');
    debugPrint('BODY: ${response.body}');
    debugPrint('PATH ENVIADO: $normalizedImagePath');

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode == 200) {
      if (body is Map<String, dynamic> &&
          body['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(body['data']);
      }
      if (body is Map<String, dynamic>) {
        return body;
      }
      throw Exception('Respuesta del servidor no válida');
    }

    if (body is Map<String, dynamic> && body['detail'] != null) {
      throw Exception(body['detail'].toString());
    }

    throw Exception('Error del servidor: ${response.statusCode}');
  }

  static Future<String> normalizeCapturedImage(String originalPath) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      originalPath,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 92,
    );

    if (result == null) {
      throw Exception('No se pudo convertir la imagen a JPG');
    }

    debugPrint('ORIGINAL: $originalPath');
    debugPrint('CONVERTIDA: ${result.path}');

    return result.path;
  }
}
