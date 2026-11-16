import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'config.dart';

/// O que o app sabe de uma agência na última rodada de consultas.
class StatusAgencia {
  const StatusAgencia({required this.noAr, required this.desde, this.liderAtual, this.latencia});

  final bool noAr;

  /// Líder em que esta agência acredita (null = sem líder, no meio de uma eleição).
  final int? liderAtual;
  final Duration? latencia;

  /// Desde quando a agência está nesse estado (no ar / fora do ar).
  final DateTime desde;
}

/// Um período de liderança visto pelo app. [fim] é null para a líder atual.
class PeriodoLideranca {
  PeriodoLideranca(this.lider, this.inicio, {this.jaEraLider = false});

  final int lider;
  final DateTime inicio;

  /// Primeira líder vista pelo app: ela já estava no cargo antes, então [inicio] é só quando o app viu.
  final bool jaEraLider;
  DateTime? fim;

  Duration duracao(DateTime agora) => (fim ?? agora).difference(inicio);
}

/// Consulta GET /bully/lider nas 3 agências em paralelo a cada [intervalo].
/// Daí saem a líder atual, quais agências estão no ar e o histórico de trocas de liderança.
class MonitorLideranca extends ChangeNotifier {
  MonitorLideranca(this._api, {this.intervalo = const Duration(seconds: 3), this.maxHistorico = 10});

  final Api _api;
  final Duration intervalo;
  final int maxHistorico;

  Timer? _timer;
  bool _consultando = false;
  int _preferida = 0;

  int? lider;

  /// Agência cuja resposta definiu a líder mostrada (a última que respondeu, se ainda estiver no ar).
  int? agenciaConsultada;
  bool eleicaoEmAndamento = false;
  DateTime? ultimaConsulta;
  final Map<int, StatusAgencia> status = {};

  /// Mais recente primeiro.
  final List<PeriodoLideranca> historico = [];

  bool get ativo => _timer != null;
  bool get nenhumaRespondeu => ultimaConsulta != null && agenciasNoAr == 0;
  int get agenciasNoAr => status.values.where((s) => s.noAr).length;
  Set<int> get foraDoAr => {for (final e in status.entries) if (!e.value.noAr) e.key};

  /// As agências que responderam não concordam sobre quem é a líder (acontece durante uma eleição).
  bool get divergencia =>
      status.values.where((s) => s.noAr && s.liderAtual != null).map((s) => s.liderAtual).toSet().length > 1;

  void iniciar() {
    if (_timer != null) return;
    consultar();
    _timer = Timer.periodic(intervalo, (_) => consultar());
  }

  /// Chamado quando o app vai para segundo plano: sem tela, não faz sentido gastar rede/bateria.
  void parar() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> consultar() async {
    if (_consultando) return; // a rodada anterior ainda está esperando timeouts
    _consultando = true;
    try {
      final respostas = await Future.wait([
        for (var i = 0; i < numeroAgencias; i++) _consultarUma(i),
      ]);
      final agora = DateTime.now();
      for (var i = 0; i < numeroAgencias; i++) {
        final (noAr, liderDela, latencia) = respostas[i];
        final anterior = status[i];
        status[i] = StatusAgencia(
          noAr: noAr,
          liderAtual: liderDela,
          latencia: latencia,
          desde: anterior != null && anterior.noAr == noAr ? anterior.desde : agora,
        );
      }
      ultimaConsulta = agora;

      // A líder mostrada vem da agência preferida; se ela caiu, da primeira que respondeu
      final ordem = [_preferida, for (var i = 0; i < numeroAgencias; i++) if (i != _preferida) i];
      final escolhida = ordem.where((i) => status[i]!.noAr).firstOrNull;
      agenciaConsultada = escolhida;
      if (escolhida != null) {
        _preferida = escolhida;
        final novoLider = status[escolhida]!.liderAtual;
        eleicaoEmAndamento = novoLider == null;
        if (novoLider != null && novoLider != lider) _trocarLider(novoLider, agora);
      }
      notifyListeners();
    } finally {
      _consultando = false;
    }
  }

  Future<(bool, int?, Duration?)> _consultarUma(int agencia) async {
    final cronometro = Stopwatch()..start();
    try {
      final r = await _api.consultarLider(agencia);
      return (true, r['liderAtual'] as int?, cronometro.elapsed);
    } on ErroApi {
      return (false, null, null);
    }
  }

  void _trocarLider(int novoLider, DateTime agora) {
    if (historico.isNotEmpty) historico.first.fim = agora;
    historico.insert(0, PeriodoLideranca(novoLider, agora, jaEraLider: lider == null));
    if (historico.length > maxHistorico) historico.removeLast();
    lider = novoLider;
  }

  @override
  void dispose() {
    parar();
    super.dispose();
  }
}
