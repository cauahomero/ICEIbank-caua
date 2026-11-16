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

  test('monitor pula a agência fora do ar e detecta a troca de líder', () async {
    SharedPreferences.setMockInitialValues({});
    final sessao = await Sessao.carregar();
    var lider = 2;
    final foraDoAr = <int>{};
    final cliente = MockClient((req) async {
      final agencia = req.url.port - portaBase;
      if (foraDoAr.contains(agencia)) throw http.ClientException('recusado');
      return http.Response('{"idAgencia":$agencia,"liderAtual":$lider}', 200);
    });
    final monitor = MonitorLideranca(Api(sessao, cliente: cliente));

    await monitor.consultar();
    expect(monitor.lider, 2);
    expect(monitor.agenciaConsultada, 0);

    // A agência que o app estava consultando cai e a liderança muda
    foraDoAr.add(0);
    lider = 1;
    await monitor.consultar();
    expect(monitor.agenciaConsultada, 1);
    expect(monitor.foraDoAr, {0});
    expect(monitor.lider, 1);
    expect(monitor.liderAnterior, 2);
  });
}
