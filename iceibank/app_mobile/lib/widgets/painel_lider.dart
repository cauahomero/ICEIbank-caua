import 'package:flutter/material.dart';

import '../config.dart';
import '../lideranca.dart';

String _hora(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

class PainelLider extends StatelessWidget {
  const PainelLider({super.key, required this.monitor});

  final MonitorLideranca monitor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final cores = Theme.of(context).colorScheme;
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
                      Text('Líder atual (Bully)', style: Theme.of(context).textTheme.labelMedium),
                      Text(titulo, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cor)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (var i = 0; i < numeroAgencias; i++) _chipAgencia(context, i),
                ]),
                const SizedBox(height: 8),
                if (m.ultimaConsulta != null)
                  Text(
                    m.nenhumaRespondeu
                        ? 'Última tentativa às ${_hora(m.ultimaConsulta!)}. Tentando de novo a cada ${m.intervalo.inSeconds}s.'
                        : 'Consultado na agência ${m.agenciaConsultada} às ${_hora(m.ultimaConsulta!)} '
                            '(atualiza a cada ${m.intervalo.inSeconds}s).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (m.mudouEm != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Troca de liderança às ${_hora(m.mudouEm!)}: agência ${m.liderAnterior} → agência ${m.lider}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chipAgencia(BuildContext context, int id) {
    final m = monitor;
    final ehLider = m.lider == id && !m.nenhumaRespondeu;
    final caiu = m.foraDoAr.contains(id);
    return Chip(
      avatar: Icon(
        ehLider ? Icons.star : (caiu ? Icons.close : Icons.circle_outlined),
        size: 18,
        color: ehLider ? Colors.green.shade700 : (caiu ? Theme.of(context).colorScheme.error : null),
      ),
      label: Text('Agência $id${caiu ? ' (sem resposta)' : ''}'),
    );
  }
}
