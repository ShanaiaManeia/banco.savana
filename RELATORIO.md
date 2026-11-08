# Relatório — Sistema de Transacções Bancárias Distribuído (Banco Savana)

Sistemas Distribuídos · Projecto 1 · ISCIM

## 1. Arquitectura
```
 App móvel (React Native) ─┐
                           ├─ HTTPS ─> Nginx (VPS) ──> API Gateway ──┬─> Serviço de Autenticação ── auth_db
 Backoffice (React) ───────┘                          (valida JWT)  ├─> Serviço de Clientes e Contas ── contas_db
                                                                     └─> Serviço de Transacções ── transacoes_db
                                                                              └─(REST interno)─> Contas
```
- **Gateway**: único ponto de entrada. Valida o JWT, aplica permissões por tipo de utilizador (funcionário/cliente) e injecta `X-User-Id`/`X-User-Tipo` (os cabeçalhos vindos de fora são descartados). Os endpoints `/internal/**` não são expostos.
- **Autenticação**: funcionários (email + palavra-passe BCrypt) e clientes (número da conta + PIN, validado no serviço de Contas). Emite JWT (HS256, 8 h). Enquanto o PIN for temporário, o token só permite alterar o PIN.
- **Clientes e Contas**: cadastro, abertura de contas, PIN cifrado (BCrypt), saldo, bloqueio; executa depósitos e transferências em transacções de BD.
- **Transacções**: regista cada operação (PENDENTE → CONCLUIDA/REJEITADA), chama o serviço de Contas e devolve o comprovativo/extracto.
- Cada serviço tem a **sua base de dados** (um servidor PostgreSQL com três bases: `auth_db`, `contas_db`, `transacoes_db`).
- **Auditoria**: tabela `auditoria` (actor, acção, data/hora) em Contas e em Transacções.

## 2. Modelo de dados
| Tabela (serviço) | Campos principais |
|---|---|
| `funcionarios` (auth) | id, nome, email (único), senha_hash, estado |
| `clientes` (contas) | id, nome, bi (único), telefone, email, estado |
| `contas` (contas) | id, numero (único), cliente_id, pin_hash, saldo (MZN, 2 casas), estado (ACTIVA/BLOQUEADA), data_abertura, pin_temporario |
| `transaccoes` (transacoes) | id, referencia (única), conta_origem, conta_destino, valor, data_hora, tipo (DEPOSITO/TRANSFERENCIA), estado, motivo |
| `auditoria` (contas, transacoes) | id, actor_tipo, actor_id, acao, data_hora |

## 3. Regras e concorrência
- Transferência aceite só se: valor > 0, contas diferentes, ambas activas, PIN certo e saldo suficiente.
- **Atomicidade**: débito e crédito são feitos no mesmo método `@Transactional` do serviço de Contas — ou acontecem os dois ou nenhum.
- **Bloqueio pessimista** (`@Lock(PESSIMISTIC_WRITE)` → `SELECT … FOR UPDATE`) sobre as contas envolvidas; o saldo nunca fica negativo porque a verificação é feita com a linha bloqueada.
- **Sem deadlock**: numa transferência bloqueia-se sempre primeiro a conta de número menor.
- O serviço de Transacções grava primeiro a transacção como PENDENTE; se o processo cair entre a chamada a Contas e a actualização do estado, a transacção fica PENDENTE e pode ser reconciliada (limitação assumida; uma evolução seria o padrão Saga/outbox).

## 4. Testes automáticos de concorrência
Ficheiro: `contas-service/src/test/java/mz/banco/contas/ConcorrenciaTest.java` — comando `mvn -pl contas-service test`.

| # | Caso | Como é verificado | Resultado |
|---|---|---|---|
| 1 | Dois depósitos simultâneos (100 e 50) | saldo final = 150 | _colar resultado do `mvn test`_ |
| 2 | Duas transferências simultâneas de 80 com saldo 100 | 1 aceite, 1 rejeitada; origem 20, destino 80 | _colar resultado_ |
| 3 | 25 pares de transferências cruzadas A→B e B→A | terminam (timeout 60 s), soma conservada (2000) | _colar resultado_ |

## 5. Implantação
VPS Linux, Docker Compose (db, 4 serviços Java, backoffice, Nginx), HTTPS com Let's Encrypt. Ver `README.md`.
