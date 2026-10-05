package com.iceibank.agencia.controller;

import com.iceibank.agencia.auth.JwtFiltro;
import com.iceibank.agencia.auth.JwtService;
import com.iceibank.agencia.config.AgenciaState;
import com.iceibank.agencia.config.AgenciasConfig;
import com.iceibank.agencia.dto.CreditarRemotoRequest;
import com.iceibank.agencia.dto.TransferenciaRequest;
import com.iceibank.agencia.relogio.RelogioVetorial;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class TransferenciasController {

    private final AgenciaState estado;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final JwtService jwtService;
    private final RestTemplate restTemplate = new RestTemplate();

    public TransferenciasController(AgenciaState estado, RelogioVetorial relogio, RegistroEventos registro,
                                    JwtService jwtService) {
        this.estado = estado;
        this.relogio = relogio;
        this.registro = registro;
        this.jwtService = jwtService;
    }

    @PostMapping("/transferencias")
    public ResponseEntity<?> transferir(@RequestBody TransferenciaRequest req) {
        Conta contaOrigem = estado.getContas().get(req.getIdOrigem());
        if (contaOrigem == null) return erro(HttpStatus.NOT_FOUND, "Conta de origem não encontrada nesta agência.");
        if (contaOrigem.getSaldo() < req.getValor()) return erro(HttpStatus.BAD_REQUEST, "Saldo insuficiente.");

        int agenciaDestino = AgenciasConfig.agenciaResponsavel(req.getIdDestino());

        // O débito é sempre local, pois esta agência é a dona da conta de origem
        int[] tsDebito = relogio.eventoLocal();
        contaOrigem.debitar(req.getValor());
        Map<String, Object> detalhesDebito = new LinkedHashMap<>();
        detalhesDebito.put("idOrigem", req.getIdOrigem());
        detalhesDebito.put("idDestino", req.getIdDestino());
        detalhesDebito.put("valor", req.getValor());
        registro.registrar("TRANSFERENCIA_DEBITO", tsDebito, detalhesDebito);

        if (agenciaDestino == estado.getIdAgencia()) {
            Conta contaDestino = estado.getContas().get(req.getIdDestino());
            if (contaDestino == null) {
                contaOrigem.creditar(req.getValor());
                return erro(HttpStatus.NOT_FOUND, "Conta de destino não encontrada.");
            }
            int[] tsCredito = relogio.eventoLocal();
            contaDestino.creditar(req.getValor());
            Map<String, Object> detalhesCredito = new LinkedHashMap<>();
            detalhesCredito.put("idOrigem", req.getIdOrigem());
            detalhesCredito.put("idDestino", req.getIdDestino());
            detalhesCredito.put("valor", req.getValor());
            registro.registrar("TRANSFERENCIA_CREDITO", tsCredito, detalhesCredito);
            return ResponseEntity.ok(Map.of("mensagem", "Transferência concluída (mesma agência)."));
        }

        // Caso entre agências: chama a agência de destino diretamente via REST
        int[] tsEnvio = relogio.aoEnviar();
        String urlDestino = AgenciasConfig.urlAgencia(agenciaDestino);

        try {
            CreditarRemotoRequest corpo = new CreditarRemotoRequest();
            corpo.setValor(req.getValor());
            corpo.setVetorEnvio(tsEnvio);
            corpo.setOrigemAgencia(estado.getIdAgencia());

            HttpHeaders cabecalhos = new HttpHeaders();
            cabecalhos.setBearerAuth(jwtService.gerarTokenServico(estado.getIdAgencia()));

            restTemplate.postForEntity(urlDestino + "/contas/" + req.getIdDestino() + "/creditar-remoto",
                    new HttpEntity<>(corpo, cabecalhos), Void.class);
            return ResponseEntity.ok(Map.of("mensagem", "Transferência concluída (entre agências)."));
        } catch (RestClientException e) {
            // LIMITAÇÃO CONHECIDA: se esta chamada falhar, o débito já aplicado acima
            // NÃO é revertido 
            Map<String, Object> detalhesFalha = new LinkedHashMap<>();
            detalhesFalha.put("idOrigem", req.getIdOrigem());
            detalhesFalha.put("idDestino", req.getIdDestino());
            detalhesFalha.put("valor", req.getValor());
            detalhesFalha.put("erro", e.getMessage());
            registro.registrar("TRANSFERENCIA_FALHOU", relogio.eventoLocal(), detalhesFalha);

            return erro(HttpStatus.BAD_GATEWAY,
                    "Falha ao contatar agência de destino. Débito já aplicado - inconsistência conhecida (ver Sprint 4).");
        }
    }

    @PostMapping("/contas/{id}/creditar-remoto")
    public ResponseEntity<?> creditarRemoto(@PathVariable int id, @RequestBody CreditarRemotoRequest req,
                                            HttpServletRequest request) {
        Claims claims = (Claims) request.getAttribute(JwtFiltro.ATRIBUTO_CLAIMS);
        if (!JwtService.TIPO_AGENCIA.equals(claims.get("tipo", String.class))) {
            return erro(HttpStatus.FORBIDDEN, "Rota exclusiva para chamadas entre agências.");
        }

        int[] ts = relogio.aoReceber(req.getVetorEnvio());

        Conta conta = estado.getContas().get(id);
        if (conta == null) return erro(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");

        conta.creditar(req.getValor());
        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idConta", id);
        detalhes.put("valor", req.getValor());
        detalhes.put("origemAgencia", req.getOrigemAgencia());
        registro.registrar("TRANSFERENCIA_CREDITO_REMOTO", ts, detalhes);

        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("mensagem", "Crédito remoto aplicado.");
        resposta.put("saldoAtual", conta.getSaldo());
        return ResponseEntity.ok(resposta);
    }

    private ResponseEntity<Map<String, String>> erro(HttpStatus status, String mensagem) {
        return ResponseEntity.status(status).body(Map.of("erro", mensagem));
    }
}
