# Banco Savana — Sistema de Transacções Bancárias Distribuído
# email":"admin@banco.co.mz","senha":"Admin@2026

Projecto 1 · Sistemas Distribuídos. O nome do banco é configurável: `BANK_NAME` (.env), `backoffice/src/api.js` e `mobile/App.js`.

## Estrutura
| Pasta | O que é |
|---|---|
| `gateway/` | API Gateway (Spring Cloud Gateway) — valida o JWT e aplica permissões |
| `auth-service/` | Autenticação: login de funcionários e de clientes (conta + PIN), emite JWT |
| `contas-service/` | Clientes e contas, PIN (BCrypt), saldos, bloqueio, **concorrência + testes** |
| `transacoes-service/` | Depósitos, transferências, extracto |
| `backoffice/` | Backoffice web (React + Vite) |
| `mobile/` | Aplicação móvel (React Native / Expo) |

## Correr os testes de concorrência
```bash
mvn -pl contas-service test      # precisa de Java 21 e Maven
```

## Correr localmente (Docker)
```bash
cp .env.example .env             # e edite as palavras-passe
docker compose up -d --build db contas-service transacoes-service auth-service gateway backoffice
```
Para desenvolvimento do backoffice: `cd backoffice && npm install && npm run dev` (proxy para o gateway em :8080).
Utilizador inicial do backoffice: `ADMIN_EMAIL` / `ADMIN_SENHA` do `.env`.

## Implantação no VPS (Linux) com HTTPS
1. Instale Docker + Docker Compose e aponte o domínio para o IP do VPS.
2. Obtenha o certificado: `sudo certbot certonly --standalone -d SEU_DOMINIO` (porta 80 livre).
3. Em `nginx/nginx.conf` substitua `SEU_DOMINIO` (3 sítios). Copie `.env.example` para `.env` e edite.
4. `docker compose up -d --build` — o backoffice fica em `https://SEU_DOMINIO/` e a API em `https://SEU_DOMINIO/api`.
5. Renovação: `certbot renew` (cron) + `docker compose restart nginx`.
6. App móvel: em `mobile/App.js` troque `SEU_DOMINIO`; `cd mobile && npm install && npx expo start` (ou gere o APK com `eas build -p android --profile preview`).

## Contas de teste
Entre no backoffice → crie 2 clientes → abra uma conta para cada (PIN inicial + saldo inicial) → use os números na app.
No primeiro acesso a app obriga a mudar o PIN.

## API (via gateway, prefixo `/api`)
`POST /auth/funcionarios/login` · `POST /auth/clientes/login` · `POST|GET /clientes` · `POST|GET /clientes/{id}/contas` ·
`POST /contas/{numero}/depositos` · `POST /transferencias` · `GET /contas/{numero}/movimentos` ·
`GET /contas`, `GET /contas/{numero}`, `POST /contas/{numero}/bloquear|desbloquear|pin`
