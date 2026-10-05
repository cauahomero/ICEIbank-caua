import { useState } from 'react'
import {
  api,
  ErroApi,
  NUMERO_AGENCIAS,
  PORTA_BASE,
  agenciaResponsavel,
  apagarToken,
  lerAgencia,
  lerToken,
  salvarAgencia,
  salvarToken,
} from './api.js'

const moeda = (v) => Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

export default function App() {
  const [token, setToken] = useState(lerToken())
  const [agencia, setAgencia] = useState(lerAgencia())
  const [avisoLogin, setAvisoLogin] = useState('')

  function trocarAgencia(id) {
    setAgencia(id)
    salvarAgencia(id)
  }

  function sair(motivo = '') {
    apagarToken()
    setToken(null)
    setAvisoLogin(motivo)
  }

  return (
    <div className="pagina">
      <header>
        <h1>ICEIBank</h1>
        <SeletorAgencia agencia={agencia} onChange={trocarAgencia} />
        {token && <button onClick={() => sair()}>Sair</button>}
      </header>

      {token ? (
        <Painel agencia={agencia} onSessaoExpirada={sair} />
      ) : (
        <Login
          agencia={agencia}
          aviso={avisoLogin}
          onLogin={(t) => {
            salvarToken(t)
            setToken(t)
            setAvisoLogin('')
          }}
        />
      )}
    </div>
  )
}

function SeletorAgencia({ agencia, onChange }) {
  return (
    <label className="seletor">
      Agência de entrada:{' '}
      <select value={agencia} onChange={(e) => onChange(Number(e.target.value))}>
        {Array.from({ length: NUMERO_AGENCIAS }, (_, i) => (
          <option key={i} value={i}>
            Agência {i} (porta {PORTA_BASE + i})
          </option>
        ))}
      </select>
    </label>
  )
}

function Login({ agencia, aviso, onLogin }) {
  const [usuario, setUsuario] = useState('')
  const [senha, setSenha] = useState('')
  const [erro, setErro] = useState('')
  const [carregando, setCarregando] = useState(false)

  async function entrar(e) {
    e.preventDefault()
    setErro('')
    setCarregando(true)
    try {
      const { token } = await api.login(agencia, usuario, senha)
      onLogin(token)
    } catch (err) {
      setErro(err.message)
    } finally {
      setCarregando(false)
    }
  }

  return (
    <form className="cartao login" onSubmit={entrar}>
      <h2>Login</h2>
      {aviso && <p className="msg erro">{aviso}</p>}
      <label>
        Usuário
        <input value={usuario} onChange={(e) => setUsuario(e.target.value)} required />
      </label>
      <label>
        Senha
        <input type="password" value={senha} onChange={(e) => setSenha(e.target.value)} required />
      </label>
      <button disabled={carregando}>{carregando ? 'Entrando...' : 'Entrar'}</button>
      {erro && <p className="msg erro">{erro}</p>}
    </form>
  )
}

function useOperacao(onSessaoExpirada) {
  const [resultado, setResultado] = useState(null)
  const [carregando, setCarregando] = useState(false)

  async function executar(chamada, mensagemSucesso, dica) {
    setCarregando(true)
    setResultado(null)
    try {
      const dados = await chamada()
      setResultado({ tipo: 'ok', texto: mensagemSucesso(dados), dados })
    } catch (err) {
      if (err instanceof ErroApi && err.status === 401) {
        onSessaoExpirada(`Sessão encerrada: ${err.message} Faça login novamente.`)
        return
      }
      const status = err instanceof ErroApi && err.status ? ` (HTTP ${err.status})` : ''
      setResultado({ tipo: 'erro', texto: err.message + status, dica: err.status === 404 ? dica : null })
    } finally {
      setCarregando(false)
    }
  }

  return { resultado, carregando, executar }
}

function Mensagem({ resultado }) {
  if (!resultado) return null
  return (
    <div className={`msg ${resultado.tipo}`}>
      {resultado.texto}
      {resultado.dica && <div className="dica">{resultado.dica}</div>}
    </div>
  )
}

function dicaAgencia(idConta, agencia) {
  const correta = agenciaResponsavel(idConta)
  if (correta === agencia) return null
  return `A conta ${idConta} pertence à agência ${correta}. Troque a agência de entrada no topo da página.`
}

function Painel({ agencia, onSessaoExpirada }) {
  return (
    <main className="grade">
      <ConsultaSaldo agencia={agencia} onSessaoExpirada={onSessaoExpirada} />
      <DepositoSaque agencia={agencia} onSessaoExpirada={onSessaoExpirada} />
      <Transferencia agencia={agencia} onSessaoExpirada={onSessaoExpirada} />
      <CriarConta agencia={agencia} onSessaoExpirada={onSessaoExpirada} />
      <Historico agencia={agencia} onSessaoExpirada={onSessaoExpirada} />
    </main>
  )
}

function ConsultaSaldo({ agencia, onSessaoExpirada }) {
  const [id, setId] = useState('')
  const { resultado, carregando, executar } = useOperacao(onSessaoExpirada)

  function consultar(e) {
    e.preventDefault()
    executar(
      () => api.consultarConta(agencia, id),
      (c) => `Conta ${c.id} (${c.nomeAluno}) — saldo: ${moeda(c.saldo)}`,
      dicaAgencia(id, agencia),
    )
  }

  return (
    <form className="cartao" onSubmit={consultar}>
      <h2>Consultar saldo</h2>
      <label>
        Nº da conta
        <input type="number" min="0" value={id} onChange={(e) => setId(e.target.value)} required />
      </label>
      <button disabled={carregando}>Consultar</button>
      <Mensagem resultado={resultado} />
    </form>
  )
}

function DepositoSaque({ agencia, onSessaoExpirada }) {
  const [id, setId] = useState('')
  const [valor, setValor] = useState('')
  const { resultado, carregando, executar } = useOperacao(onSessaoExpirada)

  function operar(tipo) {
    const chamada = tipo === 'deposito' ? api.depositar : api.sacar
    const verbo = tipo === 'deposito' ? 'Depósito' : 'Saque'
    executar(
      () => chamada(agencia, id, Number(valor)),
      (c) => `${verbo} de ${moeda(valor)} realizado. Novo saldo da conta ${c.id}: ${moeda(c.saldo)}`,
      dicaAgencia(id, agencia),
    )
  }

  return (
    <form
      className="cartao"
      onSubmit={(e) => {
        e.preventDefault()
        operar(e.nativeEvent.submitter.value)
      }}
    >
      <h2>Depósito / Saque</h2>
      <label>
        Nº da conta
        <input type="number" min="0" value={id} onChange={(e) => setId(e.target.value)} required />
      </label>
      <label>
        Valor
        <input type="number" min="0.01" step="0.01" value={valor} onChange={(e) => setValor(e.target.value)} required />
      </label>
      <div className="botoes">
        <button value="deposito" disabled={carregando}>Depositar</button>
        <button value="saque" disabled={carregando}>Sacar</button>
      </div>
      <Mensagem resultado={resultado} />
    </form>
  )
}

function Transferencia({ agencia, onSessaoExpirada }) {
  const [origem, setOrigem] = useState('')
  const [destino, setDestino] = useState('')
  const [valor, setValor] = useState('')
  const { resultado, carregando, executar } = useOperacao(onSessaoExpirada)

  function transferir(e) {
    e.preventDefault()
    executar(
      () => api.transferir(agencia, Number(origem), Number(destino), Number(valor)),
      (r) => `${r.mensagem} ${moeda(valor)} da conta ${origem} para a conta ${destino}.`,
      dicaAgencia(origem, agencia),
    )
  }

  return (
    <form className="cartao" onSubmit={transferir}>
      <h2>Transferência</h2>
      <label>
        Conta de origem
        <input type="number" min="0" value={origem} onChange={(e) => setOrigem(e.target.value)} required />
      </label>
      <label>
        Conta de destino
        <input type="number" min="0" value={destino} onChange={(e) => setDestino(e.target.value)} required />
      </label>
      <label>
        Valor
        <input type="number" min="0.01" step="0.01" value={valor} onChange={(e) => setValor(e.target.value)} required />
      </label>
      <button disabled={carregando}>Transferir</button>
      <Mensagem resultado={resultado} />
    </form>
  )
}

function CriarConta({ agencia, onSessaoExpirada }) {
  const [id, setId] = useState('')
  const [nome, setNome] = useState('')
  const [saldo, setSaldo] = useState('0')
  const { resultado, carregando, executar } = useOperacao(onSessaoExpirada)

  function criar(e) {
    e.preventDefault()
    executar(
      () => api.criarConta(agencia, Number(id), nome, Number(saldo)),
      (c) => `Conta ${c.id} criada para ${c.nomeAluno} com saldo ${moeda(c.saldo)}.`,
    )
  }

  return (
    <form className="cartao" onSubmit={criar}>
      <h2>Criar conta</h2>
      <p className="ajuda">
        Esta agência aceita contas com nº % {NUMERO_AGENCIAS} = {agencia}.
      </p>
      <label>
        Nº da conta
        <input type="number" min="0" value={id} onChange={(e) => setId(e.target.value)} required />
      </label>
      <label>
        Nome do aluno
        <input value={nome} onChange={(e) => setNome(e.target.value)} required />
      </label>
      <label>
        Saldo inicial
        <input type="number" min="0" step="0.01" value={saldo} onChange={(e) => setSaldo(e.target.value)} required />
      </label>
      <button disabled={carregando}>Criar</button>
      <Mensagem resultado={resultado} />
    </form>
  )
}

const TIPOS_EVENTO = {
  CRIAR_CONTA: { descricao: () => 'Abertura de conta', sinal: 1, campoValor: 'saldoInicial' },
  DEPOSITO: { descricao: () => 'Depósito', sinal: 1 },
  SAQUE: { descricao: () => 'Saque', sinal: -1 },
  RENDIMENTO_CDB: { descricao: (d) => `Rendimento CDB (${d.taxa * 100}%)`, sinal: 1 },
  TRANSFERENCIA_DEBITO: { descricao: (d) => `Transferência enviada para conta ${d.idDestino}`, sinal: -1 },
  TRANSFERENCIA_CREDITO: { descricao: (d) => `Transferência recebida da conta ${d.idOrigem}`, sinal: 1 },
  TRANSFERENCIA_CREDITO_REMOTO: {
    descricao: (d) => `Transferência recebida da agência ${d.origemAgencia}`,
    sinal: 1,
  },
  TRANSFERENCIA_FALHOU: { descricao: (d) => `Falha ao transferir para conta ${d.idDestino}`, sinal: 0 },
}

function Historico({ agencia, onSessaoExpirada }) {
  const [id, setId] = useState('')
  const { resultado, carregando, executar } = useOperacao(onSessaoExpirada)

  function buscar(e) {
    e.preventDefault()
    executar(
      () => api.historico(agencia, id),
      (r) => `Conta ${r.conta.id} (${r.conta.nomeAluno}) — saldo atual: ${moeda(r.conta.saldo)}`,
      dicaAgencia(id, agencia),
    )
  }

  const eventos = resultado?.tipo === 'ok' ? resultado.dados.eventos : null

  return (
    <form className="cartao largo" onSubmit={buscar}>
      <h2>Histórico da conta</h2>
      <div className="linha">
        <label>
          Nº da conta
          <input type="number" min="0" value={id} onChange={(e) => setId(e.target.value)} required />
        </label>
        <button disabled={carregando}>Ver histórico</button>
      </div>
      <Mensagem resultado={resultado} />
      {eventos && eventos.length === 0 && <p className="ajuda">Nenhum evento registrado para esta conta.</p>}
      {eventos && eventos.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>Vetor</th>
              <th>Horário</th>
              <th>Evento</th>
              <th className="valor">Valor</th>
            </tr>
          </thead>
          <tbody>
            {eventos.map((ev, i) => {
              const tipo = TIPOS_EVENTO[ev.tipo] ?? { descricao: () => ev.tipo, sinal: 0 }
              const valor = ev.detalhes[tipo.campoValor ?? 'valor']
              const classe = tipo.sinal > 0 ? 'entrada' : tipo.sinal < 0 ? 'saida' : ''
              return (
                <tr key={i}>
                  <td>[{ev.timestampVetorial.join(', ')}]</td>
                  <td>{new Date(ev.horaParede).toLocaleTimeString('pt-BR')}</td>
                  <td>{tipo.descricao(ev.detalhes)}</td>
                  <td className={`valor ${classe}`}>
                    {tipo.sinal < 0 ? '- ' : tipo.sinal > 0 ? '+ ' : ''}
                    {moeda(valor)}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}
    </form>
  )
}
