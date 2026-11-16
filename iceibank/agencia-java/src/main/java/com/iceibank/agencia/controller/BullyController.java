package com.iceibank.agencia.controller;

import com.iceibank.agencia.bully.BullyService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class BullyController {

    public record MensagemEleicao(int origemId, int[] vetorEnvio) {
    }

    public record MensagemCoordenador(int liderId, int[] vetorEnvio) {
    }

    private final BullyService bully;

    public BullyController(BullyService bully) {
        this.bully = bully;
    }

    @PostMapping("/bully/eleicao")
    public ResponseEntity<Void> eleicao(@RequestBody MensagemEleicao msg) {
        bully.receberEleicao(msg.origemId(), msg.vetorEnvio());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/bully/coordenador")
    public ResponseEntity<Void> coordenador(@RequestBody MensagemCoordenador msg) {
        bully.receberCoordenador(msg.liderId(), msg.vetorEnvio());
        return ResponseEntity.ok().build();
    }

    @GetMapping("/bully/lider")
    public Map<String, Object> lider() {
        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("idAgencia", bully.getIdAgencia());
        resposta.put("liderAtual", bully.obterLiderAtual());
        return resposta;
    }
}
