import 'package:hive_ce/hive_ce.dart';

import 'modelos.dart';

/// Armazenamento local com Hive: uma "caixa" com as contas consultadas e outra com a fila de pendentes.
/// No Android vira arquivos na pasta do app; no navegador, IndexedDB. Os dois sobrevivem a fechar o app.
class ArmazenamentoLocal {
  ArmazenamentoLocal._(this._contas, this._pendentes);

  final Box _contas;
  final Box _pendentes;

  /// Hive já inicializado (Hive.initFlutter() no app, Hive.init(pasta) nos testes).
  static Future<ArmazenamentoLocal> abrir() async =>
      ArmazenamentoLocal._(await Hive.openBox('contas'), await Hive.openBox('pendentes'));

  ContaLocal? conta(int id) {
    final m = _contas.get(id);
    return m == null ? null : ContaLocal.doMapa(m as Map);
  }

  Future<void> salvarConta(ContaLocal conta) => _contas.put(conta.id, conta.paraMapa());

  /// Em ordem de criação: é a ordem em que serão sincronizadas.
  List<OperacaoPendente> pendentes() =>
      _pendentes.values.map((m) => OperacaoPendente.doMapa(m as Map)).toList()
        ..sort((a, b) => a.criadaEm.compareTo(b.criadaEm));

  Future<void> salvarPendente(OperacaoPendente op) => _pendentes.put(op.chave, op.paraMapa());

  Future<void> removerPendente(String chave) => _pendentes.delete(chave);

  Future<void> limpar() async {
    await _contas.clear();
    await _pendentes.clear();
  }
}
