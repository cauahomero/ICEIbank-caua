import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'config.dart';

/// Consulta GET /bully/lider periodicamente. Se a agência consultada não responde,
/// tenta as outras na mesma rodada; a que respondeu vira a primeira da próxima.
class MonitorLideranca extends ChangeNotifier {
  MonitorLideranca(this._api, {this.intervalo = const Duration(seconds: 3)});

  final Api _api;
  final Duration intervalo;

  Timer? _timer;
  bool _consultando = false;
  int _preferida = 0;

  int? lider;
  int? agenciaConsultada;
  bool eleicaoEmAndamento = false;
  bool nenhumaRespondeu = false;
  Set<int> foraDoAr = {};
  DateTime? ultimaConsulta;
  int? liderAnterior;
  DateTime? mudouEm;

  bool get ativo => _timer != null;

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
      final ordem = [_preferida, for (var i = 0; i < numeroAgencias; i++) if (i != _preferida) i];
      final falharam = <int>{};
      for (final agencia in ordem) {
        try {
          final r = await _api.consultarLider(agencia);
          _registrar(agencia, r['liderAtual'] as int?, falharam);
          return;
        } on ErroApi {
          falharam.add(agencia);
        }
      }
      nenhumaRespondeu = true;
      foraDoAr = falharam;
      ultimaConsulta = DateTime.now();
      notifyListeners();
    } finally {
      _consultando = false;
    }
  }

  void _registrar(int agencia, int? novoLider, Set<int> falharam) {
    _preferida = agencia;
    agenciaConsultada = agencia;
    nenhumaRespondeu = false;
    foraDoAr = falharam;
    ultimaConsulta = DateTime.now();
    // null = a agência esqueceu a líder antiga e está no meio de uma eleição
    eleicaoEmAndamento = novoLider == null;
    if (novoLider != null && novoLider != lider) {
      if (lider != null) {
        liderAnterior = lider;
        mudouEm = DateTime.now();
      }
      lider = novoLider;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    parar();
    super.dispose();
  }
}
