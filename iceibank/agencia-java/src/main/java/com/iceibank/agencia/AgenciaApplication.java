package com.iceibank.agencia;

import com.iceibank.agencia.config.AgenciasConfig;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AgenciaApplication {

    public static void main(String[] args) {
        int idAgencia = Integer.parseInt(System.getenv().getOrDefault("AGENCIA_ID", "0"));

        if (idAgencia < 0 || idAgencia >= AgenciasConfig.NUMERO_AGENCIAS) {
            System.err.println("Agência " + idAgencia + " não configurada (esperado 0 a " + (AgenciasConfig.NUMERO_AGENCIAS - 1) + ").");
            System.exit(1);
        }

        int porta = AgenciasConfig.PORTA_BASE + idAgencia;
        System.setProperty("server.port", String.valueOf(porta));
        System.setProperty("agencia.id", String.valueOf(idAgencia));

        SpringApplication.run(AgenciaApplication.class, args);
        System.out.println("[Agência " + idAgencia + "] ouvindo na porta " + porta);
    }
}
