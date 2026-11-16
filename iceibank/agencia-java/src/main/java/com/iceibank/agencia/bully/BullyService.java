package com.iceibank.agencia.bully;

import com.iceibank.agencia.config.AgenciasConfig;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.relogio.RelogioVetorial;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

@Component
public class BullyService {

    private static final int TIMEOUT_MS = 1000;

    private final int idAgencia;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final RestClient http;
    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "bully");
        t.setDaemon(true);
        return t;
    });

    private volatile Integer liderAtual = null;
    private final AtomicBoolean eleicaoEmAndamento = new AtomicBoolean(false);

    public BullyService(@Value("${agencia.id}") int idAgencia, RelogioVetorial relogio, RegistroEventos registro) {
        this.idAgencia = idAgencia;
        this.relogio = relogio;
        this.registro = registro;

        SimpleClientHttpRequestFactory fabrica = new SimpleClientHttpRequestFactory();
        fabrica.setConnectTimeout(TIMEOUT_MS);
        fabrica.setReadTimeout(TIMEOUT_MS);
        this.http = RestClient.builder().requestFactory(fabrica).build();
    }

    @EventListener(ApplicationReadyEvent.class)
    public void aoSubir() {
        dispararEleicao();
    }

    public void dispararEleicao() {
        executor.submit(this::iniciarEleicao);
    }

    void iniciarEleicao() {
        if (!eleicaoEmAndamento.compareAndSet(false, true)) return;
        boolean alguemRespondeu = false;
        try {
            registro.registrar("ELEICAO_INICIADA", relogio.eventoLocal(), Map.of("idAgencia", idAgencia));

            for (int id = idAgencia + 1; id < AgenciasConfig.NUMERO_AGENCIAS; id++) {
                if (enviar(id, "/bully/eleicao", Map.of("origemId", idAgencia, "vetorEnvio", relogio.aoEnviar()))) {
                    alguemRespondeu = true;
                }
            }
        } finally {
            eleicaoEmAndamento.set(false);
        }

        if (!alguemRespondeu) {
            tornarMeLider();
        }
    }

    private void tornarMeLider() {
        liderAtual = idAgencia;
        registro.registrar("TORNOU_LIDER", relogio.eventoLocal(), Map.of("idAgencia", idAgencia));
        for (int id = 0; id < AgenciasConfig.NUMERO_AGENCIAS; id++) {
            if (id == idAgencia) continue;
            enviar(id, "/bully/coordenador", Map.of("liderId", idAgencia, "vetorEnvio", relogio.aoEnviar()));
        }
    }

    public void receberEleicao(int origemId, int[] vetorRecebido) {
        int[] vetor = relogio.aoReceber(vetorRecebido);
        registro.registrar("ELEICAO_RECEBIDA", vetor, Map.of("de", origemId, "minhaId", idAgencia));
        dispararEleicao();
    }

    public void receberCoordenador(int liderId, int[] vetorRecebido) {
        liderAtual = liderId;
        int[] vetor = relogio.aoReceber(vetorRecebido);
        registro.registrar("LIDER_ANUNCIADO", vetor, Map.of("liderId", liderId, "agencia", idAgencia));
    }

    // Heartbeat: fixedDelay espera a verificação anterior terminar antes de agendar a próxima
    @Scheduled(initialDelay = 3000, fixedDelay = 3000)
    public void verificarLider() {
        Integer lider = liderAtual;
        if (lider == null) {
            iniciarEleicao();
            return;
        }
        if (lider == idAgencia) return;

        try {
            http.get().uri(urlAgencia(lider) + "/bully/lider").retrieve().toBodilessEntity();
        } catch (Exception e) {
            registro.registrar("LIDER_NAO_RESPONDEU", relogio.eventoLocal(), Map.of("liderAtual", lider, "agencia", idAgencia));
            liderAtual = null;
            iniciarEleicao();
        }
    }

    public Integer obterLiderAtual() {
        return liderAtual;
    }

    public int getIdAgencia() {
        return idAgencia;
    }

    static String urlAgencia(int id) {
        return "http://localhost:" + (AgenciasConfig.PORTA_BASE + id);
    }

    private boolean enviar(int id, String rota, Map<String, Object> corpo) {
        try {
            http.post().uri(urlAgencia(id) + rota).body(corpo).retrieve().toBodilessEntity();
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
