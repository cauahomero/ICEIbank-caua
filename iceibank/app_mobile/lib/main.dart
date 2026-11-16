import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'api.dart';
import 'lideranca.dart';
import 'offline/armazenamento.dart';
import 'offline/offline_first.dart';
import 'sessao.dart';
import 'telas/home.dart';
import 'telas/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessao = await Sessao.carregar();
  await Hive.initFlutter();
  final local = await ArmazenamentoLocal.abrir();
  runApp(IceibankApp(sessao: sessao, local: local));
}

class IceibankApp extends StatefulWidget {
  const IceibankApp({super.key, required this.sessao, required this.local});

  final Sessao sessao;
  final ArmazenamentoLocal local;

  @override
  State<IceibankApp> createState() => _IceibankAppState();
}

class _IceibankAppState extends State<IceibankApp> {
  late final Api api = Api(widget.sessao);
  late final MonitorLideranca monitor = MonitorLideranca(api);
  late final OfflineFirst offline = OfflineFirst(api, widget.sessao, widget.local);
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    monitor.iniciar();
    offline.iniciar();
    // Só faz polling com o app na tela
    _ciclo = AppLifecycleListener(onResume: monitor.iniciar, onPause: monitor.parar);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    monitor.dispose();
    offline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ICEIBank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B5E9E), useMaterial3: true),
      home: ListenableBuilder(
        listenable: widget.sessao,
        builder: (context, _) => widget.sessao.logado
            ? HomeTela(api: api, sessao: widget.sessao, monitor: monitor, offline: offline)
            : LoginTela(api: api, sessao: widget.sessao, monitor: monitor),
      ),
    );
  }
}
