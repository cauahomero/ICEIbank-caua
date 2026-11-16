import 'package:flutter/material.dart';

import '../config.dart';
import '../lideranca.dart';

String _hora(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

String _duracao(Duration d) {
  if (d.inHours > 0) return '${d.inHours}h${(d.inMinutes % 60).toString().padLeft(2, '0')}min';
  if (d.inMinutes > 0) return '${d.inMinutes}min${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
  return '${d.inSeconds}s';
}

/// Líder atual, situação de cada agência e histórico de trocas de liderança.
class PainelLider extends StatelessWidget {
  const PainelLider({super.key, required this.monitor});

  final MonitorLideranca monitor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final cores = Theme.of(context).colorScheme;
        final textos = Theme.of(context).textTheme;
        final m = monitor;

        final (IconData icone, Color cor, String titulo) = switch (m) {
          _ when m.ultimaConsulta == null => (Icons.hourglass_top, cores.outline, 'Consultando agências...'),
          _ when m.nenhumaRespondeu => (Icons.cloud_off, cores.error, 'Nenhuma agência respondeu'),
          _ when m.eleicaoEmAndamento => (Icons.how_to_vote, Colors.orange.shade700, 'Eleição em andamento...'),
          _ => (Icons.workspace_premium, Colors.green.shade700, 'Agência ${m.lider} é a líder'),
        };

        return Card(
          key: const Key('painel-lider'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icone, color: cor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Líder atual (Bully)', style: textos.labelMedium),
                      Text(titulo, style: textos.titleLarge?.copyWith(color: cor)),
                    ]),
                  ),
                ]),
                if (m.ultimaConsulta != null) ...[
                  const SizedBox(height: 12),
                  _AgenciasAtivas(monitor: m),
                  const SizedBox(height: 8),
                  Text(
                    m.nenhumaRespondeu
                        ? 'Última tentativa às ${_hora(m.ultimaConsulta!)}. Tentando de novo a cada ${m.intervalo.inSeconds}s.'
                        : 'Líder segundo a agência ${m.agenciaConsultada}, consultado às ${_hora(m.ultimaConsulta!)} '
                            '(atualiza a cada ${m.intervalo.inSeconds}s).',
                    style: textos.bodySmall,
                  ),
                ],
                if (m.historico.isNotEmpty) ...[
                  const Divider(height: 24),
                  _HistoricoLideres(monitor: m),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AgenciasAtivas extends StatelessWidget {
  const _AgenciasAtivas({required this.monitor});

  final MonitorLideranca monitor;

  @override
  Widget build(BuildContext context) {
    final m = monitor;
    final textos = Theme.of(context).textTheme;
    final erro = Theme.of(context).colorScheme.error;
    final verde = Colors.green.shade700;
    final noAr = m.agenciasNoAr;
    final corResumo = noAr == numeroAgencias ? verde : (noAr == 0 ? erro : Colors.orange.shade800);

    return Column(
      key: const Key('agencias-ativas'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Agências: $noAr de $numeroAgencias no ar',
            style: textos.titleSmall?.copyWith(color: corResumo, fontWeight: FontWeight.bold)),
        if (m.divergencia)
          Text('As agências ainda não concordam sobre a líder (eleição convergindo).',
              style: textos.bodySmall?.copyWith(color: Colors.orange.shade800)),
        const SizedBox(height: 4),
        for (var i = 0; i < numeroAgencias; i++) _linha(context, i, verde, erro),
      ],
    );
  }

  Widget _linha(BuildContext context, int id, Color verde, Color erro) {
    final s = monitor.status[id];
    if (s == null) return const SizedBox.shrink();
    final textos = Theme.of(context).textTheme;
    final ehLider = s.noAr && monitor.lider == id;

    final String detalhe;
    if (!s.noAr) {
      detalhe = 'fora do ar desde ${_hora(s.desde)}';
    } else {
      final ms = '${s.latencia!.inMilliseconds} ms';
      final visao = switch (s.liderAtual) {
        null => ' · em eleição',
        final l when l != monitor.lider => ' · vê a agência $l como líder',
        _ => '',
      };
      detalhe = 'no ar · $ms$visao';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(Icons.circle, size: 12, color: s.noAr ? verde : erro),
        const SizedBox(width: 8),
        Text('Agência $id', style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (ehLider) ...[
          const SizedBox(width: 4),
          Icon(Icons.star, size: 16, color: verde),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Text(detalhe,
              style: textos.bodySmall?.copyWith(color: s.noAr ? null : erro), overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _HistoricoLideres extends StatelessWidget {
  const _HistoricoLideres({required this.monitor});

  final MonitorLideranca monitor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final agora = DateTime.now();
    final trocas = monitor.historico.length - 1;

    return Column(
      key: const Key('historico-lideres'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.history, size: 18),
          const SizedBox(width: 6),
          Text('Histórico de líderes', style: textos.titleSmall),
          const Spacer(),
          Text(trocas == 0 ? 'nenhuma troca' : '$trocas ${trocas == 1 ? 'troca' : 'trocas'}', style: textos.bodySmall),
        ]),
        const SizedBox(height: 4),
        for (final p in monitor.historico)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 84,
                child: Text('Agência ${p.lider}',
                    style: textos.bodyMedium?.copyWith(fontWeight: p.fim == null ? FontWeight.bold : null)),
              ),
              Expanded(
                child: Text(
                  '${p.jaEraLider ? 'já era líder às ' : 'eleita às '}${_hora(p.inicio)}'
                  '${p.fim == null ? ' · atual' : ' até ${_hora(p.fim!)} (${_duracao(p.duracao(agora))})'}',
                  style: textos.bodySmall,
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
