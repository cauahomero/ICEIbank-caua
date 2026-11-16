import 'package:flutter/material.dart';

import '../config.dart';
import '../offline/modelos.dart';
import '../offline/offline_first.dart';

/// Estado da conexão, fila de operações offline (pendentes, conflitos, recusadas)
/// e as últimas operações que a sincronização aplicou.
class PainelPendentes extends StatelessWidget {
  const PainelPendentes({super.key, required this.offline});

  final OfflineFirst offline;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: offline,
      builder: (context, _) {
        final o = offline;
        final fila = o.fila;
        if (!o.semRede && fila.isEmpty && o.sincronizadas.isEmpty) return const SizedBox.shrink();
        final textos = Theme.of(context).textTheme;

        final (IconData icone, Color cor, String titulo, String detalhe) = switch (o) {
          _ when o.semRede => (
            Icons.cloud_off,
            Theme.of(context).colorScheme.error,
            'Sem conexão',
            'Desde ${hora(o.semRedeDesde!)}. Saldos mostram o último dado salvo e depósitos/saques vão para a fila.',
          ),
          _ when o.sincronizando => (
            Icons.sync,
            Colors.blue.shade700,
            'Sincronizando...',
            'Enviando a fila para as agências.',
          ),
          _ when o.qtdPendentes > 0 => (
            Icons.cloud_upload,
            Colors.orange.shade800,
            'Aguardando as agências',
            'Tem rede, mas a agência ainda não respondeu. Nova tentativa a cada ${o.intervaloNovaTentativa.inSeconds}s.',
          ),
          _ when fila.isNotEmpty => (
            Icons.report,
            Theme.of(context).colorScheme.error,
            'Precisa da sua decisão',
            '${fila.length} operaç${fila.length == 1 ? 'ão feita offline não pôde' : 'ões feitas offline não puderam'} '
                'ser aplicada${fila.length == 1 ? '' : 's'} automaticamente.',
          ),
          _ => (Icons.cloud_done, Colors.green.shade700, 'Conectado', 'Fila sincronizada.'),
        };

        return Card(
          key: const Key('painel-pendentes'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icone, color: cor),
                    const SizedBox(width: 8),
                    Text(titulo, style: textos.titleMedium?.copyWith(color: cor)),
                    const Spacer(),
                    if (o.qtdPendentes > 0)
                      Chip(
                        label: Text('${o.qtdPendentes} pendente${o.qtdPendentes > 1 ? 's' : ''}'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                Text(detalhe, style: textos.bodySmall),
                for (final op in fila) _ItemFila(op: op, offline: o),
                if (o.sincronizadas.isNotEmpty) ...[
                  const Divider(height: 20),
                  Text('Sincronizadas agora há pouco', style: textos.labelLarge),
                  for (final s in o.sincronizadas)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.operacao.tipo.nome} de ${moeda(s.operacao.valor)} na conta ${s.operacao.conta} '
                              '(feito offline às ${hora(s.operacao.criadaEm)}) aplicado às ${hora(s.em)}. '
                              'Saldo: ${moeda(s.saldoFinal)}',
                              style: textos.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemFila extends StatelessWidget {
  const _ItemFila({required this.op, required this.offline});

  final OperacaoPendente op;
  final OfflineFirst offline;

  @override
  Widget build(BuildContext context) {
    final descricao = '${op.tipo.nome} de ${moeda(op.valor)} · conta ${op.conta}';

    switch (op.status) {
      case StatusPendente.pendente:
        final conta = offline.contaLocal(op.conta);
        return _caixa(
          context,
          fundo: Colors.amber.shade50,
          cor: Colors.brown.shade800,
          icone: Icons.schedule,
          titulo: '$descricao · PENDENTE',
          texto:
              'Feito offline às ${hora(op.criadaEm)}, ainda não aplicado pela agência.'
              '${conta == null ? '' : ' Saldo provisório: ${moeda(offline.saldoProvisorio(conta))}.'}',
        );
      case StatusPendente.conflito:
        return _caixa(
          context,
          fundo: Theme.of(context).colorScheme.errorContainer,
          cor: Theme.of(context).colorScheme.onErrorContainer,
          icone: Icons.sync_problem,
          titulo: '$descricao · CONFLITO',
          texto:
              'A conta ${op.conta} mudou na agência enquanto o app estava offline, então esta operação '
              'NÃO foi aplicada. Saldo real agora: ${op.saldoReal == null ? '?' : moeda(op.saldoReal!)}'
              '${op.saldoReal == null ? '' : ' (com a operação ficaria ${moeda(op.saldoReal! + op.tipo.efeito(op.valor))})'}.',
          acoes: [
            TextButton(onPressed: () => offline.descartar(op), child: const Text('Descartar')),
            FilledButton(onPressed: () => offline.aplicarMesmoAssim(op), child: const Text('Aplicar mesmo assim')),
          ],
        );
      case StatusPendente.recusada:
        return _caixa(
          context,
          fundo: Theme.of(context).colorScheme.errorContainer,
          cor: Theme.of(context).colorScheme.onErrorContainer,
          icone: Icons.block,
          titulo: '$descricao · RECUSADA',
          texto: 'A agência recusou ao sincronizar: ${op.mensagem}',
          acoes: [TextButton(onPressed: () => offline.descartar(op), child: const Text('Remover da fila'))],
        );
    }
  }

  Widget _caixa(
    BuildContext context, {
    required Color fundo,
    required Color cor,
    required IconData icone,
    required String titulo,
    required String texto,
    List<Widget> acoes = const [],
  }) {
    final textos = Theme.of(context).textTheme;
    return Container(
      key: Key('pendente-${op.chave}'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: cor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo, style: textos.titleSmall?.copyWith(color: cor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(texto, style: textos.bodySmall?.copyWith(color: cor)),
          if (acoes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, children: acoes),
            ),
        ],
      ),
    );
  }
}
