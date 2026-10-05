package com.iceibank.agencia.mensageria;

import java.util.UUID;

/** Mensagem trocada entre agências durante uma transferência. */
public class MensagemTransferencia {

    public static final String CREDITO_SOLICITADO = "CREDITO_SOLICITADO";
    public static final String CREDITO_CONFIRMADO = "CREDITO_CONFIRMADO";
    public static final String CREDITO_RECUSADO = "CREDITO_RECUSADO";

    // Único por mensagem: é o que permite ignorar uma entrega repetida (idempotência)
    private String idMensagem;
    private String tipo;
    // Igual em todas as mensagens da mesma transferência (correlação)
    private String idTransferencia;
    private int agenciaOrigem;
    private int agenciaDestino;
    private int idOrigem;
    private int idDestino;
    private double valor;
    private String motivo;
    // Relógio vetorial da origem no momento do envio; o destino faz aoReceber com ele
    private int[] vetorEnvio;

    public static MensagemTransferencia solicitacao(String idTransferencia, int agenciaOrigem, int agenciaDestino,
                                                    int idOrigem, int idDestino, double valor, int[] vetorEnvio) {
        MensagemTransferencia m = new MensagemTransferencia();
        m.idMensagem = UUID.randomUUID().toString();
        m.tipo = CREDITO_SOLICITADO;
        m.idTransferencia = idTransferencia;
        m.agenciaOrigem = agenciaOrigem;
        m.agenciaDestino = agenciaDestino;
        m.idOrigem = idOrigem;
        m.idDestino = idDestino;
        m.valor = valor;
        m.vetorEnvio = vetorEnvio;
        return m;
    }

    /** Resposta do destino para a origem, sobre a mesma transferência (novo idMensagem). */
    public MensagemTransferencia resposta(String tipoResposta, String motivoResposta, int[] vetorEnvio) {
        MensagemTransferencia m = solicitacao(idTransferencia, agenciaOrigem, agenciaDestino,
                idOrigem, idDestino, valor, vetorEnvio);
        m.tipo = tipoResposta;
        m.motivo = motivoResposta;
        return m;
    }

    public String getIdMensagem() { return idMensagem; }
    public void setIdMensagem(String idMensagem) { this.idMensagem = idMensagem; }
    public String getTipo() { return tipo; }
    public void setTipo(String tipo) { this.tipo = tipo; }
    public String getIdTransferencia() { return idTransferencia; }
    public void setIdTransferencia(String idTransferencia) { this.idTransferencia = idTransferencia; }
    public int getAgenciaOrigem() { return agenciaOrigem; }
    public void setAgenciaOrigem(int agenciaOrigem) { this.agenciaOrigem = agenciaOrigem; }
    public int getAgenciaDestino() { return agenciaDestino; }
    public void setAgenciaDestino(int agenciaDestino) { this.agenciaDestino = agenciaDestino; }
    public int getIdOrigem() { return idOrigem; }
    public void setIdOrigem(int idOrigem) { this.idOrigem = idOrigem; }
    public int getIdDestino() { return idDestino; }
    public void setIdDestino(int idDestino) { this.idDestino = idDestino; }
    public double getValor() { return valor; }
    public void setValor(double valor) { this.valor = valor; }
    public String getMotivo() { return motivo; }
    public void setMotivo(String motivo) { this.motivo = motivo; }
    public int[] getVetorEnvio() { return vetorEnvio; }
    public void setVetorEnvio(int[] vetorEnvio) { this.vetorEnvio = vetorEnvio; }
}
