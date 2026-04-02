import 'dart:math' as math;
import '../exam_models.dart';
import 'constantes_examen.dart';

class MetricasTitulo {
  const MetricasTitulo({
    required this.anchoUnaLinea,
    required this.anchoDosLineas,
  });

  final double anchoUnaLinea;
  final double anchoDosLineas;

  factory MetricasTitulo.desdeTitulo(String titulo) {
    final normalizado = titulo.trim().replaceAll(RegExp(r'\s+'), ' ');
    final anchoBase =
        normalizado.length *
        ConstantesExamen.tamanoFuenteTitulo *
        ConstantesExamen.factorAnchoCaracterTitulo;
    final palabras = normalizado.isEmpty ? const <String>[] : normalizado.split(' ');
    final caracteresPalabraMasLarga = palabras.fold<int>(
      0,
      (actual, palabra) => palabra.length > actual ? palabra.length : actual,
    );
    final anchoPalabraMasLarga =
        caracteresPalabraMasLarga *
        ConstantesExamen.tamanoFuenteTitulo *
        ConstantesExamen.factorAnchoCaracterTitulo;
    final mitadAncho = anchoBase / 2;

    return MetricasTitulo(
      anchoUnaLinea: anchoBase + 12,
      anchoDosLineas: math.max(anchoPalabraMasLarga, mitadAncho) + 10,
    );
  }
}

class BloqueMateria {
  BloqueMateria({
    required this.materia,
    required this.anchoBloque,
    required this.columnasAbarcadas,
    required this.alturaTitulo,
    required this.alturaEstimada,
    required this.divididoInternamente,
    required this.preguntasIzquierda,
    required this.preguntasDerecha,
  });

  final Materia materia;
  final double anchoBloque;
  final int columnasAbarcadas;
  final double alturaTitulo;
  final double alturaEstimada;
  final bool divididoInternamente;
  final List<int> preguntasIzquierda;
  final List<int> preguntasDerecha;

  factory BloqueMateria.desdeMateria({
    required Materia materia,
    required double anchoPagina,
    required int cantidadColumnas,
  }) {
    final dividido = materia.numeroPreguntas > 20;
    final cantidadIzquierda = dividido
        ? (materia.numeroPreguntas / 2).ceil()
        : materia.numeroPreguntas;
    final cantidadDerecha = dividido ? materia.numeroPreguntas - cantidadIzquierda : 0;

    final preguntasIzquierda = List<int>.generate(cantidadIzquierda, (index) => index + 1);
    final preguntasDerecha = List<int>.generate(
      cantidadDerecha,
      (index) => cantidadIzquierda + index + 1,
    );

    final anchoContenido = _calcularAnchoContenido(dividido);
    final metricasTitulo = MetricasTitulo.desdeTitulo(materia.nombre);

    double anchoMinimoTitulo = metricasTitulo.anchoDosLineas;
    if (metricasTitulo.anchoUnaLinea <= anchoContenido) {
      anchoMinimoTitulo = metricasTitulo.anchoUnaLinea;
    }

    final anchoDeseadoBloque = math.max(anchoContenido, anchoMinimoTitulo) +
        (ConstantesExamen.paddingBloque * 2);

    final columnasAbarcadas = _resolverColumnasAbarcadas(
      anchoDeseado: anchoDeseadoBloque,
      anchoPagina: anchoPagina,
      cantidadColumnas: cantidadColumnas,
    );
    final anchoMaximoBloque = _anchoPorColumnas(
      anchoPagina: anchoPagina,
      cantidadColumnas: cantidadColumnas,
      abarcadas: columnasAbarcadas,
    );
    final anchoFinal = math.min(anchoDeseadoBloque, anchoMaximoBloque);

    final filasVisibles = dividido ? cantidadIzquierda : materia.numeroPreguntas;
    final alturaEstimada = (ConstantesExamen.paddingBloque * 2) +
        ConstantesExamen.alturaTituloDobleLinea +
        ConstantesExamen.margenInferiorTitulo +
        (filasVisibles * ConstantesExamen.alturaFilaPregunta) +
        2;

    return BloqueMateria(
      materia: materia,
      anchoBloque: anchoFinal,
      columnasAbarcadas: columnasAbarcadas,
      alturaTitulo: ConstantesExamen.alturaTituloDobleLinea,
      alturaEstimada: alturaEstimada,
      divididoInternamente: dividido,
      preguntasIzquierda: preguntasIzquierda,
      preguntasDerecha: preguntasDerecha,
    );
  }

  static double _calcularAnchoContenido(bool dividido) {
    final anchoColumnaPregunta = ConstantesExamen.anchoNumeroPregunta +
        ConstantesExamen.separacionEtiquetaPregunta +
        (ConstantesExamen.tamanoBurbuja * 4) +
        (ConstantesExamen.separacionBurbuja * 3);

    if (dividido) {
      return (anchoColumnaPregunta * 2) + ConstantesExamen.separacionFilasColumnas;
    }

    return anchoColumnaPregunta + ConstantesExamen.margenSeguridadColumnaUnica;
  }

  static int _resolverColumnasAbarcadas({
    required double anchoDeseado,
    required double anchoPagina,
    required int cantidadColumnas,
  }) {
    for (var abarcadas = 1; abarcadas <= cantidadColumnas; abarcadas++) {
      final anchoMaximo = _anchoPorColumnas(
        anchoPagina: anchoPagina,
        cantidadColumnas: cantidadColumnas,
        abarcadas: abarcadas,
      );
      if (anchoDeseado <= anchoMaximo) {
        return abarcadas;
      }
    }
    return cantidadColumnas;
  }

  static double _anchoPorColumnas({
    required double anchoPagina,
    required int cantidadColumnas,
    required int abarcadas,
  }) {
    final anchoColumna = (anchoPagina -
            (ConstantesExamen.separacionColumnas * (cantidadColumnas - 1))) /
        cantidadColumnas;
    return (anchoColumna * abarcadas) +
        (ConstantesExamen.separacionColumnas * (abarcadas - 1));
  }
}

class BloqueUbicado {
  const BloqueUbicado({
    required this.bloque,
    required this.columnaInicio,
    required this.izquierda,
    required this.arriba,
  });

  final BloqueMateria bloque;
  final int columnaInicio;
  final double izquierda;
  final double arriba;
}

class CandidatoUbicacion {
  const CandidatoUbicacion({
    required this.columnaInicio,
    required this.izquierda,
    required this.arriba,
  });

  final int columnaInicio;
  final double izquierda;
  final double arriba;
}

class DisenoPagina {
  DisenoPagina({required this.anchoPagina, required this.cantidadColumnas})
      : alturasColumnas = List<double>.filled(cantidadColumnas, 0);

  final double anchoPagina;
  final int cantidadColumnas;
  final List<BloqueUbicado> bloques = [];
  final List<double> alturasColumnas;

  double alturaContenido = 0;

  bool get estaVacia => bloques.isEmpty;

  double get maximoDerecha {
    double max = 0.0;
    for (final b in bloques) {
      final bordeDerecho = b.izquierda + b.bloque.anchoBloque;
      if (bordeDerecho > max) {
        max = bordeDerecho;
      }
    }
    return max;
  }

  CandidatoUbicacion buscarUbicacion(BloqueMateria bloque) {
    final maxInicio = cantidadColumnas - bloque.columnasAbarcadas;
    var mejorInicio = 0;
    var mejorArriba = double.infinity;
    var mejorBrechaSoporte = double.infinity;
    var mejorFondoFuturo = double.infinity;
    var mejorHolguraReservada = double.infinity;

    for (var inicio = 0; inicio <= maxInicio; inicio++) {
      var arriba = 0.0;
      var minAlturaCubierta = double.infinity;
      
      for (var columna = inicio; columna < inicio + bloque.columnasAbarcadas; columna++) {
        if (alturasColumnas[columna] > arriba) {
          arriba = alturasColumnas[columna];
        }
        if (alturasColumnas[columna] < minAlturaCubierta) {
          minAlturaCubierta = alturasColumnas[columna];
        }
      }

      final brechaSoporte = arriba - minAlturaCubierta;
      final fondoFuturo = arriba + bloque.alturaEstimada;
      final holguraReservada =
          _anchoReservado(bloque.columnasAbarcadas) - bloque.anchoBloque;

      final esMejor = arriba < mejorArriba ||
          (arriba == mejorArriba && brechaSoporte < mejorBrechaSoporte) ||
          (arriba == mejorArriba &&
              brechaSoporte == mejorBrechaSoporte &&
              fondoFuturo < mejorFondoFuturo) ||
          (arriba == mejorArriba &&
              brechaSoporte == mejorBrechaSoporte &&
              fondoFuturo == mejorFondoFuturo &&
              holguraReservada < mejorHolguraReservada) ||
          (arriba == mejorArriba &&
              brechaSoporte == mejorBrechaSoporte &&
              fondoFuturo == mejorFondoFuturo &&
              holguraReservada == mejorHolguraReservada &&
              inicio < mejorInicio);

      if (esMejor) {
        mejorArriba = arriba;
        mejorInicio = inicio;
        mejorBrechaSoporte = brechaSoporte;
        mejorFondoFuturo = fondoFuturo;
        mejorHolguraReservada = holguraReservada;
      }
    }

    return CandidatoUbicacion(
      columnaInicio: mejorInicio,
      izquierda: _izquierdaParaColumna(mejorInicio),
      arriba: mejorArriba,
    );
  }

  void agregarBloque(BloqueMateria bloque, CandidatoUbicacion ubicacion) {
    final anchoAsignado = _anchoReservado(bloque.columnasAbarcadas);
    final espacioExtra = anchoAsignado - bloque.anchoBloque;
    final izquierdaCentrada = ubicacion.izquierda + (espacioExtra / 2);

    bloques.add(
      BloqueUbicado(
        bloque: bloque,
        columnaInicio: ubicacion.columnaInicio,
        izquierda: izquierdaCentrada,
        arriba: ubicacion.arriba,
      ),
    );

    final limiteInferior = ubicacion.arriba +
        bloque.alturaEstimada +
        ConstantesExamen.espacioEntreBloques;
        
    for (var col = ubicacion.columnaInicio; col < ubicacion.columnaInicio + bloque.columnasAbarcadas; col++) {
      alturasColumnas[col] = limiteInferior;
    }

    final fondoReal = ubicacion.arriba + bloque.alturaEstimada;
    if (fondoReal > alturaContenido) {
      alturaContenido = fondoReal;
    }
  }

  double _izquierdaParaColumna(int indice) {
    final anchoColumna = (anchoPagina -
            (ConstantesExamen.separacionColumnas * (cantidadColumnas - 1))) /
        cantidadColumnas;
    return indice * (anchoColumna + ConstantesExamen.separacionColumnas);
  }

  double _anchoReservado(int abarcadas) {
    final anchoColumna = (anchoPagina -
            (ConstantesExamen.separacionColumnas * (cantidadColumnas - 1))) /
        cantidadColumnas;
    return (anchoColumna * abarcadas) +
        (ConstantesExamen.separacionColumnas * (abarcadas - 1));
  }
}