package com.iceibank.agencia.alerta;

import com.iceibank.agencia.config.AgenciaState;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.mensageria.MensageriaConfig;
import com.iceibank.agencia.model.Conta;
import com.iceibank.agencia.relogio.RelogioVetorial;
import org.springframework.amqp.AmqpException;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Depois de uma operação que tira dinheiro da conta, publica um alerta se o saldo
 * ficou abaixo do limite. O alerta vai para um tópico separado das transferências
 * (alerta.saldo-baixo.agencia.N), e quem quiser ser avisado assina esse tópico.
 */
@Component
public class AlertasSaldo {

    private final AgenciaState estado;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final RabbitTemplate rabbitTemplate;
    private final double limite;

    public AlertasSaldo(AgenciaState estado, RelogioVetorial relogio, RegistroEventos registro,
                        RabbitTemplate rabbitTemplate, @Value("${alerta.saldo-baixo.limite}") double limite) {
        this.estado = estado;
        this.relogio = relogio;
        this.registro = registro;
        this.rabbitTemplate = rabbitTemplate;
        this.limite = limite;
    }

    public void verificar(Conta conta, String operacao) {
        if (conta.getSaldo() >= limite) return;

        int[] vetor = relogio.aoEnviar();
        AlertaSaldoBaixo alerta = new AlertaSaldoBaixo(estado.getIdAgencia(), conta.getId(), conta.getNomeAluno(),
                operacao, conta.getSaldo(), limite, vetor);

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", conta.getId());
        detalhes.put("operacao", operacao);
        detalhes.put("saldo", conta.getSaldo());
        detalhes.put("limite", limite);
        try {
            rabbitTemplate.convertAndSend(MensageriaConfig.EXCHANGE,
                    MensageriaConfig.chaveAlertaSaldoBaixo(estado.getIdAgencia()), alerta);
        } catch (AmqpException e) {
            // O alerta é só informativo: sem broker, a operação do cliente não deve falhar por causa dele
            detalhes.put("erro", "alerta não publicado: " + e.getMessage());
        }
        registro.registrar("ALERTA_SALDO_BAIXO", vetor, detalhes);
    }
}
