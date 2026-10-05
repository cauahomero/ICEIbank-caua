package com.iceibank.agencia.mensageria;

/** Estado de uma transferência entre agências, do ponto de vista da agência de origem. */
public class Transferencia {

    public static final String PENDENTE = "PENDENTE";
    public static final String CONCLUIDA = "CONCLUIDA";
    public static final String ESTORNADA = "ESTORNADA";

    private final String idTransferencia;
    private final int idOrigem;
    private final int idDestino;
    private final int agenciaDestino;
    private final double valor;
    private volatile String status = PENDENTE;
    private volatile String motivo;

    public Transferencia(String idTransferencia, int idOrigem, int idDestino, int agenciaDestino, double valor) {
        this.idTransferencia = idTransferencia;
        this.idOrigem = idOrigem;
        this.idDestino = idDestino;
        this.agenciaDestino = agenciaDestino;
        this.valor = valor;
    }

    public void finalizar(String novoStatus, String novoMotivo) {
        this.status = novoStatus;
        this.motivo = novoMotivo;
    }

    public String getIdTransferencia() { return idTransferencia; }
    public int getIdOrigem() { return idOrigem; }
    public int getIdDestino() { return idDestino; }
    public int getAgenciaDestino() { return agenciaDestino; }
    public double getValor() { return valor; }
    public String getStatus() { return status; }
    public String getMotivo() { return motivo; }
}
