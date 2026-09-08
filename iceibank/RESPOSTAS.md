6.4 Perguntas:

1- Porque adotando somente o time stamp recebido ele poderia "voltar no tempo" ou simplesmente perder a consistencia do seu atual.
2- Porque garante a ordem causal: se um evento causou outro, seu timestamp deve ser menor. Só copiar o timestamp recebido faria o relógio "andar para trás" quando o contador local já estivesse mais adiantado, quebrando a ordenação com os eventos locais anteriores. O max preserva o progresso local (ou adota o do remetente, se maior) e o +1 garante que o recebimento é sempre posterior ao envio.