package com.iceibank.agencia.dto;

public class CreditarRemotoRequest {
    private double valor;
    private int[] vetorEnvio;
    private int origemAgencia;

    public double getValor() {
        return valor;
    }

    public void setValor(double valor) {
        this.valor = valor;
    }

    public int[] getVetorEnvio() {
        return vetorEnvio;
    }

    public void setVetorEnvio(int[] vetorEnvio) {
        this.vetorEnvio = vetorEnvio;
    }

    public int getOrigemAgencia() {
        return origemAgencia;
    }

    public void setOrigemAgencia(int origemAgencia) {
        this.origemAgencia = origemAgencia;
    }
}
