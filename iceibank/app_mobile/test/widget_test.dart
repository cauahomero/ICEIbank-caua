import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iceibank_app/api.dart';
import 'package:iceibank_app/config.dart';
import 'package:iceibank_app/lideranca.dart';
import 'package:iceibank_app/sessao.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('agência responsável segue a regra id % 3', () {
    expect(agenciaResponsavel(3), 0);
    expect(agenciaResponsavel(4), 1);
    expect(agenciaResponsavel(5), 2);
  });

  test('formata moeda em reais', () {
    expect(moeda(1234.5), r'R$ 1.234,50');
    expect(moeda(0), r'R$ 0,00');
  });

  late Map<int, int?> liderVistoPor; // o que cada agência responde em /bully/lider
  late Set<int> foraDoAr;
  late MonitorLideranca monitor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final sessao = await Sessao.carregar();
    liderVistoPor = {0: 2, 1: 2, 2: 2};
    foraDoAr = {};
    final cliente = MockClient((req) async {
      final agencia = req.url.port - portaBase;
      if (foraDoAr.contains(agencia)) throw http.ClientException('recusado');
      return http.Response('{"idAgencia":$agencia,"liderAtual":${liderVistoPor[agencia]}}', 200);
    });
    monitor = MonitorLideranca(Api(sessao, cliente: cliente));
  });

  test('monitor mostra quais agências estão no ar', () async {
    await monitor.consultar();
    expect(monitor.agenciasNoAr, 3);
    expect(monitor.lider, 2);

    foraDoAr.add(2);
    liderVistoPor.addAll({0: 1, 1: 1});
    await monitor.consultar();
    expect(monitor.agenciasNoAr, 2);
    expect(monitor.foraDoAr, {2});
    expect(monitor.status[2]!.noAr, isFalse);
    expect(monitor.status[0]!.latencia, isNotNull);

    foraDoAr.addAll({0, 1});
    await monitor.consultar();
    expect(monitor.nenhumaRespondeu, isTrue);
  });

  test('monitor pula a agência preferida fora do ar e acusa divergência', () async {
    await monitor.consultar();
    expect(monitor.agenciaConsultada, 0);

    // A 0 caiu e, no meio da eleição, a 1 se diz líder enquanto a 2 ainda anuncia a si mesma
    foraDoAr.add(0);
    liderVistoPor.addAll({1: 1, 2: 2});
    await monitor.consultar();
    expect(monitor.agenciaConsultada, 1);
    expect(monitor.lider, 1);
    expect(monitor.divergencia, isTrue);
  });

  test('histórico guarda as trocas de liderança, mais recente primeiro', () async {
    await monitor.consultar();
    expect(monitor.historico.single.lider, 2);
    expect(monitor.historico.single.jaEraLider, isTrue);

    // Repetir a mesma líder não cria entrada nova
    await monitor.consultar();
    expect(monitor.historico, hasLength(1));

    foraDoAr.add(2);
    liderVistoPor.addAll({0: 1, 1: 1});
    await monitor.consultar();

    foraDoAr.remove(2);
    liderVistoPor.addAll({0: 2, 1: 2, 2: 2});
    await monitor.consultar();

    expect(monitor.historico.map((p) => p.lider), [2, 1, 2]);
    expect(monitor.historico.first.fim, isNull);
    expect(monitor.historico[1].fim, isNotNull);
    expect(monitor.historico[1].jaEraLider, isFalse);
  });

  test('em eleição (liderAtual null) mantém a líder anterior no histórico', () async {
    await monitor.consultar();
    liderVistoPor.addAll({0: null, 1: null, 2: null});
    await monitor.consultar();
    expect(monitor.eleicaoEmAndamento, isTrue);
    expect(monitor.historico, hasLength(1));
  });
}
