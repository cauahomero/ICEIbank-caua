package com.iceibank.agencia;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.iceibank.agencia.relogio.RelogioVetorial;

import java.io.IOException;
import java.nio.charset.MalformedInputException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

/**
 * Junta os logs das agências numa linha do tempo e usa o relógio vetorial para classificar
 * pares de eventos de agências diferentes:
 *   MesclarLogs        -> linha do tempo, pares concorrentes e pares causais ligados por mensagem
 *   MesclarLogs 4 9    -> compara só os eventos #4 e #9
 */
public class MesclarLogs {

    public static void main(String[] args) {
        List<JsonNode> eventos;
        try {
            eventos = lerEventos(Paths.get("data"));
        } catch (IOException e) {
            System.err.println("Erro ao ler os arquivos: " + e.getMessage());
            return;
        }

        if (args.length == 2) {
            compararDois(eventos, Integer.parseInt(args[0]), Integer.parseInt(args[1]));
            return;
        }

        System.out.println("=== Linha do tempo (ordenada por hora de parede) ===");
        for (int i = 0; i < eventos.size(); i++) {
            System.out.println(descrever(eventos, i) + " " + eventos.get(i).get("detalhes"));
        }

        System.out.println();
        System.out.println("=== Pares de eventos CONCORRENTES entre agencias diferentes ===");
        int concorrentes = 0;
        for (int i = 0; i < eventos.size(); i++) {
            for (int j = i + 1; j < eventos.size(); j++) {
                if (mesmaAgencia(eventos.get(i), eventos.get(j))) continue;
                if (RelogioVetorial.comparar(vetor(eventos.get(i)), vetor(eventos.get(j))) == 0) {
                    System.out.println(descrever(eventos, i) + "  ||  " + descrever(eventos, j));
                    concorrentes++;
                }
            }
        }
        if (concorrentes == 0) {
            System.out.println("(nenhum par concorrente encontrado - gere eventos em agencias diferentes sem transferencia entre elas)");
        }

        // Os pares ligados por uma mensagem (mesmo idTransferencia) são o contraexemplo:
        // o envio sempre aparece como causa do recebimento, nunca como concorrente
        System.out.println();
        System.out.println("=== Pares CAUSAIS entre agencias ligados pela mesma transferencia ===");
        int causais = 0;
        for (int i = 0; i < eventos.size(); i++) {
            for (int j = i + 1; j < eventos.size(); j++) {
                JsonNode a = eventos.get(i);
                JsonNode b = eventos.get(j);
                if (mesmaAgencia(a, b) || !mesmaTransferencia(a, b)) continue;
                int relacao = RelogioVetorial.comparar(vetor(a), vetor(b));
                if (relacao < 0) System.out.println(descrever(eventos, i) + "  ->  " + descrever(eventos, j));
                if (relacao > 0) System.out.println(descrever(eventos, j) + "  ->  " + descrever(eventos, i));
                if (relacao != 0) causais++;
            }
        }
        if (causais == 0) System.out.println("(nenhuma transferencia entre agencias nos logs)");

        System.out.println();
        System.out.printf("%d eventos, %d pares concorrentes, %d pares causais ligados por mensagem.%n",
                eventos.size(), concorrentes, causais);
        System.out.println("Para comparar dois eventos especificos: MesclarLogs <n1> <n2>");
    }

    private static List<JsonNode> lerEventos(Path pastaDados) throws IOException {
        List<JsonNode> eventos = new ArrayList<>();
        int semVetor = 0;
        ObjectMapper mapper = new ObjectMapper();
        try (Stream<Path> stream = Files.list(pastaDados)) {
            for (Path arquivo : stream.filter(p -> p.toString().endsWith(".jsonl")).toList()) {
                for (String linha : lerLinhas(arquivo)) {
                    if (linha.isBlank()) continue;
                    JsonNode evento = mapper.readTree(linha);
                    // Linhas do Sprint 1 só têm timestampLamport e não dá para compará-las
                    if (evento.has("timestampVetorial")) eventos.add(evento);
                    else semVetor++;
                }
            }
        }
        if (semVetor > 0) {
            System.out.println("(" + semVetor + " eventos antigos, sem timestampVetorial, foram ignorados)");
        }
        eventos.sort(Comparator.comparing(e -> e.get("horaParede").asText()));
        return eventos;
    }

    // Logs gravados antes da correção usavam a codificação padrão do Windows, não UTF-8
    private static List<String> lerLinhas(Path arquivo) throws IOException {
        try {
            return Files.readAllLines(arquivo, StandardCharsets.UTF_8);
        } catch (MalformedInputException e) {
            return Files.readAllLines(arquivo, StandardCharsets.ISO_8859_1);
        }
    }

    private static void compararDois(List<JsonNode> eventos, int n1, int n2) {
        if (n1 < 1 || n2 < 1 || n1 > eventos.size() || n2 > eventos.size()) {
            System.err.println("Os numeros devem estar entre 1 e " + eventos.size() + ".");
            return;
        }
        System.out.println(descrever(eventos, n1 - 1));
        System.out.println(descrever(eventos, n2 - 1));
        int[] a = vetor(eventos.get(n1 - 1));
        int[] b = vetor(eventos.get(n2 - 1));
        int relacao = RelogioVetorial.comparar(a, b);
        if (Arrays.equals(a, b)) System.out.println("=> vetores iguais (mesmo evento)");
        else if (relacao < 0) System.out.printf("=> #%d -> #%d: #%d aconteceu antes e pode ter causado #%d%n", n1, n2, n1, n2);
        else if (relacao > 0) System.out.printf("=> #%d -> #%d: #%d aconteceu antes e pode ter causado #%d%n", n2, n1, n2, n1);
        else System.out.printf("=> #%d || #%d: concorrentes, nenhum influenciou o outro%n", n1, n2);
    }

    private static String descrever(List<JsonNode> eventos, int i) {
        JsonNode e = eventos.get(i);
        return String.format("#%d [%s] vetor=%s %s", i + 1, e.get("agencia").asText(),
                Arrays.toString(vetor(e)).replace(" ", ""), e.get("tipo").asText());
    }

    private static int[] vetor(JsonNode evento) {
        JsonNode v = evento.get("timestampVetorial");
        int[] resultado = new int[v.size()];
        for (int k = 0; k < v.size(); k++) resultado[k] = v.get(k).asInt();
        return resultado;
    }

    private static boolean mesmaAgencia(JsonNode a, JsonNode b) {
        return a.get("agencia").asText().equals(b.get("agencia").asText());
    }

    private static boolean mesmaTransferencia(JsonNode a, JsonNode b) {
        JsonNode ta = a.get("detalhes").get("idTransferencia");
        JsonNode tb = b.get("detalhes").get("idTransferencia");
        return ta != null && tb != null && ta.asText().equals(tb.asText());
    }
}
