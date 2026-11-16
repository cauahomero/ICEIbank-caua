import 'package:flutter/material.dart';

import '../api.dart';
import '../lideranca.dart';
import '../sessao.dart';
import '../widgets/painel_lider.dart';

class LoginTela extends StatefulWidget {
  const LoginTela({super.key, required this.api, required this.sessao, required this.monitor});

  final Api api;
  final Sessao sessao;
  final MonitorLideranca monitor;

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  String? _erro;
  bool _carregando = false;
  bool _mostrarSenha = false;

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final token = await widget.api.login(_usuario.text.trim(), _senha.text);
      await widget.sessao.entrar(token);
    } on ErroApi catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aviso = widget.sessao.aviso;
    return Scaffold(
      appBar: AppBar(title: const Text('ICEIBank')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Login', style: Theme.of(context).textTheme.headlineSmall),
                      if (aviso != null) ...[
                        const SizedBox(height: 8),
                        Text(aviso, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usuario,
                        decoration: const InputDecoration(labelText: 'Usuário', border: OutlineInputBorder()),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o usuário' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _senha,
                        obscureText: !_mostrarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            key: const Key('mostrar-senha'),
                            icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                            tooltip: _mostrarSenha ? 'Esconder senha' : 'Mostrar senha',
                            onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                          ),
                        ),
                        onFieldSubmitted: (_) => _entrar(),
                        validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _carregando ? null : _entrar,
                        child: Text(_carregando ? 'Entrando...' : 'Entrar'),
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 12),
                        Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // /bully/lider não exige login: o painel já funciona aqui, recolhido para não competir com o login
            PainelLider(monitor: widget.monitor, recolhivel: true),
          ],
        ),
      ),
    );
  }
}
