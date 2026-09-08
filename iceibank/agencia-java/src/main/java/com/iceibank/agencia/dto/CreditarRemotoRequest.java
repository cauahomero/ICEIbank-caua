package com.iceibank.agencia.dto;

public class CreditarRemotoRequest {
    private double valor;
    private int timestampLamport;
    private int origemAgencia;

    public double getValor() {
        return valor;
    }

    public void setValor(double valor) {
        this.valor = valor;
    }

    public int getTimestampLamport() {
        return timestampLamport;
    }

    public void setTimestampLamport(int timestampLamport) {
        this.timestampLamport = timestampLamport;
    }

    public int getOrigemAgencia() {
        return origemAgencia;
    }

    public void setOrigemAgencia(int origemAgencia) {
        this.origemAgencia = origemAgencia;
    }
}
