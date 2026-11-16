package com.iceibank.agencia.controller;

import com.iceibank.agencia.alerta.AlertasSaldo;
import com.iceibank.agencia.config.AgenciaState;
import com.iceibank.agencia.config.AgenciasConfig;
import com.iceibank.agencia.dto.CriarContaRequest;
import com.iceibank.agencia.dto.SincronizacaoRequest;
import com.iceibank.agencia.dto.TransferenciaRequest;
import com.iceibank.agencia.dto.ValorRequest;
import com.iceibank.agencia.relogio.CompararVetores;
import com.iceibank.agencia.relogio.RelogioVetorial;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class ContasController {

    private final AgenciaState estado;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final AlertasSaldo alertas;
    private final TransferenciasController transferencias;

    public ContasController(AgenciaState estado, RelogioVetorial relogio, RegistroEventos registro,
                            AlertasSaldo alertas, TransferenciasController transferencias) {
        this.estado = estado;
        this.relogio = relogio;
        this.registro = registro;
        this.alertas = alertas;
        this.transferencias = transferencias;
    }

    @PostMapping("/contas")
    public ResponseEntity<?> criarConta(@RequestBody CriarContaRequest req) {
        if (AgenciasConfig.agenciaResponsavel(req.getId()) != estado.getIdAgencia()) {
            return erro(HttpStatus.BAD_REQUEST, "Conta " + req.getId() + " não pertence a esta agência.");
        }
        if (estado.getContas().containsKey(req.getId())) {
            return erro(HttpStatus.CONFLICT, "Conta já existe.");
        }

        int[] ts = relogio.eventoLocal();
        Conta conta = new Conta(req.getId(), req.getNomeAluno(), req.getSaldoInicial());
        estado.getContas().put(req.getId(), conta);

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", req.getId());
        detalhes.put("nomeAluno", req.getNomeAluno());
        detalhes.put("saldoInicial", req.getSaldoInicial());
        registro.registrar("CRIAR_CONTA", ts, detalhes);

        return ResponseEntity.status(HttpStatus.CREATED).body(conta);
    }

    @GetMapping("/contas/{id}")
    public ResponseEntity<?> consultarSaldo(@PathVariable int id) {
        Conta conta = estado.getContas().get(id);
        if (conta == null) return erro(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");
        // Além da conta, devolve o vetor atual: o app guarda e manda de volta ao sincronizar
        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("id", conta.getId());
        resposta.put("nomeAluno", conta.getNomeAluno());
        resposta.put("saldo", conta.getSaldo());
        resposta.put("vetorAtual", relogio.obterVetorAtual());
        return ResponseEntity.ok(resposta);
    }

    /**
     * Aplica uma operação que o app fez offline, desde que nada tenha acontecido na agência
     * desde a última leitura do app (vetorConhecido igual ao vetor atual). Se o vetor avançou,
     * devolve 409 com o estado atual em vez de aplicar a operação às cegas.
     */
    @PostMapping("/contas/{id}/sincronizar")
    public ResponseEntity<?> sincronizar(@PathVariable int id, @RequestBody SincronizacaoRequest req) {
        Conta conta = estado.getContas().get(id);
        if (conta == null) return erro(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");
        int[] vetorConhecido = req.getVetorConhecido();
        if (vetorConhecido == null || vetorConhecido.length != AgenciasConfig.NUMERO_AGENCIAS) {
            return erro(HttpStatus.BAD_REQUEST, "Informe o vetorConhecido com " + AgenciasConfig.NUMERO_AGENCIAS + " posições.");
        }
        if (req.getValor() <= 0) return erro(HttpStatus.BAD_REQUEST, "O valor deve ser maior que zero.");
        String tipo = req.getTipo() == null ? "" : req.getTipo();

        // Comparar e aplicar sob o lock do relógio: nenhum outro evento entra entre a checagem e a operação
        synchronized (relogio) {
            int[] vetorAtual = relogio.obterVetorAtual();
            CompararVetores.Relacao relacao = CompararVetores.comparar(vetorConhecido, vetorAtual);
            if (relacao != CompararVetores.Relacao.IGUAIS) {
                Map<String, Object> conflito = new LinkedHashMap<>();
                conflito.put("erro", "Conflito detectado: o estado da conta mudou desde a última sincronização do app.");
                conflito.put("relacao", relacao);
                conflito.put("vetorConhecido", vetorConhecido);
                conflito.put("vetorAtual", vetorAtual);
                conflito.put("contaAtual", conta);
                return ResponseEntity.status(HttpStatus.CONFLICT).body(conflito);
            }

            switch (tipo) {
                case "DEPOSITO" -> conta.creditar(req.getValor());
                case "SAQUE" -> {
                    if (conta.getSaldo() < req.getValor()) return erro(HttpStatus.BAD_REQUEST, "Saldo insuficiente.");
                    conta.debitar(req.getValor());
                }
                case "TRANSFERENCIA" -> {
                    // A checagem do vetor é a mesma; aplicar é a transferência normal (mesma agência ou via fila)
                    if (req.getIdDestino() == null) return erro(HttpStatus.BAD_REQUEST, "Informe o idDestino da transferência.");
                    TransferenciaRequest transferencia = new TransferenciaRequest();
                    transferencia.setIdOrigem(id);
                    transferencia.setIdDestino(req.getIdDestino());
                    transferencia.setValor(req.getValor());
                    return transferencias.transferir(transferencia);
                }
                default -> {
                    return erro(HttpStatus.BAD_REQUEST, "Tipo de operação pendente não suportado: use DEPOSITO, SAQUE ou TRANSFERENCIA.");
                }
            }

            int[] ts = relogio.eventoLocal();
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("id", id);
            detalhes.put("tipo", tipo);
            detalhes.put("valor", req.getValor());
            detalhes.put("novoSaldo", conta.getSaldo());
            detalhes.put("vetorConhecido", vetorConhecido);
            registro.registrar("SINCRONIZACAO_OFFLINE", ts, detalhes);
            // O alerta de saldo baixo também mexe no relógio, então fica dentro do lock, antes de ler o vetor
            if (tipo.equals("SAQUE")) alertas.verificar(conta, "SAQUE");

            // Devolve o vetor depois da operação: se o app tiver mais operações pendentes desta conta,
            // feitas com o mesmo vetor, ele sabe que a única mudança foi a dele e segue com este vetor
            Map<String, Object> resposta = new LinkedHashMap<>();
            resposta.put("id", conta.getId());
            resposta.put("nomeAluno", conta.getNomeAluno());
            resposta.put("saldo", conta.getSaldo());
            resposta.put("vetorAtual", relogio.obterVetorAtual());
            return ResponseEntity.ok(resposta);
        }
    }

    @PostMapping("/contas/{id}/depositar")
    public ResponseEntity<?> depositar(@PathVariable int id, @RequestBody ValorRequest req) {
        Conta conta = estado.getContas().get(id);
        if (conta == null) return erro(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");

        int[] ts = relogio.eventoLocal();
        conta.creditar(req.getValor());

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", id);
        detalhes.put("valor", req.getValor());
        detalhes.put("novoSaldo", conta.getSaldo());
        registro.registrar("DEPOSITO", ts, detalhes);

        return ResponseEntity.ok(conta);
    }

    @PostMapping("/contas/{id}/sacar")
    public ResponseEntity<?> sacar(@PathVariable int id, @RequestBody ValorRequest req) {
        Conta conta = estado.getContas().get(id);
        if (conta == null) return erro(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");
        if (conta.getSaldo() < req.getValor()) return erro(HttpStatus.BAD_REQUEST, "Saldo insuficiente.");

        int[] ts = relogio.eventoLocal();
        conta.debitar(req.getValor());

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", id);
        detalhes.put("valor", req.getValor());
        detalhes.put("novoSaldo", conta.getSaldo());
        registro.registrar("SAQUE", ts, detalhes);
        alertas.verificar(conta, "SAQUE");

        return ResponseEntity.ok(conta);
    }

    @GetMapping("/contas/{id}/historico")
    public ResponseEntity<?> historico(@PathVariable int id, @RequestParam(defaultValue = "20") int limite) {
        Conta conta = estado.getContas().get(id);
        if (conta == null) return erro(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");
        if (limite < 1) return erro(HttpStatus.BAD_REQUEST, "O limite deve ser maior que zero.");

        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("conta", conta);
        resposta.put("eventos", registro.eventosDaConta(id, limite));
        return ResponseEntity.ok(resposta);
    }

    private ResponseEntity<Map<String, String>> erro(HttpStatus status, String mensagem) {
        return ResponseEntity.status(status).body(Map.of("erro", mensagem));
    }
}
