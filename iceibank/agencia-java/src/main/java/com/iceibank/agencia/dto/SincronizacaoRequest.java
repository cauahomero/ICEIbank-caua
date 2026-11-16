package com.iceibank.agencia.dto;

/** Operação feita pelo app enquanto estava offline: DEPOSITO, SAQUE ou TRANSFERENCIA (esta usa idDestino). */
public class SincronizacaoRequest {
    private String tipo;
    private double valor;
    private Integer idDestino;
    private int[] vetorConhecido;

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public double getValor() {
        return valor;
    }

    public void setValor(double valor) {
        this.valor = valor;
    }

    public Integer getIdDestino() {
        return idDestino;
    }

    public void setIdDestino(Integer idDestino) {
        this.idDestino = idDestino;
    }

    public int[] getVetorConhecido() {
        return vetorConhecido;
    }

    public void setVetorConhecido(int[] vetorConhecido) {
        this.vetorConhecido = vetorConhecido;
    }
}
