import 'package:url_launcher/url_launcher.dart';

import '../models/alumno_model.dart';
import '../models/materia_model.dart';
import '../utils/formato.dart';
import 'resumen_academico.dart';
import 'servicio_exception.dart';

/// Prepara el mensaje y abre WhatsApp con el chat del alumno.
/// La app NUNCA envía mensajes sola: el docente revisa y toca "Enviar".
class WhatsAppService {
  /// Mensaje propuesto. Si hay datos cargados, incluye el resumen individual
  /// (asistencia, promedio y evaluaciones a recuperar). Es lógica pura: no
  /// abre nada, por eso se prueba con pruebas unitarias.
  String mensajeInicial(AlumnoModel alumno, MateriaModel materia,
      [ResumenAcademico? resumen]) {
    final nombre = alumno.nombreCompleto.split(' ').first;
    final texto = StringBuffer('Hola $nombre! Te escribo por la materia '
        '${materia.nombre} (${materia.anio}° año).\n\n');

    if (resumen != null && !resumen.sinDatos) {
      texto.writeln('Tu situación hasta hoy:');
      final pct = resumen.porcentajeAsistencia;
      if (pct != null) {
        texto.writeln('• Asistencia: ${Formato.porcentaje(pct)} '
            '(${resumen.clasesAsistidas} de ${resumen.clasesComputables} clases)');
      }
      final promedio = resumen.promedio;
      if (promedio != null) {
        texto.writeln('• Promedio: ${Formato.nota(promedio)}');
      }
      final aRecuperar = resumen.aRecuperar;
      if (aRecuperar.isNotEmpty) {
        final lista = aRecuperar
            .map((n) => '${n.evaluacion} (${Formato.nota(n.notaFinal)})')
            .join(', ');
        texto.writeln('• A recuperar: $lista');
      } else if (resumen.notas.isNotEmpty) {
        texto.writeln('• Tenés todas las evaluaciones aprobadas.');
      }
      texto.writeln();
    }

    texto.write('Saludos,\nTu docente');
    return texto.toString();
  }

  Future<void> abrirChat(String telefonoNormalizado, String mensaje) async {
    // Uri.encodeComponent codifica espacios (%20), acentos y saltos de línea.
    final uri = Uri.parse(
        'https://wa.me/$telefonoNormalizado?text=${Uri.encodeComponent(mensaje)}');

    // Corrección respecto del tutorial: se usa externalApplication para que
    // abra la app de WhatsApp y no un navegador embebido, y se verifica el
    // resultado de launchUrl en lugar de depender solo de canLaunchUrl.
    bool abierto;
    try {
      abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      abierto = false; // p. ej. PlatformException si no hay app que lo abra
    }
    if (!abierto) {
      throw const ServicioException('No se pudo abrir WhatsApp');
    }
  }
}
