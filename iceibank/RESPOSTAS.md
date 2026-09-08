6.4 Perguntas:

1- Porque adotando somente o time stamp recebido ele poderia "voltar no tempo" ou simplesmente perder a consistencia do seu atual.
2- Porque garante a ordem causal: se um evento causou outro, seu timestamp deve ser menor. Só copiar o timestamp recebido faria o relógio "andar para trás" quando o contador local já estivesse mais adiantado, quebrando a ordenação com os eventos locais anteriores. O max preserva o progresso local (ou adota o do remetente, se maior) e o +1 garante que o recebimento é sempre posterior ao envio.

8.3
1- Porque aoEnviar()/aoReceber() servem para sincronizar relógios entre processos diferentes durante uma troca de mensagem. Na transferência local, débito e crédito ocorrem no mesmo processo, então basta eventoLocal() duas vezes. Já na transferência entre agências, o crédito é feito via chamada HTTP a outro processo — uma mensagem real —, então precisa de aoEnviar() na origem e aoReceber() no destino para preservar a causalidade entre os dois relógios.
2- não é revertido. Isso significa que o sistema fica inconsistente: o dinheiro "some" temporariamente, quebrando a atomicidade que uma transferência bancária deveria garantir.
3-2PC: só debitar de fato após o destino confirmar que pode receber.
Saga compensatória: se falhar o crédito remoto, credita de volta o valor na origem