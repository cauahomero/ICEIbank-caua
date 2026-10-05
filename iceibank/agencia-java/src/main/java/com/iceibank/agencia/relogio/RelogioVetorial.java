package com.iceibank.agencia.relogio;

import com.iceibank.agencia.config.AgenciasConfig;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Relógio vetorial: uma posição por agência. A posição desta agência conta os eventos dela;
 * as outras guardam até qual evento de cada agência esta já "viu" (direta ou indiretamente).
 */
@Component
public class RelogioVetorial {
    private final int eu;
    private final int[] vetor = new int[AgenciasConfig.NUMERO_AGENCIAS];

    public RelogioVetorial(@Value("${agencia.id}") int idAgencia) {
        this.eu = idAgencia;
    }

    public synchronized int[] eventoLocal() {
        vetor[eu] += 1;
        return vetor.clone();
    }

    public synchronized int[] aoEnviar() {
        vetor[eu] += 1;
        return vetor.clone();
    }

    public synchronized int[] aoReceber(int[] recebido) {
        for (int k = 0; k < vetor.length; k++) {
            vetor[k] = Math.max(vetor[k], recebido[k]);
        }
        vetor[eu] += 1;
        return vetor.clone();
    }

    /** -1 se a aconteceu antes de b, 1 se depois, 0 se são concorrentes (ou iguais). */
    public static int comparar(int[] a, int[] b) {
        boolean algumMenor = false;
        boolean algumMaior = false;
        for (int k = 0; k < a.length; k++) {
            if (a[k] < b[k]) algumMenor = true;
            if (a[k] > b[k]) algumMaior = true;
        }
        if (algumMenor && !algumMaior) return -1;
        if (algumMaior && !algumMenor) return 1;
        return 0;
    }
}
