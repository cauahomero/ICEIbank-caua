package com.iceibank.agencia.mensageria;

import org.springframework.amqp.AmqpException;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

/** Publica na exchange; lança AmqpException se o broker estiver fora do ar. */
@Component
public class PublicadorTransferencias {
    private final RabbitTemplate rabbitTemplate;

    public PublicadorTransferencias(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void publicarCredito(int agenciaDestino, MensagemTransferencia mensagem) throws AmqpException {
        rabbitTemplate.convertAndSend(MensageriaConfig.EXCHANGE, MensageriaConfig.chaveCredito(agenciaDestino), mensagem);
    }

    public void publicarResposta(int agenciaOrigem, MensagemTransferencia mensagem) throws AmqpException {
        rabbitTemplate.convertAndSend(MensageriaConfig.EXCHANGE, MensageriaConfig.chaveResposta(agenciaOrigem), mensagem);
    }
}
