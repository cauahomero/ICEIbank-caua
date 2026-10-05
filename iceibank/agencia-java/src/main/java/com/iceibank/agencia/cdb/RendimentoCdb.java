package com.iceibank.agencia.cdb;

import com.iceibank.agencia.config.AgenciaState;
import com.iceibank.agencia.lamport.RelogioLamport;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Rende as contas como um CDB: enquanto a agência está no ar, a cada intervalo
 * cada conta com saldo positivo recebe um percentual do próprio saldo.
 * Cada agência só rende as contas que estão sob sua responsabilidade.
 */
@Component
public class RendimentoCdb {

    private final AgenciaState estado;
    private final RelogioLamport relogio;
    private final RegistroEventos registro;
    private final double taxa;

    public RendimentoCdb(AgenciaState estado, RelogioLamport relogio, RegistroEventos registro,
                         @Value("${cdb.taxa}") double taxa) {
        this.estado = estado;
        this.relogio = relogio;
        this.registro = registro;
        this.taxa = taxa;
    }

    @Scheduled(fixedRateString = "${cdb.intervalo-ms}", initialDelayString = "${cdb.intervalo-ms}")
    public void aplicarRendimento() {
        for (Conta conta : estado.getContas().values()) {
            // Arredonda para centavos; saldos muito pequenos não chegam a render 1 centavo
            double rendimento = Math.round(conta.getSaldo() * taxa * 100) / 100.0;
            if (rendimento <= 0) continue;

            int ts = relogio.eventoLocal();
            conta.creditar(rendimento);

            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("id", conta.getId());
            detalhes.put("valor", rendimento);
            detalhes.put("taxa", taxa);
            detalhes.put("novoSaldo", conta.getSaldo());
            registro.registrar("RENDIMENTO_CDB", ts, detalhes);
        }
    }
}
