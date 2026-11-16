import 'package:flutter/foundation.dart';

// Mesmos valores de AgenciasConfig.java: porta = 4000 + OFFSET + idAgencia
const int numeroAgencias = 3;
const int portaBase = 4006;

// Para um celular de verdade na mesma rede: flutter run --dart-define=HOST=192.168.0.10
const String _hostDefinido = String.fromEnvironment('HOST');

/// No emulador Android, "localhost" é o próprio emulador; o PC fica em 10.0.2.2.
String get hostAgencias {
  if (_hostDefinido.isNotEmpty) return _hostDefinido;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return 'localhost';
}

Uri urlAgencia(int idAgencia, String caminho) => Uri.parse('http://$hostAgencias:${portaBase + idAgencia}$caminho');

/// Mesma regra de AgenciasConfig.agenciaResponsavel: o app já sabe para qual agência mandar cada conta.
int agenciaResponsavel(int idConta) => idConta % numeroAgencias;

String moeda(num valor) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '${negativo ? '-' : ''}R\$ $inteiro,${partes[1]}';
}

/// HH:MM:SS (hora local).
String hora(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
