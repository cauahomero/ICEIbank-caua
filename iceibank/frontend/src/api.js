export const NUMERO_AGENCIAS = 3
export const PORTA_BASE = 4006

const CHAVE_TOKEN = 'iceibank.token'
const CHAVE_AGENCIA = 'iceibank.agencia'

// Mesma regra de AgenciasConfig.agenciaResponsavel no backend
export function agenciaResponsavel(idConta) {
  return Number(idConta) % NUMERO_AGENCIAS
}

export function lerToken() {
  return localStorage.getItem(CHAVE_TOKEN)
}

export function salvarToken(token) {
  localStorage.setItem(CHAVE_TOKEN, token)
}

export function apagarToken() {
  localStorage.removeItem(CHAVE_TOKEN)
}

export function lerAgencia() {
  return Number(localStorage.getItem(CHAVE_AGENCIA) ?? 0)
}

export function salvarAgencia(id) {
  localStorage.setItem(CHAVE_AGENCIA, String(id))
}

// Erro com o status HTTP junto, para a tela decidir o que fazer (ex.: 401 -> volta pro login)
export class ErroApi extends Error {
  constructor(status, mensagem) {
    super(mensagem)
    this.status = status
  }
}

async function requisitar(agencia, metodo, caminho, corpo) {
  const cabecalhos = { 'Content-Type': 'application/json' }
  const token = lerToken()
  if (token) cabecalhos.Authorization = `Bearer ${token}`

  let resposta
  try {
    resposta = await fetch(`/agencia${agencia}${caminho}`, {
      method: metodo,
      headers: cabecalhos,
      body: corpo ? JSON.stringify(corpo) : undefined,
    })
  } catch {
    throw new ErroApi(0, `Não foi possível contatar a agência ${agencia}.`)
  }

  const dados = await resposta.json().catch(() => null)

  if (!resposta.ok) {
    if (dados?.erro) throw new ErroApi(resposta.status, dados.erro)
    // Sem corpo JSON: normalmente é o proxy do Vite avisando que a agência está fora do ar
    throw new ErroApi(
      resposta.status,
      `Agência ${agencia} não respondeu (porta ${PORTA_BASE + agencia}). Ela está rodando?`,
    )
  }
  return dados
}

export const api = {
  login: (agencia, usuario, senha) => requisitar(agencia, 'POST', '/auth/login', { usuario, senha }),
  consultarConta: (agencia, id) => requisitar(agencia, 'GET', `/contas/${id}`),
  criarConta: (agencia, id, nomeAluno, saldoInicial) =>
    requisitar(agencia, 'POST', '/contas', { id, nomeAluno, saldoInicial }),
  depositar: (agencia, id, valor) => requisitar(agencia, 'POST', `/contas/${id}/depositar`, { valor }),
  sacar: (agencia, id, valor) => requisitar(agencia, 'POST', `/contas/${id}/sacar`, { valor }),
  historico: (agencia, id, limite = 20) => requisitar(agencia, 'GET', `/contas/${id}/historico?limite=${limite}`),
  transferir: (agencia, idOrigem, idDestino, valor) =>
    requisitar(agencia, 'POST', '/transferencias', { idOrigem, idDestino, valor }),
  consultarTransferencia: (agencia, idTransferencia) =>
    requisitar(agencia, 'GET', `/transferencias/${idTransferencia}`),
}
