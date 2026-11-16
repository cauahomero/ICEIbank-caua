# ICEIBank - app mobile (Flutter)

Cliente mobile do ICEIBank (Sprint 3). Usa a mesma API REST das agências que o frontend web e mostra, em tempo real, qual agência é a líder eleita pelo algoritmo de Bully.

## Como rodar

Suba as agências antes (na pasta `iceibank`): `.\iniciar.cmd`. Login: `operador` / `senha123`.

```powershell
cd app_mobile
flutter pub get

# Emulador Android (o app acessa o PC por 10.0.2.2)
flutter emulators --launch <id_do_emulador>
flutter run

# Celular físico na mesma rede Wi-Fi: passe o IP do PC
flutter run --dart-define=HOST=192.168.0.10

# Navegador (útil para testar rápido; o backend libera CORS para localhost)
flutter run -d chrome
```

## Estrutura

| Arquivo | Papel |
|---|---|
| `lib/config.dart` | Portas das agências (4006-4008), host por plataforma, regra `id % 3` |
| `lib/sessao.dart` | Token JWT guardado no aparelho (`shared_preferences`) |
| `lib/api.dart` | Cliente HTTP: JWT no cabeçalho, erros da API (`ErroApi`), 401 encerra a sessão |
| `lib/lideranca.dart` | `MonitorLideranca`: consulta `GET /bully/lider` nas 3 agências a cada 3 s; guarda quem está no ar e o histórico de líderes |
| `lib/widgets/painel_lider.dart` | Painel da líder atual, agências ativas (com tempo de resposta) e histórico de líderes |
| `lib/offline/armazenamento.dart` | `ArmazenamentoLocal`: contas consultadas e fila de pendentes no Hive (arquivos no Android, IndexedDB no navegador) |
| `lib/offline/offline_first.dart` | `OfflineFirst`: saldo do cache sem conexão, fila de depósitos/saques offline, sincronização automática ao reconectar (`connectivity_plus`) e tratamento do 409 |
| `lib/widgets/painel_pendentes.dart` | Estado da conexão, operações pendentes/em conflito (Descartar ou Aplicar mesmo assim) e as últimas sincronizadas |
| `lib/telas/` | Login e tela principal (saldo, depósito/saque, transferência, criar conta) |

O app manda cada operação direto para a agência dona da conta (`id % 3`), então não há seletor de "agência de entrada" como no frontend web.

## Modo offline-first

1. Com conexão, consulte a conta: o app guarda o saldo e o `vetorAtual` dela no aparelho.
2. Sem conexão (modo avião; no Chrome, F12 → Network → "Offline"), a consulta mostra o último saldo salvo e depósitos/saques vão para a fila com saldo provisório.
3. Quando a rede volta, a fila é enviada sozinha para `POST /contas/{id}/sincronizar`. Também há nova tentativa a cada 5 s, para o caso de ter rede mas a agência estar fora do ar.
4. Se a conta mudou na agência nesse meio-tempo (409), a operação fica marcada como CONFLITO, mostrando o saldo real, até a pessoa escolher Descartar ou Aplicar mesmo assim.

## Testes

```powershell
flutter analyze
flutter test
```
