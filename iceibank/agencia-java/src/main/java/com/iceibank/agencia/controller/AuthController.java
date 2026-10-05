package com.iceibank.agencia.controller;

import com.iceibank.agencia.auth.JwtService;
import com.iceibank.agencia.dto.LoginRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class AuthController {

    private final JwtService jwtService;
    private final String usuario;
    private final String senha;

    public AuthController(JwtService jwtService,
                          @Value("${auth.usuario}") String usuario,
                          @Value("${auth.senha}") String senha) {
        this.jwtService = jwtService;
        this.usuario = usuario;
        this.senha = senha;
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req) {
        if (!usuario.equals(req.getUsuario()) || !senha.equals(req.getSenha())) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("erro", "Usuário ou senha inválidos."));
        }

        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("token", jwtService.gerarTokenUsuario(req.getUsuario()));
        resposta.put("expiraEmSegundos", jwtService.getExpiracaoSegundos());
        return ResponseEntity.ok(resposta);
    }
}
