package com.iceibank.agencia.relogio;

/**
 * Relação entre dois vetores, a mesma lógica do MesclarLogs, mas separando IGUAIS de CONCORRENTES
 * (o RelogioVetorial.comparar devolve 0 para os dois casos, e a sincronização precisa distinguir).
 */
public final class CompararVetores {

    public enum Relacao { IGUAIS, ANTES, DEPOIS, CONCORRENTES }

    private CompararVetores() {
    }

    public static Relacao comparar(int[] v1, int[] v2) {
        boolean v1MenorOuIgual = true;
        boolean v2MenorOuIgual = true;
        for (int i = 0; i < v1.length; i++) {
            if (v1[i] > v2[i]) v1MenorOuIgual = false;
            if (v2[i] > v1[i]) v2MenorOuIgual = false;
        }
        if (v1MenorOuIgual && v2MenorOuIgual) return Relacao.IGUAIS;
        if (v1MenorOuIgual) return Relacao.ANTES;
        if (v2MenorOuIgual) return Relacao.DEPOIS;
        return Relacao.CONCORRENTES;
    }
}
