package com.iceibank.agencia.model;

public class Conta {
    private int id;
    private String nomeAluno;
    private double saldo;

    public Conta() {
    }

    public Conta(int id, String nomeAluno, double saldo) {
        this.id = id;
        this.nomeAluno = nomeAluno;
        this.saldo = saldo;
    }

    public int getId() {
        return id;
    }

    public String getNomeAluno() {
        return nomeAluno;
    }

    public synchronized double getSaldo() {
        return saldo;
    }

    public synchronized void creditar(double valor) {
        this.saldo += valor;
    }

    public synchronized void debitar(double valor) {
        this.saldo -= valor;
    }
}
