package com.iceibank.agencia.alerta;

import java.time.Instant;

/** Evento publicado quando uma operação deixa o saldo de uma conta abaixo do limite. */
public class AlertaSaldoBaixo {
    private int agencia;
    private int idConta;
    private String nomeAluno;
    private String operacao;
    private double saldo;
    private double limite;
    private int[] timestampVetorial;
    private String horaParede = Instant.now().toString();

    public AlertaSaldoBaixo() {
    }

    public AlertaSaldoBaixo(int agencia, int idConta, String nomeAluno, String operacao, double saldo, double limite,
                            int[] timestampVetorial) {
        this.agencia = agencia;
        this.idConta = idConta;
        this.nomeAluno = nomeAluno;
        this.operacao = operacao;
        this.saldo = saldo;
        this.limite = limite;
        this.timestampVetorial = timestampVetorial;
    }

    public int getAgencia() { return agencia; }
    public void setAgencia(int agencia) { this.agencia = agencia; }
    public int getIdConta() { return idConta; }
    public void setIdConta(int idConta) { this.idConta = idConta; }
    public String getNomeAluno() { return nomeAluno; }
    public void setNomeAluno(String nomeAluno) { this.nomeAluno = nomeAluno; }
    public String getOperacao() { return operacao; }
    public void setOperacao(String operacao) { this.operacao = operacao; }
    public double getSaldo() { return saldo; }
    public void setSaldo(double saldo) { this.saldo = saldo; }
    public double getLimite() { return limite; }
    public void setLimite(double limite) { this.limite = limite; }
    public int[] getTimestampVetorial() { return timestampVetorial; }
    public void setTimestampVetorial(int[] timestampVetorial) { this.timestampVetorial = timestampVetorial; }
    public String getHoraParede() { return horaParede; }
    public void setHoraParede(String horaParede) { this.horaParede = horaParede; }
}
