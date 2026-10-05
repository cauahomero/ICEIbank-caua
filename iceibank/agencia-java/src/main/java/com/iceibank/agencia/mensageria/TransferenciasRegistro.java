package com.iceibank.agencia.mensageria;

import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Transferências entre agências iniciadas por esta agência, para consultar o status. */
@Component
public class TransferenciasRegistro {
    private final Map<String, Transferencia> transferencias = new ConcurrentHashMap<>();

    public void adicionar(Transferencia t) {
        transferencias.put(t.getIdTransferencia(), t);
    }

    public Transferencia buscar(String idTransferencia) {
        return transferencias.get(idTransferencia);
    }
}
