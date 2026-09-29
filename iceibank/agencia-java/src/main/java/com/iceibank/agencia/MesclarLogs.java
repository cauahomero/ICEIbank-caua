package com.iceibank.agencia;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

public class MesclarLogs {

    public static void main(String[] args) {
        
        Path pastaDados = Paths.get("data");
        List<JsonNode> todosEventos = new ArrayList<>();
        ObjectMapper mapper = new ObjectMapper();

        try {
            try (Stream<Path> stream = Files.list(pastaDados)) {
                List<Path> arquivos = stream
                        .filter(p -> p.toString().endsWith(".jsonl"))
                        .toList();

                for (Path arquivo : arquivos) {
                    List<String> linhas = Files.readAllLines(arquivo);
                    for (String linha : linhas) {
                        if (!linha.isBlank()) {
                            JsonNode evento = mapper.readTree(linha);
                            todosEventos.add(evento);
                        }
                    }
                }
            }

            todosEventos.sort(Comparator.comparingLong(
                e -> e.get("timestampLamport").asLong()
            ));

            System.out.println("=== Linha do tempo unificada (ordenada por relogio de Lamport) ===");
            for (JsonNode evento : todosEventos) {
                long lamport = evento.get("timestampLamport").asLong();
                String horaParede = evento.get("horaParede").asText();
                String agencia = evento.get("agencia").asText();
                String tipo = evento.get("tipo").asText();
                String detalhes = evento.get("detalhes").toString();

                System.out.printf("[Lamport %d] (%s) %s - %s %s%n",
                        lamport, horaParede, agencia, tipo, detalhes);
            }

        } catch (IOException e) {
            System.err.println("Erro ao ler os arquivos: " + e.getMessage());
        }
    }
}