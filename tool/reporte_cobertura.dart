import 'dart:io';

class EstadisticasArchivo {
  final String ruta;
  int lineasTotales = 0;
  int lineasEjecutadas = 0;
  final List<int> noCubiertas = [];

  EstadisticasArchivo(this.ruta);

  double get porcentaje =>
      lineasTotales == 0 ? 100.0 : (lineasEjecutadas / lineasTotales) * 100.0;

  String get rangoNoCubiertas {
    if (noCubiertas.isEmpty) return '';
    if (noCubiertas.length > 8) {
      final primeros = _agruparRangos(noCubiertas.take(8).toList());
      return '$primeros... (+${noCubiertas.length - 8} más)';
    }
    return _agruparRangos(noCubiertas);
  }

  static String _agruparRangos(List<int> lineas) {
    if (lineas.isEmpty) return '';
    final rangos = <String>[];
    int inicio = lineas.first;
    int previo = inicio;

    for (int i = 1; i < lineas.length; i++) {
      final actual = lineas[i];
      if (actual == previo + 1) {
        previo = actual;
      } else {
        rangos.add(inicio == previo ? '$inicio' : '$inicio-$previo');
        inicio = actual;
        previo = actual;
      }
    }
    rangos.add(inicio == previo ? '$inicio' : '$inicio-$previo');
    return rangos.join(', ');
  }
}

void main(List<String> args) {
  final rutaLcov = args.isNotEmpty ? args.first : 'coverage/lcov.info';
  final archivoLcov = File(rutaLcov);

  if (!archivoLcov.existsSync()) {
    stderr.writeln('Error: No se encontró el archivo de cobertura en "$rutaLcov".');
    stderr.writeln('Ejecuta primero: flutter test --coverage');
    exit(1);
  }

  final lineas = archivoLcov.readAsLinesSync();
  final archivos = <String, EstadisticasArchivo>{};
  EstadisticasArchivo? actual;

  for (final linea in lineas) {
    if (linea.startsWith('SF:')) {
      final ruta = linea.substring(3).trim();
      actual = archivos.putIfAbsent(ruta, () => EstadisticasArchivo(ruta));
    } else if (linea.startsWith('DA:') && actual != null) {
      final partes = linea.substring(3).split(',');
      if (partes.length >= 2) {
        final numeroLinea = int.tryParse(partes[0]) ?? 0;
        final ejecuciones = int.tryParse(partes[1]) ?? 0;
        actual.lineasTotales++;
        if (ejecuciones > 0) {
          actual.lineasEjecutadas++;
        } else {
          actual.noCubiertas.add(numeroLinea);
        }
      }
    } else if (linea == 'end_of_record') {
      actual = null;
    }
  }

  if (archivos.isEmpty) {
    stdout.writeln('No se encontraron registros de cobertura en "$rutaLcov".');
    return;
  }

  final listaArchivos = archivos.values.toList()
    ..sort((a, b) => a.ruta.compareTo(b.ruta));

  int granTotalLineas = 0;
  int granTotalEjecutadas = 0;

  for (final a in listaArchivos) {
    granTotalLineas += a.lineasTotales;
    granTotalEjecutadas += a.lineasEjecutadas;
  }

  final granPorcentaje = granTotalLineas == 0
      ? 100.0
      : (granTotalEjecutadas / granTotalLineas) * 100.0;

  // Imprimir tabla estilo Jest / Vitest (pnpm test --coverage) en consola
  _imprimirConsola(listaArchivos, granPorcentaje, granTotalEjecutadas, granTotalLineas);

  // Escribir en GitHub Step Summary si la variable de entorno está presente
  _escribirGitHubStepSummary(listaArchivos, granPorcentaje, granTotalEjecutadas, granTotalLineas);
}

void _imprimirConsola(
  List<EstadisticasArchivo> archivos,
  double totalPct,
  int totalHit,
  int totalLines,
) {
  const colFileWidth = 48;
  const colPctWidth = 10;
  const colLinesWidth = 14;
  const colUncoveredWidth = 26;

  final sepLinea = '-' * (colFileWidth + colPctWidth + colLinesWidth + colUncoveredWidth + 9);

  stdout.writeln('\n$sepLinea');
  stdout.writeln(
    '${_padR('File', colFileWidth)} | '
    '${_padL('% Lines', colPctWidth)} | '
    '${_padL('Lines Hit/Tot', colLinesWidth)} | '
    '${_padR('Uncovered Line #s', colUncoveredWidth)}',
  );
  stdout.writeln(sepLinea);

  for (final a in archivos) {
    final rutaCorta = a.ruta.startsWith('lib/') ? a.ruta : a.ruta;
    final rutaRecortada = rutaCorta.length > colFileWidth
        ? '...${rutaCorta.substring(rutaCorta.length - colFileWidth + 3)}'
        : rutaCorta;

    stdout.writeln(
      '${_padR(rutaRecortada, colFileWidth)} | '
      '${_padL('${a.porcentaje.toStringAsFixed(2)} %', colPctWidth)} | '
      '${_padL('${a.lineasEjecutadas}/${a.lineasTotales}', colLinesWidth)} | '
      '${_padR(a.rangoNoCubiertas, colUncoveredWidth)}',
    );
  }

  stdout.writeln(sepLinea);
  stdout.writeln(
    '${_padR('All files', colFileWidth)} | '
    '${_padL('${totalPct.toStringAsFixed(2)} %', colPctWidth)} | '
    '${_padL('$totalHit/$totalLines', colLinesWidth)} | '
    '${_padR('', colUncoveredWidth)}',
  );
  stdout.writeln('$sepLinea\n');
}

void _escribirGitHubStepSummary(
  List<EstadisticasArchivo> archivos,
  double totalPct,
  int totalHit,
  int totalLines,
) {
  final rutaSummary = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (rutaSummary == null || rutaSummary.trim().isEmpty) return;

  final buffer = StringBuffer();
  final emoji = totalPct >= 80.0 ? '🟢' : (totalPct >= 60.0 ? '🟡' : '🔴');

  buffer.writeln('## 📊 Reporte de Cobertura de Código Flutter');
  buffer.writeln();
  buffer.writeln(
    '> $emoji **Cobertura Total:** `${totalPct.toStringAsFixed(2)} %` '
    '($totalHit de $totalLines líneas ejecutadas)',
  );
  buffer.writeln();
  buffer.writeln('| Archivo | % Cobertura | Líneas Cubiertas / Totales | Líneas no cubiertas |');
  buffer.writeln('| :--- | :---: | :---: | :--- |');

  for (final a in archivos) {
    final estadoEmoji = a.porcentaje >= 80.0 ? '🟢' : (a.porcentaje >= 50.0 ? '🟡' : '🔴');
    final noCub = a.rangoNoCubiertas.isEmpty ? '-' : '`${a.rangoNoCubiertas}`';
    buffer.writeln(
      '| `${a.ruta}` | $estadoEmoji ${a.porcentaje.toStringAsFixed(2)}% | '
      '${a.lineasEjecutadas} / ${a.lineasTotales} | $noCub |',
    );
  }

  buffer.writeln(
    '| **Total Global** | **$emoji ${totalPct.toStringAsFixed(2)}%** | '
    '**$totalHit / $totalLines** | - |',
  );
  buffer.writeln();

  try {
    File(rutaSummary).writeAsStringSync(buffer.toString(), mode: FileMode.append);
  } catch (e) {
    stderr.writeln('Advertencia: No se pudo escribir en GITHUB_STEP_SUMMARY: $e');
  }
}

String _padR(String texto, int ancho) {
  if (texto.length >= ancho) return texto.substring(0, ancho);
  return texto + ' ' * (ancho - texto.length);
}

String _padL(String texto, int ancho) {
  if (texto.length >= ancho) return texto.substring(0, ancho);
  return ' ' * (ancho - texto.length) + texto;
}
