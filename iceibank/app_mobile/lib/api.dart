import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'sessao.dart';

/// Erro com o status HTTP junto; status 0 = a agência nem respondeu.
class ErroApi implements Exception {
  ErroApi(this.status, this.mensagem);

  final int status;
  final String mensagem;

  bool get semConexao => status == 0;

  @override
  String toString() => status > 0 ? '$mensagem (HTTP $status)' : mensagem;
}

class Api {
  Api(this.sessao, {http.Client? cliente}) : _cliente = cliente ?? http.Client();

  static const timeout = Duration(seconds: 3);

  final Sessao sessao;
  final http.Client _cliente;

  Future<Map<String, dynamic>> _requisitar(int agencia, String metodo, String caminho,
      [Map<String, dynamic>? corpo]) async {
    final token = sessao.token;
    final requisicao = http.Request(metodo, urlAgencia(agencia, caminho))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) requisicao.headers['Authorization'] = 'Bearer $token';
    if (corpo != null) requisicao.body = jsonEncode(corpo);

    final http.Response resposta;
    try {
      resposta = await http.Response.fromStream(await _cliente.send(requisicao).timeout(timeout));
    } catch (_) {
      throw ErroApi(0, 'Não foi possível contatar a agência $agencia (porta ${portaBase + agencia}).');
    }

    dynamic dados;
    try {
      dados = resposta.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(resposta.bodyBytes));
    } catch (_) {
      dados = null;
    }

    if (resposta.statusCode >= 400) {
      final mensagem = dados is Map && dados['erro'] != null
          ? dados['erro'] as String
          : 'A agência $agencia respondeu com erro.';
      // 401 com token = sessão expirou/inválida. No login (sem token) é só senha errada.
      if (resposta.statusCode == 401 && token != null) {
        await sessao.sair('Sessão encerrada: $mensagem Faça login novamente.');
      }
      throw ErroApi(resposta.statusCode, mensagem);
    }
    return (dados as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// O mesmo segredo JWT vale nas 3 agências: tenta cada uma até alguma responder.
  Future<String> login(String usuario, String senha) async {
    ErroApi? ultimo;
    for (var agencia = 0; agencia < numeroAgencias; agencia++) {
      try {
        final r = await _requisitar(agencia, 'POST', '/auth/login', {'usuario': usuario, 'senha': senha});
        return r['token'] as String;
      } on ErroApi catch (e) {
        if (!e.semConexao) rethrow;
        ultimo = e;
      }
    }
    throw ErroApi(0, 'Nenhuma agência respondeu. ${ultimo?.mensagem ?? ''}'.trim());
  }

  // Cada operação vai direto para a agência dona da conta (mesma regra do backend)
  Future<Map<String, dynamic>> consultarConta(int id) =>
      _requisitar(agenciaResponsavel(id), 'GET', '/contas/$id');

  Future<Map<String, dynamic>> criarConta(int id, String nomeAluno, double saldoInicial) =>
      _requisitar(agenciaResponsavel(id), 'POST', '/contas',
          {'id': id, 'nomeAluno': nomeAluno, 'saldoInicial': saldoInicial});

  Future<Map<String, dynamic>> depositar(int id, double valor) =>
      _requisitar(agenciaResponsavel(id), 'POST', '/contas/$id/depositar', {'valor': valor});

  Future<Map<String, dynamic>> sacar(int id, double valor) =>
      _requisitar(agenciaResponsavel(id), 'POST', '/contas/$id/sacar', {'valor': valor});

  Future<Map<String, dynamic>> transferir(int idOrigem, int idDestino, double valor) =>
      _requisitar(agenciaResponsavel(idOrigem), 'POST', '/transferencias',
          {'idOrigem': idOrigem, 'idDestino': idDestino, 'valor': valor});

  Future<Map<String, dynamic>> consultarTransferencia(int agencia, String idTransferencia) =>
      _requisitar(agencia, 'GET', '/transferencias/$idTransferencia');

  /// Público (sem JWT). Timeout curto: o painel prefere pular logo para outra agência.
  Future<Map<String, dynamic>> consultarLider(int agencia) async {
    try {
      final r = await _cliente.get(urlAgencia(agencia, '/bully/lider')).timeout(const Duration(seconds: 2));
      if (r.statusCode != 200) throw ErroApi(r.statusCode, 'Agência $agencia respondeu ${r.statusCode}.');
      return (jsonDecode(r.body) as Map).cast<String, dynamic>();
    } on ErroApi {
      rethrow;
    } catch (_) {
      throw ErroApi(0, 'Agência $agencia fora do ar.');
    }
  }
}
