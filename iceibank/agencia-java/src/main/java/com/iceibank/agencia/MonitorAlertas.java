package com.iceibank.agencia;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.iceibank.agencia.mensageria.MensageriaConfig;
import com.rabbitmq.client.Channel;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.ConnectionFactory;
import com.rabbitmq.client.DeliverCallback;

import javax.net.ssl.SSLContext;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/**
 * Assinante do tópico de alertas: escuta os alertas de saldo baixo de TODAS as agências.
 * Roda separado das agências, usando a mesma RABBITMQ_URL.
 */
public class MonitorAlertas {

    private static final DateTimeFormatter HORA = DateTimeFormatter.ofPattern("HH:mm:ss").withZone(ZoneId.systemDefault());

    public static void main(String[] args) throws Exception {
        String url = System.getenv().getOrDefault("RABBITMQ_URL", "amqp://iceibank:iceibank@localhost:5672");
        ConnectionFactory fabrica = new ConnectionFactory();
        // setUri com amqps:// aceitaria qualquer certificado; então a URL entra como amqp://
        // e o TLS é ligado à parte, validando o certificado do servidor (ex.: CloudAMQP)
        boolean tls = url.startsWith("amqps://");
        fabrica.setUri(tls ? "amqp://" + url.substring("amqps://".length()) : url);
        if (tls) {
            if (new URI(url).getPort() == -1) fabrica.setPort(ConnectionFactory.DEFAULT_AMQP_OVER_SSL_PORT);
            fabrica.useSslProtocol(SSLContext.getDefault());
            fabrica.enableHostnameVerification();
        }

        Connection conexao = fabrica.newConnection("monitor-alertas");
        Channel canal = conexao.createChannel();
        // Declara de novo (idempotente) para o monitor poder subir antes das agências
        canal.exchangeDeclare(MensageriaConfig.EXCHANGE, "topic", true);
        canal.queueDeclare(MensageriaConfig.FILA_ALERTAS, true, false, false, null);
        canal.queueBind(MensageriaConfig.FILA_ALERTAS, MensageriaConfig.EXCHANGE, MensageriaConfig.PADRAO_ALERTAS);

        System.out.println("=== Monitor de alertas de saldo baixo ===");
        System.out.println("Fila " + MensageriaConfig.FILA_ALERTAS + " assinando '" + MensageriaConfig.PADRAO_ALERTAS
                + "' na exchange " + MensageriaConfig.EXCHANGE + ". Ctrl+C para sair.");

        ObjectMapper mapper = new ObjectMapper();
        DeliverCallback aoReceber = (tag, entrega) -> {
            JsonNode a = mapper.readTree(new String(entrega.getBody(), StandardCharsets.UTF_8));
            System.out.printf(Locale.forLanguageTag("pt-BR"),
                    "[%s] ALERTA agencia %d | conta %d (%s) ficou com R$ %.2f apos %s (limite R$ %.2f) | vetor %s | routing key %s%n",
                    HORA.format(Instant.parse(a.get("horaParede").asText())),
                    a.get("agencia").asInt(), a.get("idConta").asInt(), a.get("nomeAluno").asText(),
                    a.get("saldo").asDouble(), a.get("operacao").asText(), a.get("limite").asDouble(),
                    a.get("timestampVetorial"), entrega.getEnvelope().getRoutingKey());
            canal.basicAck(entrega.getEnvelope().getDeliveryTag(), false);
        };
        canal.basicConsume(MensageriaConfig.FILA_ALERTAS, false, aoReceber, tag -> { });
    }
}
