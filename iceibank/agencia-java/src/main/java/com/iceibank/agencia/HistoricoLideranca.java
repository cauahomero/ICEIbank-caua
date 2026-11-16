package com.iceibank.agencia;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Stream;

/**
 * Filtra os eventos do Bully nos logs das 3 agências e reconstrói a linha do tempo de lideranças.
 */
public class HistoricoLideranca {

    private static final Set<String> TIPOS_BULLY = Set.of(
            "ELEICAO_INICIADA", "ELEICAO_RECEBIDA", "TORNOU_LIDER", "LIDER_ANUNCIADO", "LIDER_NAO_RESPONDEU");

    private static final long PAUSA_NOVA_SUBIDA_S = 10;

    // Hora local, para bater com o Get-Date dos prints
    private static final DateTimeFormatter HORA =
            DateTimeFormatter.ofPattern("dd/MM HH:mm:ss.SSS").withZone(ZoneId.systemDefault());

    public static void main(String[] args) throws IOException {
        List<JsonNode> eventos = new ArrayList<>();
        ObjectMapper mapper = new ObjectMapper();
        try (Stream<Path> stream = Files.list(Paths.get("data"))) {
            for (Path arquivo : stream.filter(p -> p.toString().endsWith(".jsonl")).toList()) {
                for (String linha : MesclarLogs.lerLinhas(arquivo)) {
                    if (linha.isBlank()) continue;
                    JsonNode evento = mapper.readTree(linha);
                    if (TIPOS_BULLY.contains(evento.get("tipo").asText())) eventos.add(evento);
                }
            }
        }
        eventos.sort(Comparator.comparing(e -> Instant.parse(e.get("horaParede").asText())));

        if (eventos.isEmpty()) {
            System.out.println("Nenhum evento de eleição nos logs. Suba as agências antes (iniciar.cmd).");
            return;
        }

        System.out.println("=== Histórico de eventos de eleição ===");
        for (JsonNode e : eventos) {
            System.out.printf("(%s) [%s] %-19s %s%n", hora(e), e.get("agencia").asText(),
                    e.get("tipo").asText(), e.get("detalhes"));
        }

        System.out.println();
        System.out.println("=== Linha do tempo de líderes ===");
        for (JsonNode e : eventos) {
            String tipo = e.get("tipo").asText();
            if (tipo.equals("TORNOU_LIDER")) {
                System.out.printf("A partir de %s: Agência %d é a líder%n", hora(e), e.get("detalhes").get("idAgencia").asInt());
            } else if (tipo.equals("LIDER_NAO_RESPONDEU")) {
                System.out.printf("        (%s: %s percebeu que a Agência %d não responde)%n", hora(e),
                        e.get("agencia").asText(), e.get("detalhes").get("liderAtual").asInt());
            }
        }

        // Anúncios seguidos da mesma líder (a "tempestade" da subida) viram uma linha só.
        // Uma pausa longa entre dois anúncios indica outra subida do ambiente, que vira outra linha.
        System.out.println();
        System.out.println("=== Trocas de liderança (anúncios repetidos agrupados) ===");
        Integer liderAnterior = null;
        Instant ultimo = null;
        int repeticoes = 0;
        String desde = null;
        for (JsonNode e : eventos) {
            if (!e.get("tipo").asText().equals("TORNOU_LIDER")) continue;
            int lider = e.get("detalhes").get("idAgencia").asInt();
            Instant instante = Instant.parse(e.get("horaParede").asText());
            boolean mesmaRajada = ultimo != null && instante.minusSeconds(PAUSA_NOVA_SUBIDA_S).isBefore(ultimo);
            ultimo = instante;
            if (liderAnterior != null && lider == liderAnterior && mesmaRajada) {
                repeticoes++;
                continue;
            }
            imprimirTrecho(desde, liderAnterior, repeticoes);
            liderAnterior = lider;
            repeticoes = 1;
            desde = hora(e);
        }
        imprimirTrecho(desde, liderAnterior, repeticoes);
    }

    private static void imprimirTrecho(String desde, Integer lider, int repeticoes) {
        if (lider == null) return;
        System.out.printf("%s -> Agência %d (TORNOU_LIDER %dx)%n", desde, lider, repeticoes);
    }

    private static String hora(JsonNode evento) {
        return HORA.format(Instant.parse(evento.get("horaParede").asText()));
    }
}
