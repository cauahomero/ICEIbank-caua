import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iceibank_app/api.dart';
import 'package:iceibank_app/offline/armazenamento.dart';
import 'package:iceibank_app/offline/modelos.dart';
import 'package:iceibank_app/offline/offline_first.dart';
import 'package:iceibank_app/sessao.dart';
import 'package:iceibank_app/telas/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Agência 0 de mentira, com a mesma regra do backend: qualquer evento avança o vetor,
/// e /sincronizar só aplica se o vetorConhecido for igual ao atual.
class AgenciaFalsa {
  bool noAr = true;
  final saldos = <int, double>{3: 500};
  var vetor = [5, 2, 7];

  void evento() => vetor = [vetor[0] + 1, vetor[1], vetor[2]];

  Future<http.Response> responder(http.Request req) async {
    if (!noAr) throw http.ClientException('recusado');
    final partes = req.url.pathSegments; // contas, 3, [acao]
    final id = int.parse(partes[1]);
    final corpo = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
    Map<String, dynamic> conta() => {'id': id, 'nomeAluno': 'Ana', 'saldo': saldos[id]};

    if (partes.length == 2) return _json(200, {...conta(), 'vetorAtual': vetor});
    final valor = (corpo['valor'] as num).toDouble();
    switch (partes[2]) {
      case 'depositar':
        evento();
        saldos[id] = saldos[id]! + valor;
        return _json(200, conta());
      case 'sincronizar':
        final conhecido = (corpo['vetorConhecido'] as List).cast<int>();
        if (!vetoresIguais(conhecido, vetor)) {
          return _json(409, {'erro': 'Conflito detectado.', 'vetorAtual': vetor, 'contaAtual': conta()});
        }
        final deposito = corpo['tipo'] == 'DEPOSITO';
        if (!deposito && saldos[id]! < valor) return _json(400, {'erro': 'Saldo insuficiente.'});
        evento();
        saldos[id] = saldos[id]! + (deposito ? valor : -valor);
        return _json(200, {...conta(), 'vetorAtual': vetor});
    }
    return _json(404, {'erro': 'rota'});
  }

  http.Response _json(int status, Object corpo) =>
      http.Response(jsonEncode(corpo), status, headers: {'content-type': 'application/json'});
}

void main() {
  late AgenciaFalsa agencia;
  late StreamController<bool> rede;
  late OfflineFirst offline;

  setUp(() async {
    Hive.init(Directory.systemTemp.createTempSync('iceibank_hive').path);
    SharedPreferences.setMockInitialValues({'iceibank.token': 'token-de-teste'});
    final sessao = await Sessao.carregar();
    agencia = AgenciaFalsa();
    rede = StreamController<bool>();
    final api = Api(sessao, cliente: MockClient(agencia.responder));
    final local = await ArmazenamentoLocal.abrir();
    offline = OfflineFirst(
      api,
      sessao,
      local,
      mudancasRede: rede.stream,
      verificarRede: () async => true,
      intervaloNovaTentativa: const Duration(hours: 1),
    );
    await offline.iniciar();
  });

  tearDown(() async {
    offline.dispose();
    await rede.close();
    await Hive.deleteFromDisk();
  });

  Future<void> ficarSemRede() async {
    agencia.noAr = false;
    rede.add(false);
    await pumpEventQueue();
  }

  Future<void> voltarRede() async {
    agencia.noAr = true;
    rede.add(true);
    await pumpEventQueue();
    while (offline.sincronizando) {
      await pumpEventQueue();
    }
  }

  test('saldo consultado fica salvo e aparece sem conexão', () async {
    await offline.consultar(3);
    await ficarSemRede();

    final r = await offline.consultar(3);
    expect(r.offline, isTrue);
    expect(r.conta.saldo, 500);
    expect(r.conta.vetor, [5, 2, 7]);
  });

  test('depósito offline vai para a fila com saldo provisório e sincroniza ao reconectar', () async {
    await offline.consultar(3);
    await ficarSemRede();

    final op = await offline.operar(3, TipoOperacao.deposito, 50);
    expect(op.pendente, isTrue);
    expect(op.saldo, 550);
    expect(offline.qtdPendentes, 1);
    expect(offline.fila.single.vetorConhecido, [5, 2, 7]);
    expect(agencia.saldos[3], 500); // a agência ainda não sabe de nada

    await voltarRede(); // ninguém chamou sincronizar(): foi a volta da rede
    expect(agencia.saldos[3], 550);
    expect(offline.fila, isEmpty);
    expect(offline.sincronizadas.single.saldoFinal, 550);
    expect(offline.contaLocal(3)!.vetor, [6, 2, 7]);
  });

  test('várias operações offline da mesma conta sincronizam em sequência, sem falso conflito', () async {
    await offline.consultar(3);
    await ficarSemRede();
    await offline.operar(3, TipoOperacao.deposito, 50);
    await offline.operar(3, TipoOperacao.saque, 20);
    expect((await offline.consultar(3)).saldoProvisorio, 530);

    await voltarRede();
    expect(agencia.saldos[3], 530);
    expect(offline.fila, isEmpty);
  });

  test('conta alterada por outro caminho gera conflito visível; aplicar mesmo assim reenvia', () async {
    await offline.consultar(3);
    await ficarSemRede();
    await offline.operar(3, TipoOperacao.deposito, 50);

    // Enquanto o app está offline, alguém deposita 100 direto na agência
    agencia.saldos[3] = 600;
    agencia.evento();

    await voltarRede();
    final op = offline.fila.single;
    expect(op.status, StatusPendente.conflito);
    expect(op.saldoReal, 600);
    expect(agencia.saldos[3], 600); // não aplicou às cegas
    expect(offline.contaLocal(3)!.saldo, 600); // a cópia local mostra o estado real

    await offline.aplicarMesmoAssim(op);
    expect(agencia.saldos[3], 650);
    expect(offline.fila, isEmpty);
  });

  test('descartar remove a operação em conflito', () async {
    await offline.consultar(3);
    await ficarSemRede();
    await offline.operar(3, TipoOperacao.deposito, 50);
    agencia.evento();
    await voltarRede();

    await offline.descartar(offline.fila.single);
    expect(offline.fila, isEmpty);
    expect(agencia.saldos[3], 500);
  });

  test('offline sem cópia local ou com saque maior que o saldo provisório é recusado na hora', () async {
    await ficarSemRede();
    expect(() => offline.operar(3, TipoOperacao.deposito, 10), throwsA(isA<ErroApi>()));

    agencia.noAr = true;
    rede.add(true);
    await pumpEventQueue();
    await offline.consultar(3);
    await ficarSemRede();
    expect(() => offline.operar(3, TipoOperacao.saque, 501), throwsA(isA<ErroApi>()));
    expect(offline.fila, isEmpty);
  });

  test('com rede mas agência fora do ar, a operação também vai para a fila', () async {
    await offline.consultar(3);
    agencia.noAr = false; // a rede continua "ok"
    final op = await offline.operar(3, TipoOperacao.deposito, 10);
    expect(op.pendente, isTrue);

    agencia.noAr = true;
    await offline.sincronizar(); // o que o timer de nova tentativa faz
    expect(agencia.saldos[3], 510);
  });

  testWidgets('aviso amarelo de pendente some quando a fila da conta é sincronizada', (tester) async {
    await tester.runAsync(() async {
      await offline.consultar(3);
      await ficarSemRede();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DepositoSaque(offline: offline)),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.enterText(find.byType(TextFormField).at(1), '60');
    await tester.runAsync(() async {
      await tester.tap(find.text('Depositar'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(find.textContaining('guardado na fila'), findsOneWidget);

    await tester.runAsync(voltarRede);
    await tester.pump();
    expect(find.textContaining('guardado na fila'), findsNothing);
    expect(agencia.saldos[3], 560);
  });
}
