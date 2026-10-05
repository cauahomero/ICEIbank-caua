package com.iceibank.agencia.controller;

import com.iceibank.agencia.config.AgenciaState;
import com.iceibank.agencia.config.AgenciasConfig;
import com.iceibank.agencia.dto.TransferenciaRequest;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.mensageria.MensagemTransferencia;
import com.iceibank.agencia.mensageria.PublicadorTransferencias;
import com.iceibank.agencia.mensageria.Transferencia;
import com.iceibank.agencia.mensageria.TransferenciasRegistro;
import com.iceibank.agencia.model.Conta;
import com.iceibank.agencia.relogio.RelogioVetorial;
import org.springframework.amqp.AmqpException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@RestController
public class TransferenciasController {

    private final AgenciaState estado;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final PublicadorTransferencias publicador;
    private final TransferenciasRegistro transferencias;
    private final boolean simularDuplicidade;

    public TransferenciasController(AgenciaState estado, RelogioVetorial relogio, RegistroEventos registro,
                                    PublicadorTransferencias publicador, TransferenciasRegistro transferencias,
                                    @Value("${mensageria.simular-duplicidade}") boolean simularDuplicidade) {
        this.estado = estado;
        this.relogio = relogio;
        this.registro = registro;
        this.publicador = publicador;
        this.transferencias = transferencias;
        this.simularDuplicidade = simularDuplicidade;
    }

    @PostMapping("/transferencias")
    public ResponseEntity<?> transferir(@RequestBody TransferenciaRequest req) {
        Conta contaOrigem = estado.getContas().get(req.getIdOrigem());
        if (contaOrigem == null) return erro(HttpStatus.NOT_FOUND, "Conta de origem não encontrada nesta agência.");
        if (contaOrigem.getSaldo() < req.getValor()) return erro(HttpStatus.BAD_REQUEST, "Saldo insuficiente.");

        int agenciaDestino = AgenciasConfig.agenciaResponsavel(req.getIdDestino());
        boolean remota = agenciaDestino != estado.getIdAgencia();
        String idTransferencia = UUID.randomUUID().toString();

        // O débito é sempre local, pois esta agência é a dona da conta de origem
        int[] tsDebito = relogio.eventoLocal();
        contaOrigem.debitar(req.getValor());
        Map<String, Object> detalhesDebito = new LinkedHashMap<>();
        detalhesDebito.put("idOrigem", req.getIdOrigem());
        detalhesDebito.put("idDestino", req.getIdDestino());
        detalhesDebito.put("valor", req.getValor());
        if (remota) detalhesDebito.put("idTransferencia", idTransferencia);
        registro.registrar("TRANSFERENCIA_DEBITO", tsDebito, detalhesDebito);

        if (!remota) {
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

        // Entre agências: em vez de chamar a outra agência, publica na fila dela e não espera.
        // A transferência é registrada antes de publicar, porque a confirmação pode chegar muito rápido.
        Transferencia transferencia = new Transferencia(idTransferencia, req.getIdOrigem(), req.getIdDestino(),
                agenciaDestino, req.getValor());
        transferencias.adicionar(transferencia);

        int[] tsEnvio = relogio.aoEnviar();
        MensagemTransferencia msg = MensagemTransferencia.solicitacao(idTransferencia, estado.getIdAgencia(),
                agenciaDestino, req.getIdOrigem(), req.getIdDestino(), req.getValor(), tsEnvio);
        try {
            publicador.publicarCredito(agenciaDestino, msg);
            if (simularDuplicidade) publicador.publicarCredito(agenciaDestino, msg);
        } catch (AmqpException e) {
            // Sem broker a mensagem nem saiu, então dá para desfazer o débito na hora
            contaOrigem.creditar(req.getValor());
            transferencia.finalizar(Transferencia.ESTORNADA, "Mensageria indisponível.");
            Map<String, Object> detalhesFalha = new LinkedHashMap<>(detalhesDebito);
            detalhesFalha.put("erro", e.getMessage());
            registro.registrar("TRANSFERENCIA_FALHOU", relogio.eventoLocal(), detalhesFalha);
            return erro(HttpStatus.SERVICE_UNAVAILABLE, "Mensageria indisponível. A transferência não foi feita e o débito foi desfeito.");
        }

        Map<String, Object> detalhesEnvio = new LinkedHashMap<>();
        detalhesEnvio.put("idOrigem", req.getIdOrigem());
        detalhesEnvio.put("idDestino", req.getIdDestino());
        detalhesEnvio.put("valor", req.getValor());
        detalhesEnvio.put("idTransferencia", idTransferencia);
        detalhesEnvio.put("idMensagem", msg.getIdMensagem());
        detalhesEnvio.put("tipoMensagem", msg.getTipo());
        detalhesEnvio.put("paraAgencia", agenciaDestino);
        registro.registrar("MENSAGEM_ENVIADA", tsEnvio, detalhesEnvio);

        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("mensagem", "Transferência enviada para a agência " + agenciaDestino + ". Aguardando confirmação.");
        resposta.put("idTransferencia", idTransferencia);
        resposta.put("status", transferencia.getStatus());
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(resposta);
    }

    @GetMapping("/transferencias/{id}")
    public ResponseEntity<?> consultar(@PathVariable String id) {
        Transferencia t = transferencias.buscar(id);
        if (t == null) return erro(HttpStatus.NOT_FOUND, "Transferência não encontrada nesta agência.");
        return ResponseEntity.ok(t);
    }

    private ResponseEntity<Map<String, String>> erro(HttpStatus status, String mensagem) {
        return ResponseEntity.status(status).body(Map.of("erro", mensagem));
    }
}
