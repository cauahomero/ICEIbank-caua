6.4 Perguntas:

1- Porque adotando somente o time stamp recebido ele poderia "voltar no tempo" ou simplesmente perder a consistencia do seu atual.
2- Porque garante a ordem causal: se um evento causou outro, seu timestamp deve ser menor. Só copiar o timestamp recebido faria o relógio "andar para trás" quando o contador local já estivesse mais adiantado, quebrando a ordenação com os eventos locais anteriores. O max preserva o progresso local (ou adota o do remetente, se maior) e o +1 garante que o recebimento é sempre posterior ao envio.

8.3
1- Porque aoEnviar()/aoReceber() servem para sincronizar relógios entre processos diferentes durante uma troca de mensagem. Na transferência local, débito e crédito ocorrem no mesmo processo, então basta eventoLocal() duas vezes. Já na transferência entre agências, o crédito é feito via chamada HTTP a outro processo — uma mensagem real —, então precisa de aoEnviar() na origem e aoReceber() no destino para preservar a causalidade entre os dois relógios.
2- não é revertido. Isso significa que o sistema fica inconsistente: o dinheiro "some" temporariamente, quebrando a atomicidade que uma transferência bancária deveria garantir.
3-2PC: só debitar de fato após o destino confirmar que pode receber.
Saga compensatória: se falhar o crédito remoto, credita de volta o valor na origem

10.2
- São concorrentes, não tem relação causal. Se A influenciou B então l(A) < l(B), então eles nunca podem ter relação casual

10.3
- A regra só vale em um sentido. Se A causou B, então L(A) < L(B). No outro sentido um relógio pode estar mais adiantado que o outro. Lamport mostra uma ordem possivel mas não mostra quem influenciou quem.

- Não. No passo 3 apareceram dois eventos de agências diferentes com o mesmo timestamp, e eles eram concorrentes. Só que se L(A) < L(B), isso pode significar tanto que A causou B quanto que os dois são independentes e um relógio só estava mais "adiantado", e o Lamport não consegue diferenciar esses casos porque ele é um único contador que mistura a história de todas as agências. Isso motiva o relógio vetorial.

11.3
- Autenticação é verificar quem é o usuário. Autorização é verificar o que esse usuário pode fazer depois de identificado. Sim, um usuário autenticado consegue sacar de uma conta que não é dele. O sacar pega o id da URL e debita direto, sem comparar com o usuário do token.

-  Porque o JWT já carrega os dados dentro dele (usuário, tipo, expiração) e é assinado com a chave secreta. Para validar, o servidor só recalcula a assinatura com a chave que ele já tem e compara. Isso escala melhor do que sessão em memória: com sessão, cada servidor só conhece as sessões que ele criou, então com várias instâncias precisa de um lugar compartilhado (Redis, banco) ou de sticky session. Com JWT qualquer instância valida o token, tanto que um token gerado em uma agência funciona nas outras porque elas usam a mesma chave. A desvantagem é que não dá para invalidar um token antes de ele expirar.

-  Qualquer um com a chave consegue gerar tokens válidos, se passando por qualquer usuário ou até por uma agência (tipo "agencia"), e aí pode chamar o creditar-remoto e criar dinheiro em qualquer conta. O servidor não tem como diferenciar um token falso de um verdadeiro, e como a chave é a mesma nas 3 agências, todas ficam comprometidas. A única solução é trocar a chave, o que derruba todos os tokens. No caso da minha agencia elajá está exposta no application.properties.