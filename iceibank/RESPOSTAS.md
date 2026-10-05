6. 4 Perguntas:

1- Porque adotando somente o time stamp recebido ele poderia "voltar no tempo" ou simplesmente perder a consistencia do seu atual.
2- Porque garante a ordem causal: se um evento causou outro, seu timestamp deve ser menor. Só copiar o timestamp recebido faria o relógio "andar para trás" quando o contador local já estivesse mais adiantado, quebrando a ordenação com os eventos locais anteriores. O max preserva o progresso local (ou adota o do remetente, se maior) e o +1 garante que o recebimento é sempre posterior ao envio.

8. 3
1- Porque aoEnviar()/aoReceber() servem para sincronizar relógios entre processos diferentes durante uma troca de mensagem. Na transferência local, débito e crédito ocorrem no mesmo processo, então basta eventoLocal() duas vezes. Já na transferência entre agências, o crédito é feito via chamada HTTP a outro processo — uma mensagem real —, então precisa de aoEnviar() na origem e aoReceber() no destino para preservar a causalidade entre os dois relógios.
2- não é revertido. Isso significa que o sistema fica inconsistente: o dinheiro "some" temporariamente, quebrando a atomicidade que uma transferência bancária deveria garantir.
3-2PC: só debitar de fato após o destino confirmar que pode receber.
Saga compensatória: se falhar o crédito remoto, credita de volta o valor na origem

10. 2
- São concorrentes, não tem relação causal. Se A influenciou B então l(A) < l(B), então eles nunca podem ter relação casual

10. 3
- A regra só vale em um sentido. Se A causou B, então L(A) < L(B). No outro sentido um relógio pode estar mais adiantado que o outro. Lamport mostra uma ordem possivel mas não mostra quem influenciou quem.

- Não. No passo 3 apareceram dois eventos de agências diferentes com o mesmo timestamp, e eles eram concorrentes. Só que se L(A) < L(B), isso pode significar tanto que A causou B quanto que os dois são independentes e um relógio só estava mais "adiantado", e o Lamport não consegue diferenciar esses casos porque ele é um único contador que mistura a história de todas as agências. Isso motiva o relógio vetorial.

11. 3
- Autenticação é verificar quem é o usuário. Autorização é verificar o que esse usuário pode fazer depois de identificado. Sim, um usuário autenticado consegue sacar de uma conta que não é dele. O sacar pega o id da URL e debita direto, sem comparar com o usuário do token.

-  Porque o JWT já carrega os dados dentro dele (usuário, tipo, expiração) e é assinado com a chave secreta. Para validar, o servidor só recalcula a assinatura com a chave que ele já tem e compara. Isso escala melhor do que sessão em memória: com sessão, cada servidor só conhece as sessões que ele criou, então com várias instâncias precisa de um lugar compartilhado (Redis, banco) ou de sticky session. Com JWT qualquer instância valida o token, tanto que um token gerado em uma agência funciona nas outras porque elas usam a mesma chave. A desvantagem é que não dá para invalidar um token antes de ele expirar.

-  Qualquer um com a chave consegue gerar tokens válidos, se passando por qualquer usuário ou até por uma agência (tipo "agencia"), e aí pode chamar o creditar-remoto e criar dinheiro em qualquer conta. O servidor não tem como diferenciar um token falso de um verdadeiro, e como a chave é a mesma nas 3 agências, todas ficam comprometidas. A única solução é trocar a chave, o que derruba todos os tokens. No caso da minha agencia elajá está exposta no application.properties.

12. 3
- Quando o login dá certo, o token que a API devolve é salvo no localStorage do navegador. Todas as chamadas à API passam por uma única função, a requisitar do api.js. Antes de cada requisição ela lê o token do localStorage e, se ele existir, coloca no cabeçalho Authorization: Bearer <token>. Então as telas não precisam se preocupar com o token, a função central faz isso sozinha. Como fica no localStorage, o token continua lá mesmo se a página for recarregada, e só é apagado quando a pessoa clica em Sair ou quando a API responde 401.

- O frontend não confere a expiração sozinho. Ele só descobre que o token expirou quando faz a próxima requisição e o backend responde 401 com "Token expirado.". Como o filtro JWT roda antes do controller, a operação nem chega a ser executada, então não tem risco de ficar pela metade. Quando chega o 401, o token é apagado e a tela volta para o login com a mensagem "Sessão encerrada: Token expirado. Faça login novamente.". Então não é um erro genérico, a pessoa sabe o motivo. O ponto ruim é que o que ela tinha digitado no formulário se perde e ela precisa refazer a operação depois de entrar de novo. Daria para melhorar avisando antes de expirar, usando o expiraEmSegundos que o login devolve, ou com refresh token.

- o modelo de verdade (a Conta, o saldo, as regras) está no backend. No frontend, o que mais se aproxima do Model é o api.js, que concentra o acesso aos dados, o token e a regra id % 3. Além dele, há os estados (useState) que guardam os dados que vieram da API.
- View: é o JSX dos componentes (Login, ConsultaSaldo, Transferencia etc.) e o App.css.
- Controller: são as funções que tratam os eventos dentro dos componentes (entrar, consultar, transferir, operar) e o hook useOperacao, que chama a API e transforma o resultado em mensagem de sucesso ou de erro, ou manda de volta para o login no 401. O App também tem um pouco de controller, porque controla a sessão e a agência selecionada.
A separação existe, mas está misturada: View e Controller ficam no mesmo arquivo e no mesmo componente. Para ficar mais perto do MVC, daria para tirar a lógica dos componentes para hooks próprios (ex.: useConta) e deixar os componentes só com o JSX.

2. 1 Funcionalidade adicional
1- Histórico por conta: GET /contas/{id}/historico (com ?limite=, padrão 20) lista os últimos eventos de uma conta, do mais recente para o mais antigo: abertura, depósito, saque, transferência enviada/recebida (local ou de outra agência) e rendimento do CDB, cada um com o timestamp de Lamport e o horário. Escolhi porque, como é um banco, ver o extrato da conta é uma funcionalidade útil, e o sistema já registrava tudo no log de eventos mas não tinha como consultar isso por conta. Também aparece no frontend, no cartão "Histórico da conta".

2- CDB: enquanto a agência está no ar, a cada 5 minutos cada conta com saldo recebe 0,1% do valor que tem na conta. Fiz porque achei que seria legal ter algo rodando em tempo real, uma regra que acontece sozinha com o sistema ativo, sem ninguém chamar um endpoint. Cada rendimento é um evento local no relógio de Lamport e aparece no histórico. A taxa e o intervalo ficam no application.properties (cdb.taxa e cdb.intervalo-ms). Precisei deixar os métodos da Conta synchronized, porque agora o agendador mexe nos saldos ao mesmo tempo que as requisições.
