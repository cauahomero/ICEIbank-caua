/// Cópia local de uma conta: último saldo e vetor que a agência devolveu numa consulta.
class ContaLocal {
  ContaLocal({
    required this.id,
    required this.nomeAluno,
    required this.saldo,
    required this.vetor,
    required this.atualizadaEm,
  });

  final int id;
  final String nomeAluno;
  final double saldo;

  /// vetorAtual da agência na última leitura: é o "vetor conhecido" das operações offline.
  final List<int> vetor;
  final DateTime atualizadaEm;

  factory ContaLocal.daApi(Map<String, dynamic> j, {DateTime? em}) => ContaLocal(
    id: j['id'] as int,
    nomeAluno: j['nomeAluno'] as String? ?? '',
    saldo: (j['saldo'] as num).toDouble(),
    vetor: _vetor(j['vetorAtual']),
    atualizadaEm: em ?? DateTime.now(),
  );

  factory ContaLocal.doMapa(Map m) => ContaLocal(
    id: m['id'] as int,
    nomeAluno: m['nomeAluno'] as String,
    saldo: (m['saldo'] as num).toDouble(),
    vetor: _vetor(m['vetor']),
    atualizadaEm: DateTime.parse(m['atualizadaEm'] as String),
  );

  Map<String, dynamic> paraMapa() => {
    'id': id,
    'nomeAluno': nomeAluno,
    'saldo': saldo,
    'vetor': vetor,
    'atualizadaEm': atualizadaEm.toIso8601String(),
  };
}

enum TipoOperacao {
  deposito('DEPOSITO', 'Depósito'),
  saque('SAQUE', 'Saque');

  const TipoOperacao(this.api, this.nome);

  final String api;
  final String nome;

  /// Efeito no saldo: depósito soma, saque subtrai.
  double efeito(double valor) => this == deposito ? valor : -valor;

  static TipoOperacao daApi(String s) => values.firstWhere((t) => t.api == s);
}

enum StatusPendente {
  /// Na fila, esperando conexão.
  pendente,

  /// A agência respondeu 409: a conta mudou enquanto o app estava offline. Espera a decisão da pessoa.
  conflito,

  /// A agência recusou por outro motivo (ex.: saldo insuficiente na hora de aplicar).
  recusada,
}

/// Operação feita sem conexão, guardada até poder ser sincronizada.
class OperacaoPendente {
  OperacaoPendente({
    required this.chave,
    required this.conta,
    required this.tipo,
    required this.valor,
    required this.vetorConhecido,
    required this.criadaEm,
    this.status = StatusPendente.pendente,
    this.mensagem,
    this.saldoReal,
    this.vetorReal,
  });

  final String chave;
  final int conta;
  final TipoOperacao tipo;
  final double valor;
  List<int> vetorConhecido;
  final DateTime criadaEm;
  StatusPendente status;
  String? mensagem;

  /// Estado real da conta devolvido no 409.
  double? saldoReal;
  List<int>? vetorReal;

  factory OperacaoPendente.doMapa(Map m) => OperacaoPendente(
    chave: m['chave'] as String,
    conta: m['conta'] as int,
    tipo: TipoOperacao.daApi(m['tipo'] as String),
    valor: (m['valor'] as num).toDouble(),
    vetorConhecido: _vetor(m['vetorConhecido']),
    criadaEm: DateTime.parse(m['criadaEm'] as String),
    status: StatusPendente.values.byName(m['status'] as String),
    mensagem: m['mensagem'] as String?,
    saldoReal: (m['saldoReal'] as num?)?.toDouble(),
    vetorReal: m['vetorReal'] == null ? null : _vetor(m['vetorReal']),
  );

  Map<String, dynamic> paraMapa() => {
    'chave': chave,
    'conta': conta,
    'tipo': tipo.api,
    'valor': valor,
    'vetorConhecido': vetorConhecido,
    'criadaEm': criadaEm.toIso8601String(),
    'status': status.name,
    'mensagem': mensagem,
    'saldoReal': saldoReal,
    'vetorReal': vetorReal,
  };
}

/// Operação que estava na fila e foi aplicada pela agência (para mostrar o "antes/depois" na tela).
class OperacaoSincronizada {
  OperacaoSincronizada(this.operacao, this.saldoFinal, this.em);

  final OperacaoPendente operacao;
  final double saldoFinal;
  final DateTime em;
}

List<int> _vetor(dynamic v) => (v as List? ?? const []).map((e) => (e as num).toInt()).toList();

bool vetoresIguais(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
