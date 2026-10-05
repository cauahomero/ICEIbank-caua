package com.iceibank.agencia.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Service
public class JwtService {

    public static final String TIPO_USUARIO = "usuario";
    public static final String TIPO_AGENCIA = "agencia";

    private static final long EXPIRACAO_SERVICO_SEGUNDOS = 60;

    private final SecretKey chave;
    private final long expiracaoSegundos;

    public JwtService(@Value("${jwt.segredo}") String segredo,
                      @Value("${jwt.expiracao-segundos}") long expiracaoSegundos) {
        this.chave = Keys.hmacShaKeyFor(segredo.getBytes(StandardCharsets.UTF_8));
        this.expiracaoSegundos = expiracaoSegundos;
    }

    public String gerarTokenUsuario(String usuario) {
        return gerar(usuario, TIPO_USUARIO, expiracaoSegundos);
    }

    public String gerarTokenServico(int idAgencia) {
        return gerar("agencia-" + idAgencia, TIPO_AGENCIA, EXPIRACAO_SERVICO_SEGUNDOS);
    }

    public long getExpiracaoSegundos() {
        return expiracaoSegundos;
    }

    public Claims validar(String token) throws JwtException {
        return Jwts.parser()
                .verifyWith(chave)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private String gerar(String sujeito, String tipo, long segundos) {
        Date agora = new Date();
        return Jwts.builder()
                .subject(sujeito)
                .claim("tipo", tipo)
                .issuedAt(agora)
                .expiration(new Date(agora.getTime() + segundos * 1000))
                .signWith(chave)
                .compact();
    }
}
