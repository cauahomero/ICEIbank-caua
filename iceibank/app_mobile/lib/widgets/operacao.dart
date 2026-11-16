import 'package:flutter/material.dart';

import '../api.dart';

enum TipoMensagem { ok, erro, pendente }

class Resultado {
  const Resultado(this.tipo, this.texto);

  final TipoMensagem tipo;
  final String texto;
}

/// Estado comum das operações: carregando + mensagem de sucesso ou erro da API.
mixin OperacaoMixin<T extends StatefulWidget> on State<T> {
  Resultado? resultado;
  bool carregando = false;

  Future<R?> executar<R>(Future<R> Function() chamada, String Function(R) sucesso) async {
    setState(() {
      carregando = true;
      resultado = null;
    });
    try {
      final dados = await chamada();
      if (mounted) setState(() => resultado = Resultado(TipoMensagem.ok, sucesso(dados)));
      return dados;
    } on ErroApi catch (e) {
      // 401 já derruba a sessão e volta para o login (ver Api)
      if (mounted) setState(() => resultado = Resultado(TipoMensagem.erro, e.toString()));
      return null;
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }
}

class Mensagem extends StatelessWidget {
  const Mensagem(this.resultado, {super.key});

  final Resultado? resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    if (r == null) return const SizedBox.shrink();
    final cores = Theme.of(context).colorScheme;
    final (Color fundo, Color texto, IconData icone) = switch (r.tipo) {
      TipoMensagem.ok => (Colors.green.shade50, Colors.green.shade900, Icons.check_circle),
      TipoMensagem.erro => (cores.errorContainer, cores.onErrorContainer, Icons.error),
      TipoMensagem.pendente => (Colors.amber.shade50, Colors.brown.shade800, Icons.schedule),
    };
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: texto, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(r.texto, style: TextStyle(color: texto))),
      ]),
    );
  }
}

/// Aceita "10,50" ou "10.50".
double? lerValor(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

String? validarConta(String? v) => int.tryParse(v?.trim() ?? '') == null ? 'Informe o nº da conta' : null;

String? validarValor(String? v) {
  final valor = lerValor(v ?? '');
  return valor == null || valor <= 0 ? 'Informe um valor maior que zero' : null;
}
