import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token JWT guardado no aparelho, para o login sobreviver a fechar e abrir o app.
class Sessao extends ChangeNotifier {
  static const _chaveToken = 'iceibank.token';

  Sessao._(this._prefs) : _token = _prefs.getString(_chaveToken);

  static Future<Sessao> carregar() async => Sessao._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  String? _token;
  String? _aviso;

  String? get token => _token;
  bool get logado => _token != null;

  /// Mensagem para mostrar na tela de login (ex.: por que a sessão caiu).
  String? get aviso => _aviso;

  Future<void> entrar(String token) async {
    _token = token;
    _aviso = null;
    await _prefs.setString(_chaveToken, token);
    notifyListeners();
  }

  Future<void> sair([String? motivo]) async {
    _token = null;
    _aviso = motivo;
    await _prefs.remove(_chaveToken);
    notifyListeners();
  }
}
