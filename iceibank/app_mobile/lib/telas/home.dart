import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../lideranca.dart';
import '../offline/modelos.dart';
import '../offline/offline_first.dart';
import '../sessao.dart';
import '../widgets/operacao.dart';
import '../widgets/painel_lider.dart';
import '../widgets/painel_pendentes.dart';

class HomeTela extends StatelessWidget {
  const HomeTela({super.key, required this.api, required this.sessao, required this.monitor, required this.offline});

  final Api api;
  final Sessao sessao;
  final MonitorLideranca monitor;
  final OfflineFirst offline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ICEIBank'),
        actions: [
          ListenableBuilder(
            listenable: offline,
            builder: (context, _) => offline.semRede
                ? Tooltip(
                    message: 'Sem conexão: operações vão para a fila',
                    child: Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.error),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout), onPressed: () => sessao.sair()),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            PainelLider(monitor: monitor),
            PainelPendentes(offline: offline),
            ConsultaSaldo(offline: offline),
            DepositoSaque(offline: offline),
            Transferencia(api: api),
            CriarConta(api: api),
          ],
        ),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.titulo, required this.children, this.ajuda});

  final String titulo;
  final String? ajuda;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            if (ajuda != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(ajuda!, style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

Widget _campo(
  TextEditingController c,
  String rotulo, {
  String? Function(String?)? validator,
  bool decimal = false,
  bool numerico = true,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: TextFormField(
    controller: c,
    keyboardType: numerico ? TextInputType.numberWithOptions(decimal: decimal) : TextInputType.text,
    decoration: InputDecoration(labelText: rotulo, border: const OutlineInputBorder(), isDense: true),
    validator: validator,
  ),
);

class ConsultaSaldo extends StatefulWidget {
  const ConsultaSaldo({super.key, required this.offline});

  final OfflineFirst offline;

  @override
  State<ConsultaSaldo> createState() => _ConsultaSaldoState();
}

/// Some com o aviso amarelo de "sem conexão / pendente" quando a rede volta e a fila daquela conta
/// foi sincronizada. Conflitos continuam visíveis no painel de pendentes.
mixin _LimpaAvisoOffline<T extends StatefulWidget> on State<T>, OperacaoMixin<T> {
  OfflineFirst get offline;
  int? _contaDoAviso;

  @override
  void initState() {
    super.initState();
    offline.addListener(_verificarAviso);
  }

  @override
  void dispose() {
    offline.removeListener(_verificarAviso);
    super.dispose();
  }

  void _verificarAviso() {
    final conta = _contaDoAviso;
    if (conta == null || resultado?.tipo != TipoMensagem.pendente || offline.semRede) return;
    final aindaNaFila = offline.fila.any((o) => o.conta == conta && o.status == StatusPendente.pendente);
    if (!aindaNaFila) {
      setState(() {
        resultado = null;
        _contaDoAviso = null;
      });
    }
  }
}

class _ConsultaSaldoState extends State<ConsultaSaldo> with OperacaoMixin, _LimpaAvisoOffline {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();

  @override
  OfflineFirst get offline => widget.offline;

  void _consultar() {
    if (!_form.currentState!.validate()) return;
    _contaDoAviso = int.parse(_id.text.trim());
    executar(
      () => widget.offline.consultar(int.parse(_id.text.trim())),
      _descrever,
      tipo: (r) => r.offline || r.pendentes > 0 ? TipoMensagem.pendente : TipoMensagem.ok,
    );
  }

  String _descrever(SaldoConsultado r) {
    final c = r.conta;
    final pendentes = r.pendentes == 0
        ? ''
        : ' Saldo provisório, com ${r.pendentes} operaç${r.pendentes == 1 ? 'ão pendente' : 'ões pendentes'}: '
              '${moeda(r.saldoProvisorio)}.';
    if (r.offline) {
      return 'Sem conexão: último saldo conhecido da conta ${c.id} (${c.nomeAluno}), '
          'salvo às ${hora(c.atualizadaEm)}: ${moeda(c.saldo)}.$pendentes';
    }
    return 'Conta ${c.id} (${c.nomeAluno}): saldo ${moeda(c.saldo)}.$pendentes';
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: _Cartao(
        titulo: 'Consultar saldo',
        children: [
          _campo(_id, 'Nº da conta', validator: validarConta),
          FilledButton(onPressed: carregando ? null : _consultar, child: const Text('Consultar')),
          Mensagem(resultado),
        ],
      ),
    );
  }
}

class DepositoSaque extends StatefulWidget {
  const DepositoSaque({super.key, required this.offline});

  final OfflineFirst offline;

  @override
  State<DepositoSaque> createState() => _DepositoSaqueState();
}

class _DepositoSaqueState extends State<DepositoSaque> with OperacaoMixin, _LimpaAvisoOffline {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _valor = TextEditingController();

  @override
  OfflineFirst get offline => widget.offline;

  void _operar(bool deposito) {
    if (!_form.currentState!.validate()) return;
    final id = int.parse(_id.text.trim());
    _contaDoAviso = id;
    final valor = lerValor(_valor.text)!;
    final tipo = deposito ? TipoOperacao.deposito : TipoOperacao.saque;
    executar(
      () => widget.offline.operar(id, tipo, valor),
      (r) => r.pendente
          ? 'Sem conexão: ${tipo.nome.toLowerCase()} de ${moeda(valor)} na conta $id guardado na fila. '
                'Saldo provisório: ${moeda(r.saldo)}. Ele será enviado sozinho quando a conexão voltar.'
          : '${tipo.nome} de ${moeda(valor)} realizado. Novo saldo da conta $id: ${moeda(r.saldo)}',
      tipo: (r) => r.pendente ? TipoMensagem.pendente : TipoMensagem.ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: _Cartao(
        titulo: 'Depósito / Saque',
        children: [
          _campo(_id, 'Nº da conta', validator: validarConta),
          _campo(_valor, 'Valor (R\$)', validator: validarValor, decimal: true),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: carregando ? null : () => _operar(true), child: const Text('Depositar')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: carregando ? null : () => _operar(false),
                  child: const Text('Sacar'),
                ),
              ),
            ],
          ),
          Mensagem(resultado),
        ],
      ),
    );
  }
}

class Transferencia extends StatefulWidget {
  const Transferencia({super.key, required this.api});

  final Api api;

  @override
  State<Transferencia> createState() => _TransferenciaState();
}

class _TransferenciaState extends State<Transferencia> with OperacaoMixin {
  static const _tentativasAcompanhamento = 30;

  final _form = GlobalKey<FormState>();
  final _origem = TextEditingController();
  final _destino = TextEditingController();
  final _valor = TextEditingController();
  Resultado? _acompanhamento;

  Future<void> _transferir() async {
    if (!_form.currentState!.validate()) return;
    final origem = int.parse(_origem.text.trim());
    final destino = int.parse(_destino.text.trim());
    final valor = lerValor(_valor.text)!;
    setState(() => _acompanhamento = null);
    final r = await executar(
      () => widget.api.transferir(origem, destino, valor),
      (r) => '${r['mensagem']} ${moeda(valor)} da conta $origem para a conta $destino.',
    );
    // Entre agências a API responde 202 (pendente): acompanha até o destino confirmar ou recusar
    final idTransferencia = r?['idTransferencia'] as String?;
    if (idTransferencia != null) _acompanhar(agenciaResponsavel(origem), idTransferencia);
  }

  Future<void> _acompanhar(int agencia, String idTransferencia) async {
    setState(
      () => _acompanhamento = const Resultado(TipoMensagem.pendente, 'Aguardando confirmação da agência de destino...'),
    );
    for (var i = 0; i < _tentativasAcompanhamento; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      final Map<String, dynamic> t;
      try {
        t = await widget.api.consultarTransferencia(agencia, idTransferencia);
      } on ErroApi catch (e) {
        if (mounted) {
          setState(
            () => _acompanhamento = Resultado(TipoMensagem.erro, 'Não foi possível acompanhar a transferência: $e'),
          );
        }
        return;
      }
      if (!mounted) return;
      if (t['status'] == 'CONCLUIDA') {
        setState(
          () => _acompanhamento = Resultado(
            TipoMensagem.ok,
            'Confirmada pela agência ${t['agenciaDestino']}: a conta ${t['idDestino']} recebeu ${moeda(t['valor'] as num)}.',
          ),
        );
        return;
      }
      if (t['status'] == 'ESTORNADA') {
        setState(
          () => _acompanhamento = Resultado(
            TipoMensagem.erro,
            'Transferência recusada: ${t['motivo']} O valor de ${moeda(t['valor'] as num)} voltou para a conta ${t['idOrigem']}.',
          ),
        );
        return;
      }
    }
    setState(
      () => _acompanhamento = const Resultado(
        TipoMensagem.pendente,
        'Ainda pendente: a agência de destino não respondeu. A mensagem continua na fila e será processada quando ela voltar.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: _Cartao(
        titulo: 'Transferência',
        ajuda: 'Contas da mesma agência: na hora. Entre agências: via fila, com confirmação.',
        children: [
          _campo(_origem, 'Conta de origem', validator: validarConta),
          _campo(_destino, 'Conta de destino', validator: validarConta),
          _campo(_valor, 'Valor (R\$)', validator: validarValor, decimal: true),
          FilledButton(onPressed: carregando ? null : _transferir, child: const Text('Transferir')),
          Mensagem(resultado),
          Mensagem(_acompanhamento),
        ],
      ),
    );
  }
}

class CriarConta extends StatefulWidget {
  const CriarConta({super.key, required this.api});

  final Api api;

  @override
  State<CriarConta> createState() => _CriarContaState();
}

class _CriarContaState extends State<CriarConta> with OperacaoMixin {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _nome = TextEditingController();
  final _saldo = TextEditingController(text: '0');

  void _criar() {
    if (!_form.currentState!.validate()) return;
    executar(
      () => widget.api.criarConta(int.parse(_id.text.trim()), _nome.text.trim(), lerValor(_saldo.text)!),
      (c) =>
          'Conta ${c['id']} criada para ${c['nomeAluno']} na agência '
          '${agenciaResponsavel(c['id'] as int)}, saldo ${moeda(c['saldo'] as num)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: _Cartao(
        titulo: 'Criar conta',
        ajuda: 'A conta vai para a agência nº % $numeroAgencias (ex.: conta 4 → agência 1).',
        children: [
          _campo(_id, 'Nº da conta', validator: validarConta),
          _campo(
            _nome,
            'Nome do aluno',
            numerico: false,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
          ),
          _campo(
            _saldo,
            'Saldo inicial (R\$)',
            decimal: true,
            validator: (v) {
              final s = lerValor(v ?? '');
              return s == null || s < 0 ? 'Informe um saldo válido' : null;
            },
          ),
          FilledButton(onPressed: carregando ? null : _criar, child: const Text('Criar')),
          Mensagem(resultado),
        ],
      ),
    );
  }
}
