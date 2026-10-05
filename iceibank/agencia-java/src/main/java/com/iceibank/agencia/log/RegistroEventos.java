package com.iceibank.agencia.log;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class RegistroEventos {
    private static final Map<String, String> CAMPO_CONTA = Map.of(
            "CRIAR_CONTA", "id",
            "DEPOSITO", "id",
            "SAQUE", "id",
            "RENDIMENTO_CDB", "id",
            "TRANSFERENCIA_DEBITO", "idOrigem",
            "TRANSFERENCIA_CREDITO", "idDestino",
            "TRANSFERENCIA_FALHOU", "idOrigem",
            "TRANSFERENCIA_CREDITO_REMOTO", "idConta"
    );

    private final String nomeAgencia;
    private final Path caminhoArquivo;
    private final List<Map<String, Object>> eventosEmMemoria = new ArrayList<>();

    public RegistroEventos(@Value("${agencia.id}") String idAgencia) throws IOException {
        this.nomeAgencia = "agencia-" + idAgencia;
        Path pastaDados = Paths.get("data");
        Files.createDirectories(pastaDados);
        this.caminhoArquivo = pastaDados.resolve("eventos-" + nomeAgencia + ".jsonl");
    }

    public synchronized Map<String, Object> registrar(String tipo, int timestampLamport, Map<String, Object> detalhes) {
        Map<String, Object> evento = new LinkedHashMap<>();
        evento.put("agencia", nomeAgencia);
        evento.put("tipo", tipo);
        evento.put("timestampLamport", timestampLamport);
        evento.put("horaParede", Instant.now().toString());
        evento.put("detalhes", detalhes);

        String linha = paraJson(evento);
        try (FileWriter writer = new FileWriter(caminhoArquivo.toFile(), true)) {
            writer.write(linha + System.lineSeparator());
        } catch (IOException e) {
            throw new RuntimeException("Falha ao gravar log de eventos", e);
        }
        eventosEmMemoria.add(evento);
        System.out.println("[Lamport " + timestampLamport + "] " + tipo + " " + detalhes);
        return evento;
    }

    public synchronized List<Map<String, Object>> eventosDaConta(int idConta, int limite) {
        List<Map<String, Object>> resultado = new ArrayList<>();
        for (int i = eventosEmMemoria.size() - 1; i >= 0 && resultado.size() < limite; i--) {
            Map<String, Object> evento = eventosEmMemoria.get(i);
            String campo = CAMPO_CONTA.get((String) evento.get("tipo"));
            Map<?, ?> detalhes = (Map<?, ?>) evento.get("detalhes");
            if (campo != null && Integer.valueOf(idConta).equals(detalhes.get(campo))) {
                resultado.add(evento);
            }
        }
        return resultado;
    }

    @SuppressWarnings("unchecked")
    private String paraJson(Object valor) {
        if (valor == null) {
            return "null";
        }
        if (valor instanceof Map) {
            StringBuilder sb = new StringBuilder("{");
            Map<String, Object> mapa = (Map<String, Object>) valor;
            boolean primeiro = true;
            for (Map.Entry<String, Object> entrada : mapa.entrySet()) {
                if (!primeiro) sb.append(",");
                sb.append("\"").append(entrada.getKey()).append("\":");
                sb.append(paraJson(entrada.getValue()));
                primeiro = false;
            }
            sb.append("}");
            return sb.toString();
        }
        if (valor instanceof Number) {
            return valor.toString();
        }
        String texto = valor.toString().replace("\\", "\\\\").replace("\"", "\\\"");
        return "\"" + texto + "\"";
    }
}
