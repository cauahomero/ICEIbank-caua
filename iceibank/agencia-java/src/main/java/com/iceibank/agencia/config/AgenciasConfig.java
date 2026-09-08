package com.iceibank.agencia.config;

public final class AgenciasConfig {

    public static final int OFFSET = 6;
    public static final int NUMERO_AGENCIAS = 3;
    public static final int PORTA_BASE = 4000 + OFFSET;

    private AgenciasConfig() {
    }

    public static String urlAgencia(int idAgencia) {
        return "http://localhost:" + (PORTA_BASE + idAgencia);
    }

    public static int agenciaResponsavel(int idConta) {
        return idConta % NUMERO_AGENCIAS;
    }
}
