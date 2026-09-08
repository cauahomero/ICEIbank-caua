package com.iceibank.agencia.controller;

import com.iceibank.agencia.config.AgenciaState;
import com.iceibank.agencia.config.AgenciasConfig;
import com.iceibank.agencia.dto.CriarContaRequest;
import com.iceibank.agencia.dto.ValorRequest;
import com.iceibank.agencia.lamport.RelogioLamport;
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
    private final RelogioLamport relogio;
    private final RegistroEventos registro;

    public ContasController(AgenciaState estado, RelogioLamport relogio, RegistroEventos registro) {
        this.estado = estado;
        this.relogio = relogio;
        this.registro = registro;
    }

    @PostMapping("/contas")
    public ResponseEntity<?> criarConta(@RequestBody CriarContaRequest req) {
        if (AgenciasConfig.agenciaResponsavel(req.getId()) != estado.getIdAgencia()) {
            return erro(HttpStatus.BAD_REQUEST, "Conta " + req.getId() + " não pertence a esta agência.");
        }
        if (estado.getContas().containsKey(req.getId())) {
            return erro(HttpStatus.CONFLICT, "Conta já existe.");
        }

        int ts = relogio.eventoLocal();
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
        return ResponseEntity.ok(conta);
    }

    @PostMapping("/contas/{id}/depositar")
    public ResponseEntity<?> depositar(@PathVariable int id, @RequestBody ValorRequest req) {
        Conta conta = estado.getContas().get(id);
        if (conta == null) return erro(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");

        int ts = relogio.eventoLocal();
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

        int ts = relogio.eventoLocal();
        conta.debitar(req.getValor());

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", id);
        detalhes.put("valor", req.getValor());
        detalhes.put("novoSaldo", conta.getSaldo());
        registro.registrar("SAQUE", ts, detalhes);

        return ResponseEntity.ok(conta);
    }

    private ResponseEntity<Map<String, String>> erro(HttpStatus status, String mensagem) {
        return ResponseEntity.status(status).body(Map.of("erro", mensagem));
    }
}
