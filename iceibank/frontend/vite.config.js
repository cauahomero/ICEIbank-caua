import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Mesmos valores de AgenciasConfig.java: porta = 4000 + OFFSET + idAgencia
const PORTA_BASE = 4006
const NUMERO_AGENCIAS = 3

// O backend não tem CORS, então o navegador fala só com o Vite e ele repassa:
// /agencia0/contas/1 -> http://localhost:4006/contas/1
const proxy = {}
for (let i = 0; i < NUMERO_AGENCIAS; i++) {
  proxy[`/agencia${i}`] = {
    target: `http://localhost:${PORTA_BASE + i}`,
    rewrite: (path) => path.replace(`/agencia${i}`, ''),
  }
}

export default defineConfig({
  plugins: [react()],
  server: { port: 5173, proxy },
})
