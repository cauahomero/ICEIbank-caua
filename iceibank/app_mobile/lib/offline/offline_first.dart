import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../api.dart';
import '../config.dart';
import '../sessao.dart';
import 'armazenamento.dart';
import 'modelos.dart';

/// Resultado de uma consulta de saldo: da agência (online) ou da cópia local (offline).
class SaldoConsultado {
  SaldoConsultado(this.conta, {required this.offline, required this.pendentes, required this.saldoProvisorio});

  final ContaLocal conta;
  final bool offline;

  /// Operações desta conta ainda na fila (status pendente).
  final int pendentes;
  final double saldoProvisorio;
}

/// Resultado de um depósito/saque: aplicado na hora ou guardado na fila.
class OperacaoRealizada {
  OperacaoRealizada({required this.pendente, required this.saldo});

  final bool pendente;

  /// Saldo novo (online) ou saldo provisório (com a operação na fila).
  final double saldo;
}

/// Coordena o modo offline-first: cópia local das contas, fila de operações pendentes
/// e sincronização automática quando a rede volta.
class OfflineFirst extends ChangeNotifier {
  OfflineFirst(
    this._api,
    this._sessao,
    this._local, {
    Stream<bool>? mudancasRede,
    Future<bool> Function()? verificarRede,
    this.intervaloNovaTentativa = const Duration(seconds: 5),
  }) : _mudancasRede = mudancasRede ?? Connectivity().onConnectivityChanged.map(_temRede),
       _verificarRede = verificarRede ?? (() async => _temRede(await Connectivity().checkConnectivity()));

  final Api _api;
  final Sessao _sessao;
  final ArmazenamentoLocal _local;
  final Stream<bool> _mudancasRede;
  final Future<bool> Function() _verificarRede;

  /// Além de reagir à volta da rede, tenta de novo de tempos em tempos (cobre o caso
  /// "tem rede, mas a agência estava fora do ar").
  final Duration intervaloNovaTentativa;

  StreamSubscription<bool>? _assinaturaRede;
  Timer? _timer;
  bool _sincronizando = false;

  bool semRede = false;
  DateTime? semRedeDesde;
  final List<OperacaoSincronizada> sincronizadas = [];

  bool get sincronizando => _sincronizando;
  List<OperacaoPendente> get fila => _local.pendentes();
  int get qtdPendentes => fila.where((o) => o.status == StatusPendente.pendente).length;

  static bool _temRede(List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none);

  Future<void> iniciar() async {
    _definirRede(await _verificarRede());
    _assinaturaRede = _mudancasRede.listen((temRede) {
      final voltou = semRede && temRede;
      _definirRede(temRede);
      if (voltou) sincronizar(); // reconectou: sincroniza sem a pessoa apertar nada
    });
    _sessao.addListener(_aoMudarSessao);
    _timer = Timer.periodic(intervaloNovaTentativa, (_) {
      if (qtdPendentes > 0) sincronizar();
    });
    if (qtdPendentes > 0) unawaited(sincronizar());
  }

  void _definirRede(bool temRede) {
    if (semRede == !temRede) return;
    semRede = !temRede;
    semRedeDesde = semRede ? DateTime.now() : null;
    notifyListeners();
  }

  void _aoMudarSessao() {
    // Depois de um novo login (ex.: o token expirou com operações na fila), retoma a sincronização
    if (_sessao.logado && qtdPendentes > 0) sincronizar();
  }

  ContaLocal? contaLocal(int id) => _local.conta(id);

  double saldoProvisorio(ContaLocal conta) => fila
      .where((o) => o.conta == conta.id && o.status == StatusPendente.pendente)
      .fold(conta.saldo, (s, o) => s + o.tipo.efeito(o.valor));

  Future<SaldoConsultado> consultar(int id) async {
    if (!semRede) {
      try {
        final conta = ContaLocal.daApi(await _api.consultarConta(id));
        await _local.salvarConta(conta);
        return _saldo(conta, offline: false);
      } on ErroApi catch (e) {
        if (!e.semConexao) rethrow;
      }
    }
    final salva = _local.conta(id);
    if (salva == null) {
      throw ErroApi(
        0,
        'Sem conexão com a agência ${agenciaResponsavel(id)} e sem dados salvos da conta $id neste aparelho.',
      );
    }
    return _saldo(salva, offline: true);
  }

  SaldoConsultado _saldo(ContaLocal conta, {required bool offline}) => SaldoConsultado(
    conta,
    offline: offline,
    pendentes: fila.where((o) => o.conta == conta.id && o.status == StatusPendente.pendente).length,
    saldoProvisorio: saldoProvisorio(conta),
  );

  /// Depósito ou saque. Com conexão vai direto para a agência; sem conexão entra na fila.
  Future<OperacaoRealizada> operar(int id, TipoOperacao tipo, double valor) async {
    if (!semRede) {
      try {
        final r = tipo == TipoOperacao.deposito ? await _api.depositar(id, valor) : await _api.sacar(id, valor);
        await _atualizarCopia(id);
        return OperacaoRealizada(pendente: false, saldo: (r['saldo'] as num).toDouble());
      } on ErroApi catch (e) {
        if (!e.semConexao) rethrow; // erro de verdade (saldo insuficiente, conta inexistente...): não vai para a fila
      }
    }
    return _enfileirar(id, tipo, valor);
  }

  /// Depois de uma operação online, relê a conta para a cópia local ter o vetor novo.
  Future<void> _atualizarCopia(int id) async {
    try {
      await _local.salvarConta(ContaLocal.daApi(await _api.consultarConta(id)));
    } on ErroApi {
      // Sem a releitura, a próxima operação offline desta conta só vai dar conflito ao sincronizar
    }
  }

  Future<OperacaoRealizada> _enfileirar(int id, TipoOperacao tipo, double valor) async {
    final conta = _local.conta(id);
    if (conta == null) {
      throw ErroApi(
        0,
        'Sem conexão com a agência ${agenciaResponsavel(id)}. Para operar offline, consulte a conta $id antes, com conexão: o app precisa do último saldo e do vetor dela.',
      );
    }
    final provisorio = saldoProvisorio(conta);
    if (tipo == TipoOperacao.saque && provisorio < valor) {
      throw ErroApi(0, 'Sem conexão e o saldo provisório da conta $id (${moeda(provisorio)}) não cobre esse saque.');
    }
    final op = OperacaoPendente(
      chave: DateTime.now().microsecondsSinceEpoch.toString(),
      conta: id,
      tipo: tipo,
      valor: valor,
      vetorConhecido: conta.vetor,
      criadaEm: DateTime.now(),
    );
    await _local.salvarPendente(op);
    notifyListeners();
    return OperacaoRealizada(pendente: true, saldo: provisorio + tipo.efeito(valor));
  }

  /// Envia a fila em ordem. Para no primeiro "sem conexão" (as demais também falhariam).
  Future<void> sincronizar() async {
    if (_sincronizando || !_sessao.logado) return;
    _sincronizando = true;
    notifyListeners();
    try {
      for (final op in fila) {
        if (op.status != StatusPendente.pendente) continue;
        // A fila pode ter mudado dentro do laço (vetor de outra operação atualizado)
        final atual = fila.where((o) => o.chave == op.chave).firstOrNull;
        if (atual == null || atual.status != StatusPendente.pendente) continue;
        if (!await _enviar(atual)) break;
      }
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  /// false = sem conexão (ou sessão expirada): interrompe a rodada.
  Future<bool> _enviar(OperacaoPendente op) async {
    try {
      final r = await _api.sincronizar(op.conta, op.tipo.api, op.valor, op.vetorConhecido);
      final conta = ContaLocal.daApi(r);
      await _local.salvarConta(conta);
      await _local.removerPendente(op.chave);
      // Outras operações desta conta feitas com o mesmo vetor: a única mudança na agência foi
      // a operação que acabou de ser aplicada, então elas seguem com o vetor novo
      for (final outra in fila) {
        if (outra.conta == op.conta &&
            outra.status == StatusPendente.pendente &&
            vetoresIguais(outra.vetorConhecido, op.vetorConhecido)) {
          outra.vetorConhecido = conta.vetor;
          await _local.salvarPendente(outra);
        }
      }
      sincronizadas.insert(0, OperacaoSincronizada(op, conta.saldo, DateTime.now()));
      if (sincronizadas.length > 5) sincronizadas.removeLast();
      return true;
    } on ErroApi catch (e) {
      if (e.semConexao || e.status == 401) return false;
      if (e.status == 409) {
        final contaAtual = (e.dados?['contaAtual'] as Map?)?.cast<String, dynamic>();
        op
          ..status = StatusPendente.conflito
          ..mensagem = e.mensagem
          ..saldoReal = (contaAtual?['saldo'] as num?)?.toDouble()
          ..vetorReal = (e.dados?['vetorAtual'] as List?)?.map((v) => (v as num).toInt()).toList();
        // A cópia local passa a refletir o estado real da conta
        if (contaAtual != null && op.vetorReal != null) {
          await _local.salvarConta(ContaLocal.daApi({...contaAtual, 'vetorAtual': op.vetorReal}));
        }
      } else {
        op
          ..status = StatusPendente.recusada
          ..mensagem = e.toString();
      }
      await _local.salvarPendente(op);
      return true;
    }
  }

  /// Conflito: a pessoa viu o saldo real e decidiu aplicar a operação mesmo assim.
  Future<void> aplicarMesmoAssim(OperacaoPendente op) async {
    if (op.vetorReal == null) return;
    op
      ..vetorConhecido = op.vetorReal!
      ..status = StatusPendente.pendente
      ..mensagem = null;
    await _local.salvarPendente(op);
    notifyListeners();
    await sincronizar();
  }

  Future<void> descartar(OperacaoPendente op) async {
    await _local.removerPendente(op.chave);
    notifyListeners();
  }

  @override
  void dispose() {
    _assinaturaRede?.cancel();
    _timer?.cancel();
    _sessao.removeListener(_aoMudarSessao);
    super.dispose();
  }
}
