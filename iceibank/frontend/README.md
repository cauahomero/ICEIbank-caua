# ICEIBank - Frontend (React + Vite)

## Como rodar

1. Suba as agências (cada uma em um terminal):
   ```
   cd agencia-java
   $env:AGENCIA_ID=0; java -jar target/agencia-1.0.0.jar   # porta 4006
   $env:AGENCIA_ID=1; java -jar target/agencia-1.0.0.jar   # porta 4007
   $env:AGENCIA_ID=2; java -jar target/agencia-1.0.0.jar   # porta 4008
   ```
2. Rode o frontend:
   ```
   cd frontend
   npm install
   npm run dev
   ```
3. Abra http://localhost:5173 e entre com `operador` / `senha123`.

## Decisões

- **Agência de entrada:** o seletor no topo escolhe para qual agência as requisições vão. O Vite faz proxy de `/agencia0`, `/agencia1` e `/agencia2` para as portas 4006, 4007 e 4008. Assim o navegador só fala com uma origem e não é preciso configurar CORS no backend.
- **Token:** fica no `localStorage` e vai no cabeçalho `Authorization: Bearer` de toda requisição. Como as 3 agências usam a mesma chave, o mesmo token serve para qualquer uma delas.
- **Erros:** a mensagem `erro` da API aparece no próprio formulário. Um 401 (token ausente/expirado) apaga o token e volta para o login com o motivo. Se a conta não é da agência selecionada, a tela avisa qual é a agência certa (`id % 3`). Se a agência estiver fora do ar, aparece um aviso dizendo isso.
