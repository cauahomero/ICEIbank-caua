package com.iceibank.agencia.mensageria;

import com.iceibank.agencia.config.AgenciaState;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import com.iceibank.agencia.relogio.RelogioVetorial;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Consome a fila desta agência. Faz os dois papéis da transferência:
 * - como destino: recebe CREDITO_SOLICITADO, credita (ou recusa) e responde para a origem;
 * - como origem: recebe a resposta e conclui a transferência, ou estorna o débito se foi recusada.
 */
@Component
public class ConsumidorTransferencias {

    private final AgenciaState estado;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final PublicadorTransferencias publicador;
    private final TransferenciasRegistro transferencias;

    // Ids de mensagens já processadas. O broker entrega "pelo menos uma vez",
    // então a mesma mensagem pode chegar de novo e não pode ser aplicada duas vezes.
    // Fica em memória, como as contas: some quando a agência reinicia.
    private final Set<String> processadas = ConcurrentHashMap.newKeySet();

    public ConsumidorTransferencias(AgenciaState estado, RelogioVetorial relogio, RegistroEventos registro,
                                    PublicadorTransferencias publicador, TransferenciasRegistro transferencias) {
        this.estado = estado;
        this.relogio = relogio;
        this.registro = registro;
        this.publicador = publicador;
        this.transferencias = transferencias;
    }

    @RabbitListener(queues = "fila-agencia-${agencia.id}")
    public void receber(MensagemTransferencia msg) {
        if (processadas.contains(msg.getIdMensagem())) {
            Map<String, Object> detalhes = base(msg);
            detalhes.put("tipoMensagem", msg.getTipo());
            registro.registrar("MENSAGEM_DUPLICADA_IGNORADA", relogio.eventoLocal(), detalhes);
            return;
        }

        switch (msg.getTipo()) {
            case MensagemTransferencia.CREDITO_SOLICITADO -> creditar(msg);
            case MensagemTransferencia.CREDITO_CONFIRMADO -> concluir(msg);
            case MensagemTransferencia.CREDITO_RECUSADO -> estornar(msg);
            default -> throw new IllegalArgumentException("Tipo de mensagem desconhecido: " + msg.getTipo());
        }
        // Só marca depois de processar: se falhar no meio, a reentrega ainda é aplicada
        processadas.add(msg.getIdMensagem());
    }

    // Lado do destino
    private void creditar(MensagemTransferencia msg) {
        int[] recebimento = relogio.aoReceber(msg.getVetorEnvio());
        Conta conta = estado.getContas().get(msg.getIdDestino());

        if (conta == null) {
            String motivo = "Conta de destino " + msg.getIdDestino() + " não encontrada na agência " + estado.getIdAgencia() + ".";
            Map<String, Object> detalhes = base(msg);
            detalhes.put("motivo", motivo);
            registro.registrar("TRANSFERENCIA_CREDITO_RECUSADO", recebimento, detalhes);
            responder(msg, MensagemTransferencia.CREDITO_RECUSADO, motivo);
            return;
        }

        conta.creditar(msg.getValor());
        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idConta", msg.getIdDestino());
        detalhes.put("valor", msg.getValor());
        detalhes.put("origemAgencia", msg.getAgenciaOrigem());
        detalhes.put("idOrigem", msg.getIdOrigem());
        detalhes.put("idTransferencia", msg.getIdTransferencia());
        detalhes.put("idMensagem", msg.getIdMensagem());
        registro.registrar("TRANSFERENCIA_CREDITO_REMOTO", recebimento, detalhes);
        responder(msg, MensagemTransferencia.CREDITO_CONFIRMADO, null);
    }

    private void responder(MensagemTransferencia pedido, String tipo, String motivo) {
        int[] envio = relogio.aoEnviar();
        MensagemTransferencia resposta = pedido.resposta(tipo, motivo, envio);
        publicador.publicarResposta(pedido.getAgenciaOrigem(), resposta);

        Map<String, Object> detalhes = base(resposta);
        detalhes.put("tipoMensagem", tipo);
        detalhes.put("paraAgencia", pedido.getAgenciaOrigem());
        registro.registrar("MENSAGEM_ENVIADA", envio, detalhes);
    }

    // Lado da origem
    private void concluir(MensagemTransferencia msg) {
        int[] recebimento = relogio.aoReceber(msg.getVetorEnvio());
        Transferencia t = transferencias.buscar(msg.getIdTransferencia());
        if (t != null) t.finalizar(Transferencia.CONCLUIDA, null);
        registro.registrar("TRANSFERENCIA_CONFIRMADA", recebimento, base(msg));
    }

    private void estornar(MensagemTransferencia msg) {
        int[] recebimento = relogio.aoReceber(msg.getVetorEnvio());
        Conta origem = estado.getContas().get(msg.getIdOrigem());
        if (origem != null) origem.creditar(msg.getValor());

        Transferencia t = transferencias.buscar(msg.getIdTransferencia());
        if (t != null) t.finalizar(Transferencia.ESTORNADA, msg.getMotivo());

        Map<String, Object> detalhes = base(msg);
        detalhes.put("motivo", msg.getMotivo());
        if (origem != null) detalhes.put("novoSaldo", origem.getSaldo());
        registro.registrar("TRANSFERENCIA_ESTORNADA", recebimento, detalhes);
    }

    private Map<String, Object> base(MensagemTransferencia msg) {
        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idOrigem", msg.getIdOrigem());
        detalhes.put("idDestino", msg.getIdDestino());
        detalhes.put("valor", msg.getValor());
        detalhes.put("idTransferencia", msg.getIdTransferencia());
        detalhes.put("idMensagem", msg.getIdMensagem());
        return detalhes;
    }
}
