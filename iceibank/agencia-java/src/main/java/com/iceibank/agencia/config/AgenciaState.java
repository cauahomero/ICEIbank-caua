package com.iceibank.agencia.config;

import com.iceibank.agencia.model.Conta;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Equivalente ao app.locals do Express: estado compartilhado desta agência
 * (id, contas em memória), único por processo já que é um bean singleton.
 */
@Component
public class AgenciaState {
    private final int idAgencia;
    private final Map<Integer, Conta> contas = new ConcurrentHashMap<>();

    public AgenciaState(@Value("${agencia.id}") int idAgencia) {
        this.idAgencia = idAgencia;
    }

    public int getIdAgencia() {
        return idAgencia;
    }

    public Map<Integer, Conta> getContas() {
        return contas;
    }
}
