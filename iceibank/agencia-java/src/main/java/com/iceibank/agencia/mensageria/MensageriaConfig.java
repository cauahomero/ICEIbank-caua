package com.iceibank.agencia.mensageria;

import com.iceibank.agencia.config.AgenciasConfig;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Declarable;
import org.springframework.amqp.core.Declarables;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.support.converter.DefaultJackson2JavaTypeMapper;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.ArrayList;
import java.util.List;

/**
 * Exchange topic "iceibank.eventos" com uma fila durável por agência.
 * A fila da agência N recebe:
 *   agencia.N.creditar  -> pedidos de crédito vindos de outras agências
 *   agencia.N.resposta  -> confirmações/recusas das transferências que ela iniciou
 */
@Configuration
public class MensageriaConfig {

    public static final String EXCHANGE = "iceibank.eventos";

    // Funcionalidade adicional: alertas de saldo baixo num tópico separado, com uma fila
    // própria que recebe os alertas de todas as agências (o "#" casa qualquer sufixo)
    public static final String FILA_ALERTAS = "fila-alertas";
    public static final String PADRAO_ALERTAS = "alerta.#";

    public static String chaveAlertaSaldoBaixo(int idAgencia) {
        return "alerta.saldo-baixo.agencia." + idAgencia;
    }

    public static String fila(int idAgencia) {
        return "fila-agencia-" + idAgencia;
    }

    public static String chaveCredito(int idAgencia) {
        return "agencia." + idAgencia + ".creditar";
    }

    public static String chaveResposta(int idAgencia) {
        return "agencia." + idAgencia + ".resposta";
    }

    // Toda agência declara as filas de todas: se a agência de destino nunca subiu,
    // a fila dela já existe e a mensagem fica retida em vez de ser descartada.
    @Bean
    public Declarables filasDasAgencias() {
        TopicExchange exchange = new TopicExchange(EXCHANGE, true, false);
        List<Declarable> declaraveis = new ArrayList<>();
        declaraveis.add(exchange);
        for (int i = 0; i < AgenciasConfig.NUMERO_AGENCIAS; i++) {
            Queue fila = QueueBuilder.durable(fila(i)).build();
            declaraveis.add(fila);
            declaraveis.add(BindingBuilder.bind(fila).to(exchange).with(chaveCredito(i)));
            declaraveis.add(BindingBuilder.bind(fila).to(exchange).with(chaveResposta(i)));
        }
        Queue filaAlertas = QueueBuilder.durable(FILA_ALERTAS).build();
        declaraveis.add(filaAlertas);
        declaraveis.add(BindingBuilder.bind(filaAlertas).to(exchange).with(PADRAO_ALERTAS));
        return new Declarables(declaraveis);
    }

    @Bean
    public MessageConverter conversorJson() {
        Jackson2JsonMessageConverter conversor = new Jackson2JsonMessageConverter();
        DefaultJackson2JavaTypeMapper mapeador = new DefaultJackson2JavaTypeMapper();
        mapeador.setTrustedPackages("com.iceibank.agencia.mensageria");
        conversor.setJavaTypeMapper(mapeador);
        return conversor;
    }
}
